/**
 * Pi's collapsed codemode view still shows script, nested-call, and output
 * previews, making the transcript noisy; their preview limits are not configurable.
 * This renderer hides scripts and successful output behind a compact summary,
 * keeping errors visible. Ctrl+O (or a fullscreen result click) expands the
 * original renderer. Execution, permissions, and model-visible output are unchanged.
 */
import { stripVTControlCharacters } from "node:util";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { truncateToWidth } from "@earendil-works/pi-tui";

type NestedCall = { name: string; status: string; error?: string; cost?: number };

function clean(text: string): string {
	return stripVTControlCharacters(text).replace(/\s+/g, " ").trim();
}

// Truncate rather than wrap, including long errors and narrow terminals.
function compactLines(lines: () => string[]) {
	return {
		render: (width: number) => lines().map((line) => truncateToWidth(line, width)),
		invalidate() {},
	};
}

export default function (pi: ExtensionAPI) {
	pi.registerToolRenderer((name, next) => {
		const original = next();
		if (name !== "codemode" || !original?.renderCall || !original.renderResult) return original;
		const { renderCall, renderResult } = original;
		return {
			...original,
			renderCall(args, theme, context) {
				// The stock renderer expects its own Container, not our compact component.
				if (context.expanded) return renderCall(args, theme, { ...context, lastComponent: undefined });
				return compactLines(() => [theme.fg("toolTitle", theme.bold("codemode"))]);
			},
			renderResult(result, options, theme, context) {
				if (options.expanded) return renderResult(result, options, theme, { ...context, lastComponent: undefined });
				const calls: NestedCall[] = result.details?.calls ?? [];
				const failed = calls.filter((call) => call.status === "error");
				const cancelled = calls.filter((call) => call.status === "cancelled");
				const status = context.isError ? "failed" : options.isPartial ? "running" : "completed";
				const parts = [`${calls.length} ${calls.length === 1 ? "call" : "calls"}`, status];
				if (failed.length) parts.push(`${failed.length} failed`);
				if (cancelled.length) parts.push(`${cancelled.length} cancelled`);
				if (!options.isPartial && context.durationMs !== undefined) {
					parts.push(`${(context.durationMs / 1000).toFixed(1)}s`);
				}
				const cost = calls.reduce((total, call) => total + (call.cost ?? 0), 0);
				if (cost > 0) parts.push(`$${cost >= 0.01 ? cost.toFixed(2) : cost.toPrecision(2)}`);

				let error = failed[0] ? `${failed[0].name}: ${failed[0].error ?? "tool failed"}` : "";
				if (context.isError) {
					const output = result.content.filter((item) => item.type === "text").map((item) => item.text).join("\n");
					const scriptError = /Script error:\s*([^\n]+)/.exec(output)?.[1];
					const diagnostic = output.replace(/^Script (completed|failed)\nWall time [^\n]*\nOutput:\n/, "").trim();
					error = scriptError ?? (diagnostic.split("\n")[0] || error || "Script failed");
				}
				return compactLines(() => [
					theme.fg(context.isError || failed.length ? "error" : options.isPartial ? "warning" : "muted", parts.join(" · ")),
					...(error ? [theme.fg("error", clean(error))] : []),
				]);
			},
		};
	});
}
