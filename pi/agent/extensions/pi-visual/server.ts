/**
 * Static server for the visuals directory. Serves .html pages only, never
 * anything outside the directory. No pi imports.
 *
 * Binds to localhost only. Reach it from the phone with
 * `tailscale serve --bg <port>` rather than binding to 0.0.0.0, so the pages
 * are on the tailnet over HTTPS and never on the LAN.
 */

import { readFile } from "node:fs/promises";
import { createServer, type Server } from "node:http";
import { resolve } from "node:path";
import { resolveRequest } from "./core.ts";

const HOST = "127.0.0.1";
/**
 * Sent on every response with the served directory, so a second pi session can
 * tell a pi-visual server for its own directory from anything else on the port.
 */
const MARKER = "x-pi-visual";

/**
 * Start serving `dir`, or resolve "shared" when another pi-visual server
 * already serves the same directory on the port. Several pi sessions share one visuals directory, so the
 * first one to start serves for all of them. Rejects when some other program,
 * or a pi-visual server for a different directory, holds the port.
 */
export function serve(dir: string, port: number): Promise<Server | "shared"> {
	// Encoded so a non-ASCII path is still a valid header value.
	const tag = encodeURIComponent(resolve(dir));
	const server = createServer(async (req, res) => {
		res.setHeader(MARKER, tag);
		const file = req.method === "GET" || req.method === "HEAD" ? resolveRequest(dir, req.url ?? "/") : undefined;
		if (!file) {
			res.writeHead(404, { "content-type": "text/plain" }).end("not found\n");
			return;
		}
		try {
			const body = await readFile(file);
			res.writeHead(200, {
				"content-type": "text/html; charset=utf-8",
				"cache-control": "no-store",
				"x-content-type-options": "nosniff",
				"referrer-policy": "no-referrer",
			});
			res.end(req.method === "HEAD" ? undefined : body);
		} catch {
			res.writeHead(500, { "content-type": "text/plain" }).end("read failed\n");
		}
	});
	return new Promise((resolvePromise, reject) => {
		server.once("error", (err: NodeJS.ErrnoException) => {
			if (err.code !== "EADDRINUSE") return reject(err);
			fetch(`http://${HOST}:${port}/`, { method: "HEAD" })
				.then((res) => res.headers.get(MARKER), () => null)
				.then((other) => {
					if (other === tag) resolvePromise("shared");
					else if (other) {
						reject(new Error(`port ${port} serves another visuals directory (${decodeURIComponent(other)}); set PI_VISUAL_PORT or PI_VISUAL_DIR`));
					} else reject(new Error(`port ${port} is used by another program; set PI_VISUAL_PORT`));
				});
		});
		server.listen(port, HOST, () => {
			// Never keep pi alive just to serve pages.
			server.unref();
			resolvePromise(server);
		});
	});
}
