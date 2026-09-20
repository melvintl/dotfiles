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
 * /allow batch saves several recent approvals at once. It uses the same rule
 * suggestions as /allow, previews what will be written, and skips approvals
 * whose safe durable pattern cannot be inferred without manual narrowing.
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
type PreparedRule = { approval: Approval; rule: Rule; keptDenies: [string, unknown][] };
type SkippedRule = { approval: Approval; reason: string };
type AllowCommandContext = {
	cwd: string;
	isProjectTrusted(): boolean;
	ui: {
		select(title: string, options: string[]): Promise<string | undefined>;
		editor(title: string, initialText?: string): Promise<string | undefined>;
		confirm(title: string, message?: string): Promise<boolean>;
		notify(message: string, level: "info" | "warning" | "error"): void;
	};
};

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

function labelsForApprovals(approvals: Approval[]): string[] {
	return approvals.map((a, i) => `${i + 1}. [${a.surface}] ${ellipsize(a.value, 90)}`);
}

function describeRule(rule: Rule): string {
	return rule.pattern === null ? `${rule.key}: allow all` : `${rule.key}: "${rule.pattern}"`;
}

function projectConfigPath(cwd: string): string {
	return join(cwd, ".pi", CONFIG_REL);
}

function globalConfigPath(): string {
	return join(process.env.PI_CODING_AGENT_DIR ?? join(homedir(), ".pi", "agent"), CONFIG_REL);
}

