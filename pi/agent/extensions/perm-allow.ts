/**
 * /allow - save a permission you just approved as a project-level rule, so
 * pi-permission-system stops asking for it in this folder. The plugin itself
 * only has "allow for this session"; durable approvals are parked upstream
 * (gotgenes/pi-packages#799).
 *
 * Approvals are collected from the plugin's `permissions:decision` broadcast.
 * /allow picks one, suggests a wildcard pattern (editable), and appends it to
 * <cwd>/.pi/extensions/pi-permission-system/config.json. The plugin stamps
 * that file's mtime, so a saved rule applies to the next tool call - provided
 * the project is trusted (/trust), otherwise the plugin ignores the file.
 *
 * Project pattern maps are shallow-merged over the global ones and a new key
 * lands at the END of the merged map. Rules are last-match-wins, so a broad
 * project allow would silently beat a global deny ("git push *" over
 * "git push --force*"). Restating the deny in the project file does not help:
 * a key that already exists keeps its global position. So /allow re-adds each
 * overlapped deny after the new allow under an equivalent spelling - the
 * plugin documents "**" as identical to "*" - which is a new key and lands last.
 */

import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, isAbsolute, join, relative, resolve } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

type Approval = { surface: string; value: string };
type PatternMap = Record<string, unknown>;
type Rule = { key: string; pattern: string | null };

const CONFIG_REL = join("extensions", "pi-permission-system", "config.json");
const MAX_RECENT = 15;

// How many leading words name the subcommand; unknown commands use 1.
const ARITY: Record<string, number> = {
	"npm run": 3, "pnpm run": 3, "yarn run": 3, "bun run": 3, "docker compose": 3, "mise run": 3, "uv run": 3,
	git: 2, npm: 2, pnpm: 2, yarn: 2, bun: 2, npx: 2, cargo: 2, go: 2, docker: 2, gh: 2,
	mise: 2, uv: 2, pip: 2, deno: 2, kubectl: 2, systemctl: 2,
};

// The extension module is cached across session replacements (/new, /clear),
// so approvals survive those; the listener is re-registered per instance.
const recent: Approval[] = [];

function remember(approval: Approval) {
	const i = recent.findIndex((a) => a.surface === approval.surface && a.value === approval.value);
	if (i !== -1) recent.splice(i, 1);
	recent.unshift(approval);
	recent.length = Math.min(recent.length, MAX_RECENT);
}

function expandHome(pattern: string): string {
	return pattern.startsWith("~/") ? join(homedir(), pattern.slice(2)) : pattern;
}

/** Whether some string matches both wildcard patterns. */
function globsOverlap(a: string, b: string): boolean {
	const seen = new Set<number>();
	const walk = (i: number, j: number): boolean => {
		if (i === a.length && j === b.length) return true;
		const id = i * (b.length + 1) + j;
		if (seen.has(id)) return false;
		seen.add(id);
		if (a[i] === "*" && (walk(i + 1, j) || (j < b.length && walk(i, j + 1)))) return true;
		if (b[j] === "*" && (walk(i, j + 1) || (i < a.length && walk(i + 1, j)))) return true;
		if (i === a.length || j === b.length || a[i] === "*" || b[j] === "*") return false;
		return (a[i] === b[j] || a[i] === "?" || b[j] === "?") && walk(i + 1, j + 1);
	};
	return walk(0, 0);
}

function looksLikePath(value: string): boolean {
	return !/\s/.test(value) && (/^[~/.]/.test(value) || value.includes("/"));
}

function tildify(path: string): string {
	const home = homedir();
	return path === home || path.startsWith(`${home}/`) ? `~${path.slice(home.length)}` : path;
}

function suggestBashPattern(command: string): string {
	const words = command.trim().split(/\s+/);
	while (words.length > 1 && /^[A-Za-z_][A-Za-z0-9_]*=/.test(words[0])) words.shift();
	const arity = ARITY[words.slice(0, 2).join(" ")] ?? ARITY[words[0]] ?? 1;
	return `${words.slice(0, arity).join(" ")} *`;
}

function suggestRule({ surface, value }: Approval, cwd: string): Rule {
	if (surface === "bash") return { key: "bash", pattern: suggestBashPattern(value) };

	const pathSurface = /^(path|external_directory)(_read|_write)?$/.test(surface);
	if (!looksLikePath(value)) {
		// A path surface needs a pattern; anything else is a plain tool switch.
		return pathSurface ? { key: surface, pattern: "" } : { key: surface, pattern: null };
	}

	const expanded = value.startsWith("~") ? join(homedir(), value.slice(1)) : value;
	const abs = resolve(cwd, expanded);
	const rel = relative(cwd, abs);
	const outside = rel.startsWith("..") || isAbsolute(rel);
	if (pathSurface) {
		const dir = outside ? tildify(dirname(abs)) : dirname(rel);
		return { key: surface, pattern: dir === "." ? "*" : `${dir}/*` };
	}
	// A file tool's outside-cwd ask is reported under the tool's own name.
	if (outside) {
		const write = surface === "write" || surface === "edit";
		return { key: write ? "external_directory_write" : "external_directory_read", pattern: `${tildify(dirname(abs))}/*` };
	}
	return { key: surface, pattern: null };
}

function readConfig(path: string): Record<string, unknown> {
	if (!existsSync(path)) return {};
	const parsed: unknown = JSON.parse(readFileSync(path, "utf8"));
	if (typeof parsed !== "object" || parsed === null || Array.isArray(parsed)) throw new Error("not a JSON object");
	return parsed as Record<string, unknown>;
}

