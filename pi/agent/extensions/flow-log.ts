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
 * The provider payload is dumped in full only on request #1 (system prompt and
 * tool schemas are identical on every request, and the message history is
 * cumulative). Later requests log just the messages added since the previous
 * request plus a summary line — the trace stays complete without the O(n^2)
 * repetition. Tool results are truncated in the TOOL section since they also
 * appear inside the request payload.
 *
 * Off by default. Enable at startup with PI_FLOW_LOG=1, or mid-session with
 * `/flow-log on` (the next request is then logged as #1 with the full payload,
 * which contains the entire prior history — nothing is lost by enabling late).
 * `/flow-log off` stops logging; `/flow-log` shows status and the file path.
 * One file per session under ~/.pi/agent/flow-logs/.
 */

import { appendFileSync, mkdirSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const MAX_TOOL_RESULT_CHARS = 3000;

let logFile: string | undefined;
let requestNo = 0;
let loggedMessageCount = 0;
let enabled = !!process.env.PI_FLOW_LOG && process.env.PI_FLOW_LOG !== "0";

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
		loggedMessageCount = 0;
	});

	pi.on("before_agent_start", async (event) => {
		if (!enabled) return;
		write(`\n# USER PROMPT\n\n${event.prompt}\n`);
		write(`_system prompt: ${event.systemPrompt.length} chars (full text inside every request payload below)_\n`);
	});

	pi.on("before_provider_request", async (event, ctx) => {
		if (!enabled) return;
		requestNo++;
		const model = ctx.model ? `${ctx.model.provider}/${ctx.model.id}` : "unknown";
		write(`\n## → LLM REQUEST #${requestNo} (${model})\n`);
		const payload: any = event.payload;
		const messages = Array.isArray(payload?.messages) ? payload.messages : undefined;
		if (requestNo === 1 || !messages) {
			// Full payload once per session (or as fallback if the payload shape is
			// unrecognized): system prompt and tool schemas never change after this.
			write("The exact payload sent to the provider — system prompt, full message history, tool schemas:\n");
			write(fenced(payload));
		} else {
			const fresh = messages.slice(loggedMessageCount);
			write(
				`messages=${messages.length} (${fresh.length} new) · system prompt + tool schemas unchanged — full payload in request #1\n`,
			);
			if (fresh.length > 0) write(fenced(fresh));
		}
		if (messages) loggedMessageCount = messages.length;
	});

	pi.on("after_provider_response", async (event) => {
		if (!enabled) return;
		write(`\n## ← LLM RESPONSE #${requestNo} (HTTP ${event.status})\n`);
	});

	pi.on("message_end", async (event) => {
		if (!enabled) return;
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
		if (!enabled) return;
		write(`\n### ⚙ TOOL ${event.toolName} start (${event.toolCallId})\n${fenced(event.args)}`);
	});

	pi.on("tool_execution_end", async (event) => {
		if (!enabled) return;
		const status = event.isError ? "ERROR" : "ok";
		const output = typeof event.result === "string" ? event.result : textOf(event.result) || json(event.result);
		write(`\n### ⚙ TOOL ${event.toolName} end — ${status}\n\n\`\`\`\n${truncate(output, MAX_TOOL_RESULT_CHARS)}\n\`\`\``);
	});

	pi.on("turn_end", async (event) => {
		if (!enabled) return;
		write(`\n---\n_turn ${event.turnIndex} complete_\n`);
	});

	pi.registerCommand("flow-log", {
		description: "flow-log status and file path; 'on'/'off' toggles logging",
		handler: async (args, ctx) => {
			const arg = String(args ?? "")
				.trim()
				.toLowerCase();
			if (arg === "on") {
				if (!enabled) {
					enabled = true;
					// Log the next request as #1 with the full payload — it carries the
					// entire history, so enabling late loses nothing.
					requestNo = 0;
					loggedMessageCount = 0;
				}
				ctx.ui.notify(`flow-log on — logging to ${logFile ?? "~/.pi/agent/flow-logs/ (file created on next event)"}`, "info");
			} else if (arg === "off") {
				enabled = false;
				ctx.ui.notify("flow-log off", "info");
			} else {
				ctx.ui.notify(
					`flow-log is ${enabled ? "on" : "off"} · ${logFile ?? "no file yet this session"} · use /flow-log on|off (PI_FLOW_LOG=1 enables at startup)`,
					"info",
				);
			}
		},
	});
}
