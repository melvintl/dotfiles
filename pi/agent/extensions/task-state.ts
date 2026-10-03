/**
 * Per-worktree task state in TASK.md.
 *
 * The worktree, not the conversation, holds the task: Objective, State,
 * Decisions, Open items, Gotchas (the handoff format). A new session, a model
 * switch or a compaction resumes from the same file.
 *
 * - before_agent_start: injects <git toplevel>/TASK.md as a `task_state`
 *   system prompt section, read fresh every run so edits are picked up.
 * - session_start: one-line "Resuming: <objective>" notice.
 * - /task shows the path and objective; /task init writes a skeleton.
 * - session_before_compact: Pi does not read back a mutated
 *   `customInstructions`, so the summary is generated here with the built-in
 *   compact() plus an extra instruction. Any failure falls back to Pi's own
 *   compaction.
 */

import { existsSync, readFileSync, statSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { compact } from "@earendil-works/pi-coding-agent";

const COMPACT_INSTRUCTIONS =
	"Write the summary as a development handoff. The task's objective, decisions and open items " +
	"are tracked in TASK.md, which is re-injected every turn, but keep every decision, rejected " +
	"approach and open item from this conversation anyway: some may not be in TASK.md yet.";

/** Nearest ancestor of `cwd` containing `.git` (a directory, or a file in a worktree). */
function gitRoot(cwd: string): string | undefined {
	for (let dir = cwd; ; dir = dirname(dir)) {
		if (existsSync(join(dir, ".git"))) return dir;
		if (dirname(dir) === dir) return undefined;
	}
}

function taskPath(cwd: string): string | undefined {
	const root = gitRoot(cwd);
	return root && join(root, "TASK.md");
}

function readTask(cwd: string): { path: string; content: string } | undefined {
	const path = taskPath(cwd);
	if (!path || !existsSync(path) || !statSync(path).isFile()) return undefined;
	const content = readFileSync(path, "utf8").trim();
	return content ? { path, content } : undefined;
}

/** First non-empty line under `## Objective`. */
function objective(content: string): string | undefined {
	const match = /^##\s+Objective\s*\n+([^\n#][^\n]*)/m.exec(content);
	return match?.[1].trim();
}

function skeleton(branch: string): string {
	return `## Objective
${branch ? `Branch \`${branch}\`: ` : ""}<what the work is for and what "done" looks like>

## State
- Verification: not run

## Decisions

## Open items
1.

## Gotchas
`;
}

export default function (pi: ExtensionAPI) {
	pi.on("before_agent_start", async (event, ctx) => {
		const task = readTask(ctx.cwd);
		if (!task) return;
		event.systemPromptOptions.sections = {
			...event.systemPromptOptions.sections,
			task_state: `Current task state, from ${task.path}. Keep this file up to date.\n\n${task.content}`,
		};
	});

	pi.on("session_start", async (_event, ctx) => {
		const task = readTask(ctx.cwd);
		if (!task) return;
		ctx.ui.notify(`Resuming: ${objective(task.content) ?? task.path}`, "info");
	});

	pi.registerCommand("task", {
		description: "Show TASK.md for this worktree; `/task init` creates it",
		handler: async (args, ctx) => {
			const path = taskPath(ctx.cwd);
			if (!path) {
				ctx.ui.notify("Not in a git repository", "error");
				return;
			}
			if (args.trim() === "init") {
				if (existsSync(path)) {
					ctx.ui.notify(`${path} already exists`, "warning");
					return;
				}
				const branch = await pi.exec("git", ["branch", "--show-current"], { cwd: ctx.cwd });
				writeFileSync(path, skeleton(branch.code === 0 ? branch.stdout.trim() : ""));
				ctx.ui.notify(`Created ${path}`, "info");
				return;
			}
			const task = readTask(ctx.cwd);
			ctx.ui.notify(
				task ? `${task.path}\n${objective(task.content) ?? "(no objective)"}` : `No ${path} (/task init)`,
				"info",
			);
		},
	});

	pi.on("session_before_compact", async (event, ctx) => {
		const model = ctx.model;
		if (!model || !readTask(ctx.cwd)) return;
		try {
			const auth = await ctx.modelRegistry.getApiKeyAndHeaders(model);
			if (!auth.ok) return;
			const instructions = [event.customInstructions, COMPACT_INSTRUCTIONS].filter(Boolean).join("\n\n");
			// A null header value marks a provider default header as deleted.
			const headers = Object.fromEntries(
				Object.entries(auth.headers ?? {}).filter((entry): entry is [string, string] => entry[1] !== null),
			);
			const compaction = await compact(
				event.preparation,
				auth.baseUrl ? { ...model, baseUrl: auth.baseUrl } : model,
				auth.apiKey,
				headers,
				instructions,
				event.signal,
				pi.getThinkingLevel(),
				undefined,
				auth.env,
			);
			return { compaction };
		} catch {
			return;
		}
	});
}
