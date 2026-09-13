/**
 * Collapsed startup info for Pi.
 *
 * Pi's default startup screen can take a lot of vertical space when many skills,
 * prompt templates, extensions, and themes are installed. This extension keeps
 * startup compact by replacing the normal startup header with a one-line summary
 * and relying on the user's `quietStartup` setting to suppress the expanded
 * resource listing.
 *
 * The replacement header implements `setExpanded()`, so Pi's tool-output toggle
 * (`app.tools.expand`, Ctrl+O by default) expands it into the full keybinding
 * hints plus the loaded resources, exactly like the built-in header does, and
 * collapses it back to the one-liner on the next press.
 *
 * It also provides `/startup-info`, which renders the loaded Context files
 * (SYSTEM.md, APPEND_SYSTEM.md, AGENTS.md/CLAUDE.md), Skills, Prompts,
 * Extensions, and Themes on demand as a TUI-only custom entry. That gives quick
 * access to the same kind of information without forcing it to occupy screen
 * space every time Pi starts.
 *
 * On initial startup only, the extension clears the terminal before Pi renders so
 * the shell prompt used to launch `pi` is not left above the TUI. It deliberately
 * does not clear the screen on `/reload`, `/new`, `/resume`, or `/fork`.
 */

import { existsSync, readFileSync, statSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, isAbsolute, join, relative, resolve } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { VERSION, keyHint, keyText, rawKeyHint } from "@earendil-works/pi-coding-agent";
import { Box, Text, truncateToWidth, wrapTextWithAnsi } from "@earendil-works/pi-tui";

interface StartupInfoData {
	lines: string[];
	timestamp: number;
}

function uniq(values: string[]): string[] {
	return [...new Set(values.filter(Boolean))].sort((a, b) => a.localeCompare(b));
}

function formatSection(title: string, values: string[]): string[] {
	return values.length > 0 ? [`[${title}]`, `  ${values.join(", ")}`] : [`[${title}]`, "  none"];
}

function formatContextPath(p: string, cwd: string): string {
	const abs = isAbsolute(p) ? resolve(p) : resolve(cwd, p);
	const rel = relative(resolve(cwd), abs);
	const inside = rel === "" || (rel !== ".." && !rel.startsWith("../") && !isAbsolute(rel));
	if (inside) return rel || ".";
	const home = homedir();
	return abs === home || abs.startsWith(`${home}/`) ? `~${abs.slice(home.length)}` : abs;
}

/**
 * Locate the SYSTEM.md / APPEND_SYSTEM.md file Pi loaded. The extension API only
 * exposes the loaded text, not the path, so mirror Pi's discovery order (project
 * `.pi/<name>` first, then the global agent dir) and pick the candidate whose
 * contents match what was actually loaded. This avoids listing a project file
 * that Pi skipped because the project is untrusted.
 */
function findPromptFile(name: string, loadedText: string | undefined, cwd: string): string | undefined {
	if (!loadedText?.trim()) return undefined;
	const candidates = [join(cwd, ".pi", name), join(agentDir(), name)].filter((p) => existsSync(p));
	const wanted = loadedText.trim();
	for (const candidate of candidates) {
		try {
			if (readFileSync(candidate, "utf8").trim() === wanted) return candidate;
		} catch {}
	}
	return candidates[0];
}

function agentDir(): string {
	return process.env.PI_CODING_AGENT_DIR ?? join(homedir(), ".pi", "agent");
}

const CONTEXT_FILE_NAMES = ["AGENTS.override.md", "AGENTS.md", "AGENTS.MD", "CLAUDE.md", "CLAUDE.MD"];

function contextFileInDir(dir: string): string | undefined {
	for (const name of CONTEXT_FILE_NAMES) {
		const candidate = join(dir, name);
		try {
			if (existsSync(candidate) && statSync(candidate).isFile()) return candidate;
		} catch {}
	}
	return undefined;
}

