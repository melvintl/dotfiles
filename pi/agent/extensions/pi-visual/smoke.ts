/**
 * Smoke test for the pi-free half of pi-visual (core.ts, server.ts).
 * Run: node pi/agent/extensions/pi-visual/smoke.ts   (Node 23.6+ strips types)
 * pi only loads index.ts from this directory, so this file is never an extension.
 */

import { mkdtempSync, rmSync } from "node:fs";
import type { AddressInfo } from "node:net";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { createServer } from "node:http";
import { listPages, resolveRequest, saveVisual, slugify, validate } from "./core.ts";
import { serve } from "./server.ts";

const dir = mkdtempSync(join(tmpdir(), "pi-visual-"));
let failures = 0;
const check = (ok: unknown, label: string) => {
	console.log(`${ok ? "ok  " : "FAIL"} ${label}`);
	if (!ok) failures++;
};

try {
	const html = `<p>AG-UI streams agent events to a UI; MCP connects agents to tools.</p>
<pre class="mermaid">flowchart TD
  A[Agent] -->|AG-UI events| U[UI]
  A -->|MCP calls| T[Tools]</pre>
<script type="module">import mermaid from "https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs"; mermaid.initialize({ startOnLoad: true, theme: "dark" });</script>`;
	const now = new Date(2026, 9, 17, 14, 32);
	const a = saveVisual(dir, { title: "AG-UI vs MCP <test>", html }, now);
	const b = saveVisual(dir, { title: "AG-UI vs MCP <test>", html }, now);

	check(a.name === "2026-10-17-1432-ag-ui-vs-mcp-test.html", "file name is date-time-slug");
	check(b.name.endsWith("-2.html"), "same title in the same minute gets a suffix");
	check(slugify("!!!") === "visual", "empty slug falls back to 'visual'");
	for (const bad of ["<!doctype html><p>x</p>", "<html><p>x</p></html>", "<body>x</body>", "  "]) {
		let threw = false;
		try {
			validate({ title: "t", html: bad });
		} catch {
			threw = true;
		}
		check(threw, `rejects ${JSON.stringify(bad)}`);
	}
	check(resolveRequest(dir, "/../../etc/passwd") === undefined, "blocks path traversal");
	check(resolveRequest(dir, "/%2e%2e/%2e%2e/etc/hosts") === undefined, "blocks encoded traversal");
	check(resolveRequest(dir, "/x.ts") === undefined, "serves .html only");
	check(resolveRequest(dir, "/")?.endsWith("index.html"), "/ serves the index");

	const first = await serve(dir, 0);
	if (first === "shared") throw new Error("port 0 cannot be shared");
	const port = (first.address() as AddressInfo).port;
	check((await serve(dir, port)) === "shared", "second server on a taken port reports shared");
	const other = createServer((_req, res) => res.end()).listen(0, "127.0.0.1");
	await new Promise((r) => other.once("listening", r));
	const otherPort = (other.address() as AddressInfo).port;
	check(await serve(dir, otherPort).then(() => false, () => true), "a port held by another program is an error");
	other.close();
	check(listPages(dir)[0] === b.name && !listPages(dir).includes("index.html"), "listPages: pages only, newest first");

	const res = await fetch(`http://127.0.0.1:${port}/${a.name}`);
	const page = await res.text();
	check(res.status === 200, "serves a page");
	check(page.includes("Content-Security-Policy"), "page carries the CSP meta tag");
	check(page.includes("&#60;test&#62;"), "title is escaped");
	const index = await (await fetch(`http://127.0.0.1:${port}/`)).text();
	check(index.includes(encodeURIComponent(b.name)), "index lists pages");
	check((await fetch(`http://127.0.0.1:${port}/missing.html`)).status === 404, "missing page is 404");
	first.close();
} finally {
	rmSync(dir, { recursive: true, force: true });
}

console.log(failures ? `\n${failures} failed` : "\nall ok");
process.exit(failures ? 1 : 0);
