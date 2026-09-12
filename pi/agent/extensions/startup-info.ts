/**
 * Collapsed startup info for Pi.
 *
 * Pi's default startup screen can take a lot of vertical space when many skills,
 * prompt templates, extensions, and themes are installed. This extension keeps
 * startup compact by replacing the normal startup header with a one-line summary
 * and relying on the user's `quietStartup` setting to suppress the expanded
 * resource listing.
 *
 * It also provides `/startup-info`, which renders the loaded Skills, Prompts,
 * Extensions, and Themes on demand as a TUI-only custom entry. That gives quick
 * access to the same kind of information without forcing it to occupy screen
 * space every time Pi starts.
 *
 * On initial startup only, the extension clears the terminal before Pi renders so
 * the shell prompt used to launch `pi` is not left above the TUI. It deliberately
 * does not clear the screen on `/reload`, `/new`, `/resume`, or `/fork`.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { VERSION } from "@earendil-works/pi-coding-agent";
import { Box, Text, truncateToWidth } from "@earendil-works/pi-tui";

interface StartupInfoData {
	lines: string[];
	timestamp: number;
}

function uniq(values: string[]): string[] {
	return [...new Set(values.filter(Boolean))].sort((a, b) => a.localeCompare(b));
}

function formatSection(title: string, values: string[]): string[] {
	return values.length > 0 ? [`[${title}]`, `  ${values.join(", ")}`] : [`[${title}]`, "  none"];
}

function sourceLabel(command: any): string {
	const info = command?.sourceInfo;
	return info?.source || info?.path?.split("/").filter(Boolean).at(-1) || command?.name || "unknown";
}

export default function (pi: ExtensionAPI) {
	pi.registerEntryRenderer<StartupInfoData>("startup-info", (entry, _state, theme) => {
		const data = entry.data ?? { lines: [], timestamp: Date.now() };
		const box = new Box(1, 1, (text) => theme.bg("customMessageBg", text));
		for (const line of data.lines) {
			if (line.startsWith("[") && line.endsWith("]")) {
				box.addChild(new Text(theme.fg("accent", line), 0, 0));
			} else {
				box.addChild(new Text(theme.fg("muted", line), 0, 0));
			}
		}
		return box;
	});

	pi.on("session_start", async (event, ctx) => {
		if (ctx.mode !== "tui") return;

		// Clear the terminal on initial Pi startup so the shell prompt used to launch
		// Pi is not left above the TUI. Keep /reload, /new, /resume, and /fork from
		// clearing the current transcript unexpectedly.
		if (event.reason === "startup") {
			process.stdout.write("\x1b[H\x1b[2J\x1b[3J");
		}

		ctx.ui.setHeader((_tui: unknown, theme: any) => ({
			render(width: number): string[] {
				const line = `${theme.fg("accent", "pi")} ${theme.fg("dim", `v${VERSION}`)} ${theme.fg("dim", "· resources collapsed · type ")}${theme.fg("accent", "/startup-info")}${theme.fg("dim", " to show resources")}`;
				return [truncateToWidth(line, width)];
			},
			invalidate() {},
		}));
	});

	pi.registerCommand("startup-info", {
		description: "Show loaded startup resources: skills, prompts, extensions, and themes",
		handler: async (_args, ctx) => {
			const commands = pi.getCommands();
			const skills = uniq(commands.filter((c: any) => c.source === "skill").map((c: any) => c.name.replace(/^skill:/, "")));
			const prompts = uniq(commands.filter((c: any) => c.source === "prompt").map((c: any) => `/${c.name}`));
			const extensions = uniq(commands.filter((c: any) => c.source === "extension").map(sourceLabel));
			const themes = ctx.mode === "tui" ? uniq((ctx.ui.getAllThemes?.() ?? []).map((t: any) => t.name)) : [];

			pi.appendEntry<StartupInfoData>("startup-info", {
				timestamp: Date.now(),
				lines: [
					...formatSection("Skills", skills),
					"",
					...formatSection("Prompts", prompts),
					"",
					...formatSection("Extensions", extensions),
					"",
					...formatSection("Themes", themes),
				],
			});
		},
	});
}