/**
 * Mirror of Pi's `loadProjectContextFiles`: the global agent-dir context file first,
 * then one file per ancestor directory from the filesystem root down to cwd.
 * Used when the accurate list is unavailable (see collectContextFiles).
 */
function discoverContextFiles(cwd: string): string[] {
	const found: string[] = [];
	const global = contextFileInDir(agentDir());
	if (global) found.push(global);
	const ancestors: string[] = [];
	let dir = resolve(cwd);
	while (true) {
		const file = contextFileInDir(dir);
		if (file && !found.includes(file)) ancestors.unshift(file);
		const parent = dirname(dir);
		if (parent === dir) break;
		dir = parent;
	}
	return [...found, ...ancestors];
}

/** Mirror of Pi's SYSTEM.md / APPEND_SYSTEM.md discovery: trusted project file, else global. */
function discoverPromptFile(name: string, cwd: string, trusted: boolean): string | undefined {
	const projectPath = join(cwd, ".pi", name);
	if (trusted && existsSync(projectPath)) return projectPath;
	const globalPath = join(agentDir(), name);
	return existsSync(globalPath) ? globalPath : undefined;
}

/**
 * Only command contexts expose `getSystemPromptOptions()`, which reflects what Pi
 * really loaded (including `--no-context-files`, `--system-prompt`, etc.). Event
 * contexts such as `session_start` do not, so the header falls back to
 * re-running Pi's discovery rules against the filesystem.
 */
function collectContextFiles(ctx: any): string[] {
	const cwd: string = ctx.cwd ?? process.cwd();
	const paths: string[] = [];
	if (typeof ctx.getSystemPromptOptions === "function") {
		const options = ctx.getSystemPromptOptions();
		const systemFile = findPromptFile("SYSTEM.md", options?.customPrompt, cwd);
		if (systemFile) paths.push(systemFile);
		const appendFile = findPromptFile("APPEND_SYSTEM.md", options?.appendSystemPrompt, cwd);
		if (appendFile) paths.push(appendFile);
		for (const file of options?.contextFiles ?? []) {
			if (file?.path) paths.push(file.path);
		}
	} else {
		const trusted = ctx.isProjectTrusted?.() === true;
		const systemFile = discoverPromptFile("SYSTEM.md", cwd, trusted);
		if (systemFile) paths.push(systemFile);
		const appendFile = discoverPromptFile("APPEND_SYSTEM.md", cwd, trusted);
		if (appendFile) paths.push(appendFile);
		paths.push(...discoverContextFiles(cwd));
	}
	return [...new Set(paths)].map((p) => formatContextPath(p, cwd));
}

function sourceLabel(command: any): string {
	const info = command?.sourceInfo;
	return info?.source || info?.path?.split("/").filter(Boolean).at(-1) || command?.name || "unknown";
}

/** Plain-text lines describing loaded resources; shared by the header and the command. */
function collectResourceLines(pi: ExtensionAPI, ctx: any): string[] {
	const commands = pi.getCommands();
	const contextFiles = collectContextFiles(ctx);
	const skills = uniq(commands.filter((c: any) => c.source === "skill").map((c: any) => c.name.replace(/^skill:/, "")));
	const prompts = uniq(commands.filter((c: any) => c.source === "prompt").map((c: any) => `/${c.name}`));
	const extensions = uniq(commands.filter((c: any) => c.source === "extension").map(sourceLabel));
	const themes = ctx.mode === "tui" ? uniq((ctx.ui.getAllThemes?.() ?? []).map((t: any) => t.name)) : [];
	return [
		...formatSection("Context", contextFiles),
		"",
		...formatSection("Skills", skills),
		"",
		...formatSection("Prompts", prompts),
		"",
		...formatSection("Extensions", extensions),
		"",
		...formatSection("Themes", themes),
	];
}

function styleResourceLine(theme: any, line: string): string {
	return line.startsWith("[") && line.endsWith("]") ? theme.fg("accent", line) : theme.fg("muted", line);
}

