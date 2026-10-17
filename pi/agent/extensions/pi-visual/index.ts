/**
 * pi-visual - let the model answer with a page instead of prose.
 *
 * `render_ui` takes a title and HTML body, saves a self-contained One Dark page
 * to the visuals directory and returns its URL. A small static server serves
 * the directory, and index.html lists every page newest first. The `visual`
 * skill bundled here holds the page contract (libraries, layout, when to draw).
 *
 * Thin wrapper: the work lives in core.ts and server.ts, which have no pi
 * imports, so a pi-durable browser facet can replace this file later.
 *
 * Environment:
 *   PI_VISUAL_DIR   where pages go          (~/.pi/agent/visuals)
 *   PI_VISUAL_PORT  server port             (4178)
 *   PI_VISUAL_URL   base URL shown in links (http://localhost:<port>)
 *                   set to the `tailscale serve` URL to get phone-ready links
 *
 * `/visuals` shows the index URL; `/visuals open` opens the newest page.
 */

import { spawn } from "node:child_process";
import { homedir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { Type } from "@earendil-works/pi-ai";
import { defineTool, type ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { listPages, saveVisual } from "./core.ts";
import { serve } from "./server.ts";

const HERE = dirname(fileURLToPath(import.meta.url));
const DIR = process.env.PI_VISUAL_DIR ?? join(process.env.PI_CODING_AGENT_DIR ?? join(homedir(), ".pi", "agent"), "visuals");
const PORT = Number(process.env.PI_VISUAL_PORT ?? 4178);
const BASE_URL = (process.env.PI_VISUAL_URL ?? `http://localhost:${PORT}`).replace(/\/+$/, "");

// Module state is shared by every session in this process (subagents included).
let serving: Promise<unknown> | undefined;

function ensureServer(): Promise<unknown> {
	serving ??= serve(DIR, PORT).catch((err) => {
		serving = undefined;
		throw err;
	});
	return serving;
}

function openInBrowser(url: string): void {
	const cmd = process.platform === "darwin" ? "open" : "xdg-open";
	spawn(cmd, [url], { detached: true, stdio: "ignore" }).on("error", () => {}).unref();
}

const renderUi = defineTool({
	name: "render_ui",
	label: "Render UI",
	description:
		"Publish an HTML page (diagram, chart, interactive explainer, comparison) and get back a URL the user can open in a browser or on their phone. " +
		"Scripts may load only from cdn.jsdelivr.net, cdnjs.cloudflare.com or unpkg.com, and the page cannot fetch from anywhere else, so inline the data. " +
		"Read the `visual` skill before the first call in a session.",
	promptSnippet: "render_ui: publish an HTML visual (diagram, chart, interactive explainer) and return its URL",
	promptGuidelines: [
		"Use render_ui when structure, a process, a comparison or data is clearer seen than read. Plain questions still get plain text.",
		"After render_ui, reply with the URL and at most two lines on what the page shows. Do not restate the page in prose.",
	],
	parameters: Type.Object({
		title: Type.String({ description: "Short page title, 2-6 words" }),
		html: Type.String({ description: "Body markup: elements plus inline <style>/<script>. No <html>, <head> or <body>." }),
	}),

	async execute(_toolCallId, params) {
		const saved = saveVisual(DIR, { title: params.title, html: params.html });
		let note = "";
		try {
			await ensureServer();
		} catch (err) {
			note = `\nServer not running (${(err as Error).message}); open the file directly: ${saved.file}`;
		}
		const url = `${BASE_URL}/${encodeURIComponent(saved.name)}`;
		return {
			content: [{ type: "text", text: `Published "${params.title}": ${url}${note}` }],
			details: { url, file: saved.file },
		};
	},
});

export default function (pi: ExtensionAPI) {
	pi.registerTool(renderUi);

	pi.on("resources_discover", async () => ({ skillPaths: [join(HERE, "skills")] }));

	pi.registerCommand("visuals", {
		description: "Show the visuals index URL; 'open' opens the newest page in the browser",
		handler: async (args, ctx) => {
			try {
				await ensureServer();
			} catch (err) {
				ctx.ui.notify(`pi-visual server failed: ${(err as Error).message}`, "error");
				return;
			}
			if (String(args ?? "").trim().toLowerCase() === "open") {
				const name = listPages(DIR)[0];
				if (!name) {
					ctx.ui.notify("No visuals yet", "info");
					return;
				}
				openInBrowser(`${BASE_URL}/${encodeURIComponent(name)}`);
				return;
			}
			ctx.ui.notify(`Visuals: ${BASE_URL}/ · files in ${DIR}`, "info");
		},
	});
}