function isDeny(action: unknown): boolean {
	return action === "deny" || (typeof action === "object" && action !== null && (action as PatternMap).action === "deny");
}

/** Global deny rules on `key` that a project-level `pattern: allow` would override. */
function shadowedDenies(globalConfigPath: string, key: string, pattern: string): [string, unknown][] {
	let permission: PatternMap;
	try {
		permission = (readConfig(globalConfigPath).permission ?? {}) as PatternMap;
	} catch {
		return [];
	}
	// Bare path/external_directory entries also apply to their _read/_write keys.
	const keys = new Set([key, key.replace(/_(read|write)$/, "")]);
	const denies = new Map<string, unknown>();
	for (const k of keys) {
		const map = permission[k];
		if (typeof map !== "object" || map === null) continue;
		for (const [denyPattern, action] of Object.entries(map)) {
			if (isDeny(action) && globsOverlap(expandHome(pattern), expandHome(denyPattern))) {
				denies.set(denyPattern, action);
			}
		}
	}
	return [...denies];
}

function ellipsize(text: string, max: number): string {
	const line = text.replace(/\s+/g, " ");
	return line.length > max ? `${line.slice(0, max - 1)}…` : line;
}

export default function (pi: ExtensionAPI) {
	pi.events.on("permissions:decision", (raw) => {
		const event = raw as { surface?: unknown; value?: unknown; resolution?: unknown };
		if (typeof event.surface !== "string" || typeof event.value !== "string") return;
		if (event.resolution !== "user_approved" && event.resolution !== "user_approved_for_session") return;
		remember({ surface: event.surface, value: event.value });
	});

	pi.registerCommand("allow", {
		description: "Save a permission you approved as a rule for this project",
		handler: async (_args, ctx) => {
			if (recent.length === 0) {
				ctx.ui.notify("No approved permission prompts yet in this pi process", "info");
				return;
			}

			const labels = recent.map((a, i) => `${i + 1}. [${a.surface}] ${ellipsize(a.value, 90)}`);
			const picked = await ctx.ui.select("Save which approval for this project?", labels);
			if (!picked) return;
			const approval = recent[labels.indexOf(picked)];

			const rule = suggestRule(approval, ctx.cwd);
			let keptDenies: [string, unknown][] = [];
			if (rule.pattern !== null) {
				const save = rule.pattern ? `Allow "${rule.pattern}" on ${rule.key}` : undefined;
				const choice = await ctx.ui.select(
					`[${approval.surface}] ${ellipsize(approval.value, 90)}`,
					[...(save ? [save] : []), "Edit pattern", "Cancel"],
				);
				if (!choice || choice === "Cancel") return;
				if (choice === "Edit pattern") {
					const edited = await ctx.ui.editor(`Pattern for ${rule.key} (* = anything, ? = one char)`, rule.pattern);
					rule.pattern = edited?.trim().split("\n")[0].trim() ?? "";
					if (!rule.pattern) return;
				}

				const globalConfigPath = join(process.env.PI_CODING_AGENT_DIR ?? join(homedir(), ".pi", "agent"), CONFIG_REL);
				keptDenies = shadowedDenies(globalConfigPath, rule.key, rule.pattern);
				if (keptDenies.length > 0) {
					const names = keptDenies.map(([d]) => `"${d}"`).join(", ");
					if (keptDenies.some(([d]) => !d.includes("*"))) {
						ctx.ui.notify(`Not saved: "${rule.pattern}" would override the global deny ${names}. Run /allow again with a narrower pattern.`, "error");
						return;
					}
					const keep = `Save, and keep ${keptDenies.length === 1 ? "that deny" : "those denies"} on top`;
					const answer = await ctx.ui.select(`"${rule.pattern}" overlaps the global deny ${names}`, [keep, "Cancel"]);
					if (answer !== keep) return;
				}
			} else {
				const ok = await ctx.ui.confirm(`Allow every '${rule.key}' call in this project?`, ctx.cwd);
				if (!ok) return;
			}

			const configPath = join(ctx.cwd, ".pi", CONFIG_REL);
			let config: Record<string, unknown>;
			try {
				config = readConfig(configPath);
			} catch (error) {
				ctx.ui.notify(`Not saved: ${configPath} is not plain JSON (${(error as Error).message})`, "error");
				return;
			}

			const existing = config.permission;
			const permission: PatternMap = typeof existing === "object" && existing !== null ? (existing as PatternMap) : {};
			if (rule.pattern === null) {
				permission[rule.key] = "allow";
			} else {
				const current = permission[rule.key];
				const map: PatternMap =
					typeof current === "object" && current !== null
						? (current as PatternMap)
						: typeof current === "string"
							? { "*": current }
							: {};
				// Re-insert so the rule is last in the map, where it wins.
				delete map[rule.pattern];
				map[rule.pattern] = "allow";
				for (const [denyPattern, action] of keptDenies) {
					const respelled = denyPattern.replace("*", "**");
					delete map[respelled];
					map[respelled] = action;
				}
				permission[rule.key] = map;
			}
			config.permission = permission;

			mkdirSync(dirname(configPath), { recursive: true });
			writeFileSync(configPath, `${JSON.stringify(config, null, 2)}\n`);

			const what = rule.pattern === null ? rule.key : `${rule.key}: "${rule.pattern}"`;
			if (ctx.isProjectTrusted()) {
				ctx.ui.notify(`Saved ${what} -> ${tildify(configPath)}`, "info");
			} else {
				ctx.ui.notify(`Saved ${what}, but this project is not trusted so it is ignored. Run /trust, then restart pi.`, "warning");
			}
		},
	});
}
