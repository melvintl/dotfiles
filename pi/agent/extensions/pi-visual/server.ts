/**
 * Static server for the visuals directory. Serves .html pages only, never
 * anything outside the directory. No pi imports.
 *
 * Binds to localhost by default. Reach it from the phone with
 * `tailscale serve --bg <port>` rather than binding to 0.0.0.0, so the pages
 * are on the tailnet over HTTPS and never on the LAN.
 */

import { readFile } from "node:fs/promises";
import { createServer, type Server } from "node:http";
import { resolveRequest } from "./core.ts";

/**
 * Start serving `dir`, or resolve "shared" when the port is already taken.
 * Several pi sessions share one visuals directory, so the first one to start
 * serves for all of them.
 */
export function serve(dir: string, host: string, port: number): Promise<Server | "shared"> {
	const server = createServer(async (req, res) => {
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
			if (err.code === "EADDRINUSE") resolvePromise("shared");
			else reject(err);
		});
		server.listen(port, host, () => {
			// Never keep pi alive just to serve pages.
			server.unref();
			resolvePromise(server);
		});
	});
}
