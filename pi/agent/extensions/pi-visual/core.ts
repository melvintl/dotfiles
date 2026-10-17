/**
 * pi-visual core - turn a model-written HTML body into a self-contained page on
 * disk and keep an index of every page.
 *
 * No pi imports on purpose. The pi wrapper (index.ts) and a future pi-durable
 * browser facet both call these functions; only the wrapper changes when the
 * runtime does.
 *
 * Every page gets the same shell: One Dark tokens, a layout that works from
 * phone to laptop width, and a Content-Security-Policy meta tag that only lets
 * scripts load from a short CDN allowlist and blocks fetch/XHR to anywhere
 * else. The meta tag applies whether the page is served or opened from disk.
 */

import { existsSync, mkdirSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import { join, resolve, sep } from "node:path";

const MAX_BODY_BYTES = 1_000_000;
const INDEX_FILE = "index.html";

/** Script origins a page may load from. */
const CDN_ORIGINS = ["https://cdn.jsdelivr.net", "https://cdnjs.cloudflare.com", "https://unpkg.com"];

const CSP = [
	"default-src 'none'",
	`script-src 'unsafe-inline' ${CDN_ORIGINS.join(" ")}`,
	`style-src 'unsafe-inline' ${CDN_ORIGINS.join(" ")} https://fonts.googleapis.com`,
	`font-src data: https://fonts.gstatic.com ${CDN_ORIGINS.join(" ")}`,
	`img-src data: blob: ${CDN_ORIGINS.join(" ")}`,
	`connect-src ${CDN_ORIGINS.join(" ")}`,
	"worker-src blob:",
	"base-uri 'none'",
	"form-action 'none'",
].join("; ");

// One Dark, matching themes/one-dark-tmux.json.
const BASE_CSS = `
:root {
	color-scheme: dark;
	--bg: #282c34; --panel: #30343c; --line: #3e4451; --fg: #abb2bf; --strong: #dcdfe4;
	--muted: #5c6370; --red: #e06c75; --green: #98c379; --yellow: #e5c07b;
	--blue: #61afef; --purple: #c678dd; --cyan: #56b6c2; --orange: #d19a66;
	--sans: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
	--mono: "JetBrainsMono Nerd Font", "JetBrains Mono", ui-monospace, monospace;
}
* { box-sizing: border-box; }
html, body { margin: 0; background: var(--bg); color: var(--fg); }
body { font: 16px/1.5 var(--sans); padding: 16px; max-width: 1400px; margin: 0 auto; overflow-x: hidden; }
@media (min-width: 1000px) { body { padding: 24px 32px; } }
/* Visual beside a side panel (controls, legend, details) on wide screens; stacked on narrow ones. */
.split { display: grid; gap: 16px; }
@media (min-width: 1000px) { .split { grid-template-columns: minmax(0, 1fr) 320px; align-items: start; } }
header.pv { display: flex; justify-content: space-between; align-items: baseline; gap: 12px;
	border-bottom: 1px solid var(--line); margin-bottom: 16px; padding-bottom: 8px; }
header.pv h1 { font-size: 1.25rem; margin: 0; color: var(--strong); }
header.pv a, header.pv time { color: var(--muted); font-size: 0.85rem; white-space: nowrap; }
a { color: var(--blue); }
h2, h3 { color: var(--strong); }
code, pre { font-family: var(--mono); font-size: 0.9em; }
pre { background: var(--panel); padding: 12px; border-radius: 6px; overflow-x: auto; }
canvas, img, video { max-width: 100%; height: auto; }
svg { max-width: 100%; }
table { border-collapse: collapse; width: 100%; }
th, td { border-bottom: 1px solid var(--line); padding: 6px 8px; text-align: left; }
button, select, input { font: inherit; color: var(--strong); background: var(--panel);
	border: 1px solid var(--line); border-radius: 6px; padding: 6px 10px; }
`;

interface Visual {
	title: string;
	/** Body markup: elements, <style> and <script> tags. Not a full document. */
	html: string;
}

interface SavedVisual {
	/** File name inside the visuals directory, also its URL path. */
	name: string;
	/** Absolute path on disk. */
	file: string;
}

function escapeHtml(text: string): string {
	return text.replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`);
}

export function slugify(title: string): string {
	const slug = title
		.toLowerCase()
		.normalize("NFKD")
		.replace(/[^a-z0-9]+/g, "-")
		.replace(/^-+|-+$/g, "")
		.slice(0, 60)
		.replace(/-+$/, "");
	return slug || "visual";
}

/** Throws with a message the model can act on when the body breaks the contract. */
export function validate(visual: Visual): void {
	if (!visual.title.trim()) throw new Error("title is empty");
	if (!visual.html.trim()) throw new Error("html is empty");
	if (Buffer.byteLength(visual.html) > MAX_BODY_BYTES) {
		throw new Error(`html is over ${MAX_BODY_BYTES} bytes; inline less data or simplify the page`);
	}
	if (/<!doctype|<html[\s>]|<head[\s>]|<body[\s>]/i.test(visual.html)) {
		throw new Error("send body markup only: no <!doctype>, <html>, <head> or <body>; the page shell is added for you");
	}
}

function pageShell(visual: Visual, now: Date): string {
	const title = escapeHtml(visual.title.trim());
	const { date, hh, mm } = clock(now);
	return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta http-equiv="Content-Security-Policy" content="${CSP}">
<title>${title}</title>
<style>${BASE_CSS}</style>
</head>
<body>
<header class="pv"><h1>${title}</h1><span><time datetime="${now.toISOString()}">${date} ${hh}:${mm}</time> · <a href="index.html">all</a></span></header>
${visual.html}
</body>
</html>
`;
}

/** Local date and time pieces for file names (2026-10-17-1432) and headers (2026-10-17 14:32). */
function clock(now: Date): { date: string; hh: string; mm: string } {
	const pad = (n: number) => String(n).padStart(2, "0");
	return {
		date: `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}`,
		hh: pad(now.getHours()),
		mm: pad(now.getMinutes()),
	};
}

export function saveVisual(dir: string, visual: Visual, now = new Date()): SavedVisual {
	validate(visual);
	mkdirSync(dir, { recursive: true });
	const { date, hh, mm } = clock(now);
	const base = `${date}-${hh}${mm}-${slugify(visual.title)}`;
	let name = `${base}.html`;
	for (let n = 2; existsSync(join(dir, name)); n++) name = `${base}-${n}.html`;
	const file = join(dir, name);
	writeFileSync(file, pageShell(visual, now));
	writeIndex(dir);
	return { name, file };
}

/** Matches the names saveVisual writes (2026-10-17-1432-slug.html), so other .html files in the directory stay out of the index. */
const PAGE_NAME = /^\d{4}-\d{2}-\d{2}-\d{4}-.+\.html$/;

/** Page file names, newest first. Names start with a local timestamp, so they sort by time. */
export function listPages(dir: string): string[] {
	if (!existsSync(dir)) return [];
	return readdirSync(dir)
		.filter((name) => PAGE_NAME.test(name))
		.map((name) => name.slice(0, -5)) // sort without ".html" so "x" < "x-2"
		.sort()
		.reverse()
		.map((base) => `${base}.html`);
}

/** Write index.html if it is missing, so the index URL works before the first page. */
export function ensureIndex(dir: string): void {
	if (existsSync(join(dir, INDEX_FILE))) return;
	mkdirSync(dir, { recursive: true });
	writeIndex(dir);
}

/** Regenerate index.html: every page, newest first, titled from its <title>. */
function writeIndex(dir: string): void {
	const pages = listPages(dir);
	const items = pages
		.map((name) => {
			const head = readFileSync(join(dir, name), "utf8").slice(0, 4000);
			const title = /<title>([^<]*)<\/title>/.exec(head)?.[1] ?? escapeHtml(name);
			return `<li><a href="${encodeURIComponent(name)}">${title}</a><br><small>${escapeHtml(name.slice(0, 15))}</small></li>`;
		})
		.join("\n");
	const css = `${BASE_CSS} ul { list-style: none; padding: 0; } li { padding: 10px 0; border-bottom: 1px solid var(--line); } small { color: var(--muted); }`;
	writeFileSync(
		join(dir, INDEX_FILE),
		`<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>pi visuals</title>
<style>${css}</style>
</head>
<body>
<header class="pv"><h1>pi visuals</h1><span>${pages.length}</span></header>
<ul>
${items || "<li>Nothing yet.</li>"}
</ul>
</body>
</html>
`,
	);
}

/**
 * Map a request path to a file inside `dir`, or undefined when it escapes the
 * directory or is not an .html page. "/" serves the index.
 */
export function resolveRequest(dir: string, urlPath: string): string | undefined {
	let path: string;
	try {
		path = decodeURIComponent(urlPath.split("?")[0] ?? "/");
	} catch {
		return undefined;
	}
	if (path === "/" || path === "") path = `/${INDEX_FILE}`;
	if (!path.endsWith(".html")) return undefined;
	const root = resolve(dir);
	const file = resolve(root, `.${path}`);
	if (!file.startsWith(root + sep)) return undefined;
	return existsSync(file) ? file : undefined;
}
