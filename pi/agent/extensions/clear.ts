/**
 * /clear - start a fresh context like /new, but keep the current model
 * and thinking level instead of resetting them to the settings defaults.
 *
 * The captured `pi` and `ctx` become stale once ctx.newSession() replaces the
 * runtime, and the replacement context has no setModel. So the restore is
 * handed off via module state (the extension module is cached across session
 * replacements) to the session_start handler registered by the fresh
 * extension instance of the new session, whose `pi` targets that session.
 */

import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

type ActiveModel = NonNullable<ExtensionContext["model"]>;
type ThinkingLevel = ReturnType<ExtensionAPI["getThinkingLevel"]>;

let pendingRestore: { model: ActiveModel; thinkingLevel: ThinkingLevel } | undefined;

export default function (pi: ExtensionAPI) {
	pi.on("session_start", async (event, ctx) => {
		if (event.reason !== "new" || !pendingRestore) return;
		const { model, thinkingLevel } = pendingRestore;
		pendingRestore = undefined;
		const ok = await pi.setModel(model);
		if (!ok) {
			ctx.ui.notify(`Could not restore model ${model.provider}/${model.id} (no auth)`, "error");
			return;
		}
		pi.setThinkingLevel(thinkingLevel);
	});

	pi.registerCommand("clear", {
		description: "Start a fresh context, keeping the current model and thinking level",
		handler: async (_args, ctx) => {
			if (ctx.model) {
				pendingRestore = { model: ctx.model, thinkingLevel: pi.getThinkingLevel() };
			}

			try {
				const result = await ctx.newSession({
					withSession: async (replacementCtx) => {
						replacementCtx.ui.notify("Context cleared", "info");
					},
				});

				if (result.cancelled) {
					ctx.ui.notify("Clear cancelled", "info");
				}
			} finally {
				// On success the session_start handler has already consumed the
				// stash; this covers cancel and throw so a later plain /new
				// can't pick up a stale restore.
				pendingRestore = undefined;
			}
		},
	});
}