function applyRule(permission: PatternMap, { rule, keptDenies }: PreparedRule) {
	if (rule.pattern === null) {
		permission[rule.key] = "allow";
		return;
	}

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

function writePreparedRules(configPath: string, prepared: PreparedRule[]) {
	const config = readConfig(configPath);
	const existing = config.permission;
	const permission: PatternMap = typeof existing === "object" && existing !== null ? (existing as PatternMap) : {};
	for (const item of prepared) applyRule(permission, item);
	config.permission = permission;

	mkdirSync(dirname(configPath), { recursive: true });
	writeFileSync(configPath, `${JSON.stringify(config, null, 2)}\n`);
}

function parseSelection(input: string, max: number): number[] {
	const selected = new Set<number>();
	const body = input
		.split("\n")
		.map((line) => line.replace(/#.*/, ""))
		.join(" ");
	for (const token of body.split(/[\s,]+/)) {
		if (!token) continue;
		const range = /^(\d+)-(\d+)$/.exec(token);
		if (range) {
			const start = Number(range[1]);
			const end = Number(range[2]);
			const step = start <= end ? 1 : -1;
			for (let n = start; n !== end + step; n += step) {
				if (n >= 1 && n <= max) selected.add(n - 1);
			}
			continue;
		}
		const numberedLine = /^(\d+)\.$/.exec(token);
		if (/^\d+$/.test(token) || numberedLine) {
			const n = Number(numberedLine?.[1] ?? token);
			if (n >= 1 && n <= max) selected.add(n - 1);
		}
	}
	return [...selected].sort((a, b) => a - b);
}

function prepareBatchRules(approvals: Approval[], cwd: string): { prepared: PreparedRule[]; skipped: SkippedRule[] } {
	const prepared: PreparedRule[] = [];
	const skipped: SkippedRule[] = [];
	const configPath = globalConfigPath();

	for (const approval of approvals) {
		const rule = suggestRule(approval, cwd);
		if (rule.pattern === "") {
			skipped.push({ approval, reason: "no safe path pattern could be inferred" });
			continue;
		}
		const keptDenies = rule.pattern === null ? [] : shadowedDenies(configPath, rule.key, rule.pattern);
		const unbatchable = keptDenies.filter(([pattern]) => !pattern.includes("*"));
		if (unbatchable.length > 0) {
			skipped.push({
				approval,
				reason: `suggested ${describeRule(rule)} overlaps exact global deny ${unbatchable.map(([d]) => `"${d}"`).join(", ")}`,
			});
			continue;
		}
		prepared.push({ approval, rule, keptDenies });
	}
	return { prepared, skipped };
}

function renderSelectionSheet(approvals: Approval[], cwd: string): string {
	const lines = [
		"# Enter approval numbers/ranges to save, e.g. 1,3-5",
		"# Lines starting with # are ignored. Leave blank to cancel.",
		"",
	];
	for (const [i, approval] of approvals.entries()) {
		const rule = suggestRule(approval, cwd);
		const target = rule.pattern === "" ? "needs manual /allow" : describeRule(rule);
		lines.push(`# ${i + 1}. [${approval.surface}] ${ellipsize(approval.value, 78)} -> ${target}`);
	}
	return `${lines.join("\n")}\n`;
}

async function saveSingleApproval(ctx: AllowCommandContext) {
	const labels = labelsForApprovals(recent);
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

		keptDenies = shadowedDenies(globalConfigPath(), rule.key, rule.pattern);
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

	const configPath = projectConfigPath(ctx.cwd);
	try {
		writePreparedRules(configPath, [{ approval, rule, keptDenies }]);
	} catch (error) {
		ctx.ui.notify(`Not saved: ${configPath} is not plain JSON (${(error as Error).message})`, "error");
		return;
	}

	const what = rule.pattern === null ? rule.key : `${rule.key}: "${rule.pattern}"`;
	if (ctx.isProjectTrusted()) {
		ctx.ui.notify(`Saved ${what} -> ${tildify(configPath)}`, "info");
	} else {
		ctx.ui.notify(`Saved ${what}, but this project is not trusted so it is ignored. Run /trust, then restart pi.`, "warning");
	}
}

async function saveBatchApprovals(ctx: AllowCommandContext) {
	const edited = await ctx.ui.editor("Batch /allow: numbers/ranges to save", renderSelectionSheet(recent, ctx.cwd));
	if (!edited) return;
	const indices = parseSelection(edited, recent.length);
	if (indices.length === 0) {
		ctx.ui.notify("No approvals selected", "info");
		return;
	}

	const approvals = indices.map((i) => recent[i]);
	const { prepared, skipped } = prepareBatchRules(approvals, ctx.cwd);
	if (prepared.length === 0) {
		ctx.ui.notify(`No batch-saveable approvals selected${skipped.length ? ` (${skipped.length} skipped)` : ""}`, "warning");
		return;
	}

	const preview = [
		`Save ${prepared.length} rule${prepared.length === 1 ? "" : "s"} to this project's permission config?`,
		"",
		...prepared.map(({ approval, rule, keptDenies }) => {
			const denyNote = keptDenies.length > 0 ? `; keep global denies ${keptDenies.map(([d]) => `"${d}"`).join(", ")}` : "";
			return `- [${approval.surface}] ${ellipsize(approval.value, 70)} -> ${describeRule(rule)}${denyNote}`;
		}),
		...(skipped.length > 0
			? ["", "Skipped:", ...skipped.map(({ approval, reason }) => `- [${approval.surface}] ${ellipsize(approval.value, 70)}: ${reason}`)]
			: []),
	].join("\n");
	const answer = await ctx.ui.select(preview, [`Save ${prepared.length} rule${prepared.length === 1 ? "" : "s"}`, "Cancel"]);
	if (!answer?.startsWith("Save ")) return;

	const configPath = projectConfigPath(ctx.cwd);
	try {
		writePreparedRules(configPath, prepared);
	} catch (error) {
		ctx.ui.notify(`Not saved: ${configPath} is not plain JSON (${(error as Error).message})`, "error");
		return;
	}

	const summary = `Saved ${prepared.length} rule${prepared.length === 1 ? "" : "s"}${skipped.length ? ` (${skipped.length} skipped)` : ""}`;
	if (ctx.isProjectTrusted()) {
		ctx.ui.notify(`${summary} -> ${tildify(configPath)}`, "info");
	} else {
		ctx.ui.notify(`${summary}, but this project is not trusted so it is ignored. Run /trust, then restart pi.`, "warning");
	}
}

export default function (pi: ExtensionAPI) {
	pi.events.on("permissions:decision", (raw: unknown) => {
		const event = raw as { surface?: unknown; value?: unknown; resolution?: unknown };
		if (typeof event.surface !== "string" || typeof event.value !== "string") return;
		if (event.resolution !== "user_approved" && event.resolution !== "user_approved_for_session") return;
		remember({ surface: event.surface, value: event.value });
	});

	pi.registerCommand("allow", {
		description: "Save approved permissions as project rules; use '/allow batch' for several",
		handler: async (args: string, ctx: AllowCommandContext) => {
			if (recent.length === 0) {
				ctx.ui.notify("No approved permission prompts yet in this pi process", "info");
				return;
			}

			if (args.trim() === "batch") {
				await saveBatchApprovals(ctx);
				return;
			}
			await saveSingleApproval(ctx);
		},
	});
}
