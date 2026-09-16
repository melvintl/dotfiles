/**
 * flow-log - write a human-readable trace of the agent loop to a markdown file.
 *
 * Purpose: understanding how the harness works, not ops monitoring. For every
 * prompt it logs the chain of events in order:
 *
 *   USER PROMPT -> LLM REQUEST (the exact provider payload: system prompt,
 *   message history, tool schemas) -> LLM RESPONSE (stop reason, usage, text,
 *   tool calls) -> TOOL execution (args, result) -> next request ...
 *
 * The provider payload is dumped in full on every request. That is deliberate:
 * seeing the whole context re-sent (and growing) each turn is the core insight
 * into how an agent harness works. Tool results are truncated in the TOOL
 * section since they reappear verbatim inside the next request payload.
 *
 * One file per session under ~/.pi/agent/flow-logs/. `/flow-log` prints the
 * current file's path.
 */

import { appendFileSync, mkdirSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const MAX_TOOL_RESULT_CHARS = 3000;

let logFile: string | undefined;
let requestNo = 0;

function logPath(): string {
	if (!logFile) {
		const dir = join(process.env.PI_CODING_AGENT_DIR ?? join(homedir(), ".pi", "agent"), "flow-logs");
		mkdirSync(dir, { recursive: true });
		logFile = join(dir, `${new Date().toISOString().replace(/[:.]/g, "-")}.md`);
	}
	return logFile as string;
}

function write(text: string): void {
	appendFileSync(logPath(), `${text}\n`);
}

function json(value: unknown): string {
	try {
		return JSON.stringify(value, null, 2);
	} catch {
		return String(value);
	}
}

function fenced(value: unknown): string {
	return `\`\`\`json\n${json(value)}\n\`\`\``;
}

function truncate(text: string, max: number): string {
	return text.length > max ? `${text.slice(0, max)}\n… [truncated ${text.length - max} of ${text.length} chars]` : text;
}

/** Pull the plain text out of an AgentMessage content array (string or {type:"text"} blocks). */
function textOf(message: any): string {
	const content = message?.content;
	if (typeof content === "string") return content;
	if (Array.isArray(content)) {
		return content
			.filter((block: any) => block?.type === "text")
			.map((block: any) => block.text)
			.join("\n");
	}
	return "";
}

export default function (pi: ExtensionAPI) {
	pi.on("session_start", async () => {
		// New session (startup, /new, /resume, /fork) starts a fresh log file.
		logFile = undefined;
		requestNo = 0;
	});

	pi.on("before_agent_start", async (event) => {
		write(`\n# USER PROMPT\n\n${event.prompt}\n`);
		write(`_system prompt: ${event.systemPrompt.length} chars (full text inside every request payload below)_\n`);
	});

	pi.on("before_provider_request", async (event, ctx) => {
		requestNo++;
		const model = ctx.model ? `${ctx.model.provider}/${ctx.model.id}` : "unknown";
		write(`\n## → LLM REQUEST #${requestNo} (${model})\n`);
		write("The exact payload sent to the provider — system prompt, full message history, tool schemas:\n");
		write(fenced(event.payload));
	});

	pi.on("after_provider_response", async (event) => {
		write(`\n## ← LLM RESPONSE #${requestNo} (HTTP ${event.status})\n`);
	});

	pi.on("message_end", async (event) => {
		const message: any = event.message;
		if (message?.role !== "assistant") return;
		const usage = message.usage
			? `input=${message.usage.input ?? "?"} output=${message.usage.output ?? "?"} cacheRead=${message.usage.cacheRead ?? 0}`
			: "usage unavailable";
		write(`stopReason=\`${message.stopReason ?? "?"}\` · ${usage}\n`);
		const text = textOf(message);
		if (text.trim()) write(`**assistant text:**\n\n${text}\n`);
		const toolCalls = Array.isArray(message.content) ? message.content.filter((block: any) => block?.type === "toolCall") : [];
		for (const call of toolCalls) {
			write(`**requests tool call** \`${call.name}\` (${call.id}):\n${fenced(call.arguments)}`);
		}
	});

	pi.on("tool_execution_start", async (event) => {
		write(`\n### ⚙ TOOL ${event.toolName} start (${event.toolCallId})\n${fenced(event.args)}`);
	});

	pi.on("tool_execution_end", async (event) => {
		const status = event.isError ? "ERROR" : "ok";
		const output = typeof event.result === "string" ? event.result : textOf(event.result) || json(event.result);
		write(`\n### ⚙ TOOL ${event.toolName} end — ${status}\n\n\`\`\`\n${truncate(output, MAX_TOOL_RESULT_CHARS)}\n\`\`\``);
	});

	pi.on("turn_end", async (event) => {
		write(`\n---\n_turn ${event.turnIndex} complete_\n`);
	});

	pi.registerCommand("flow-log", {
		description: "Show the path of the current flow log file",
		handler: async (_args, ctx) => {
			ctx.ui.notify(logFile ?? `No flow log yet this session (will be created under ~/.pi/agent/flow-logs/)`, "info");
		},
	});
}