/** Same hint list as Pi's built-in expanded header; keyHint() honours keybindings.json. */
function expandedHints(theme: any): string[] {
	return [
		keyHint("app.interrupt", "to interrupt"),
		keyHint("app.clear", "to clear"),
		rawKeyHint(`${keyText("app.clear")} twice`, "to exit"),
		keyHint("app.exit", "to exit (empty)"),
		keyHint("app.suspend", "to suspend"),
		keyHint("tui.editor.deleteToLineEnd", "to delete to end"),
		keyHint("app.thinking.cycle", "to cycle thinking level"),
		rawKeyHint(`${keyText("app.model.cycleForward")}/${keyText("app.model.cycleBackward")}`, "to cycle models"),
		keyHint("app.model.select", "to select model"),
		keyHint("app.tools.expand", "to expand tools"),
		keyHint("app.thinking.toggle", "to expand thinking"),
		keyHint("app.editor.external", "for external editor"),
		rawKeyHint("/", "for commands"),
		rawKeyHint("!", "to run bash"),
		rawKeyHint("!!", "to run bash (no context)"),
		keyHint("app.message.followUp", "to queue follow-up"),
		keyHint("app.message.dequeue", "to edit all queued messages"),
		keyHint("app.clipboard.pasteImage", "to paste image (with text fallback)"),
		rawKeyHint("drop files", "to attach"),
	].map((hint) => theme.fg("muted", hint));
}

/**
 * Header that Pi can expand/collapse through `setExpanded()`. Pi calls it with the
 * current tool-output state when the header is installed and on every toggle.
 */
function createHeader(pi: ExtensionAPI, ctx: any, tui: any, theme: any) {
	let expanded = false;
	const logo = `${theme.bold(theme.fg("accent", "pi"))} ${theme.fg("dim", `v${VERSION}`)}`;
	return {
		render(width: number): string[] {
			if (!expanded) {
				const line = `${logo} ${theme.fg("dim", "· resources collapsed · ")}${keyHint("app.tools.expand", "to expand")}${theme.fg("dim", " · ")}${theme.fg("accent", "/startup-info")}${theme.fg("dim", " to print")}`;
				return [truncateToWidth(line, width)];
			}
			const lines = [logo, ...expandedHints(theme), "", ...collectResourceLines(pi, ctx).map((line) => styleResourceLine(theme, line))];
			return lines.flatMap((line) => (line === "" ? [""] : wrapTextWithAnsi(line, width)));
		},
		invalidate() {},
		setExpanded(value: boolean) {
			if (expanded === value) return;
			expanded = value;
			tui.requestRender?.();
		},
	};
}

export default function (pi: ExtensionAPI) {
	pi.registerEntryRenderer<StartupInfoData>("startup-info", (entry, _state, theme) => {
		const data = entry.data ?? { lines: [], timestamp: Date.now() };
		const box = new Box(1, 1, (text) => theme.bg("customMessageBg", text));
		for (const line of data.lines) {
			box.addChild(new Text(styleResourceLine(theme, line), 0, 0));
		}
		return box;
	});

	pi.on("session_start", async (event, ctx) => {
		if (ctx.mode !== "tui") return;

		// Clear the terminal on initial Pi startup so the shell prompt used to launch
		// Pi is not left above the TUI. Keep /reload, /new, /resume, and /fork from
		// clearing the current transcript unexpectedly.
		if (event.reason === "startup") {
			process.stdout.write("\x1b[H\x1b[2J\x1b[3J");
		}

		ctx.ui.setHeader((tui: any, theme: any) => createHeader(pi, ctx, tui, theme));
	});

	pi.registerCommand("startup-info", {
		description: "Show loaded startup resources: skills, prompts, extensions, and themes",
		handler: async (_args, ctx) => {
			pi.appendEntry<StartupInfoData>("startup-info", {
				timestamp: Date.now(),
				lines: collectResourceLines(pi, ctx),
			});
		},
	});
}
