/**
 * Drop tools that a model's provider or gateway cannot handle, just before
 * the request leaves pi. Some managed gateways (e.g. a LiteLLM proxy in a
 * client org) translate a function tool named "web_search" into provider
 * params the backend rejects, or simply don't permit web access at all;
 * stripping those tools client-side avoids hard errors and keeps the agent
 * degrading gracefully.
 *
 * The capability is generic; the model->tool mapping is machine-local and
 * lives in config.local.json next to this file (gitignored, see
 * config.local.json.example). No config file -> no-op.
 * Rules are read once per pi process; restart pi after editing the config.
 */

import { existsSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

type Rule = { modelPrefixes: string[]; dropTools: string[]; reason?: string };

const CONFIG_PATH = join(
	process.env.PI_CODING_AGENT_DIR ?? join(homedir(), ".pi", "agent"),
	"extensions",
	"drop-unsupported-tools",
	"config.local.json",
);

function loadRules(): Rule[] {
	if (!existsSync(CONFIG_PATH)) return [];
	try {
		const parsed = JSON.parse(readFileSync(CONFIG_PATH, "utf8")) as { rules?: unknown };
		if (!Array.isArray(parsed.rules)) return [];
		return parsed.rules.filter(
			(r): r is Rule => Array.isArray((r as Rule)?.modelPrefixes) && Array.isArray((r as Rule)?.dropTools),
		);
	} catch (error) {
		console.error(`drop-unsupported-tools: ignoring unreadable ${CONFIG_PATH}: ${(error as Error).message}`);
		return [];
	}
}

export default function (pi: ExtensionAPI) {
	const rules = loadRules();
	if (rules.length === 0) return;

	// Notify once per model so the missing capability is visible, not baffling.
	const notified = new Set<string>();

	pi.on("before_provider_request", (event, ctx) => {
		const modelId = ctx.model?.id;
		if (!modelId) return;
		const rule = rules.find((r) => r.modelPrefixes.some((prefix) => modelId.startsWith(prefix)));
		if (!rule) return;

		const payload = event.payload as Record<string, unknown>;
		const tools = payload.tools as Array<Record<string, unknown>> | undefined;
		if (!tools?.length) return;

		const drop = new Set(rule.dropTools);
		const filtered = tools.filter((tool) => !drop.has(tool.name as string));
		if (filtered.length === tools.length) return;

		if (!notified.has(modelId)) {
			notified.add(modelId);
			const count = tools.length - filtered.length;
			const why = rule.reason ? ` (${rule.reason})` : "";
			(ctx as { ui?: { notify?: (message: string, level: string) => void } }).ui?.notify?.(
				`Dropped ${count} unsupported tool${count === 1 ? "" : "s"} for ${modelId}${why}`,
				"warning",
			);
		}

		return { ...payload, tools: filtered };
	});
}
