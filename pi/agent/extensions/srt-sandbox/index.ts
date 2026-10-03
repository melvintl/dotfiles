/**
 * srt-sandbox - run the agent's bash tool inside @anthropic-ai/sandbox-runtime
 * (bubblewrap + seccomp + a domain-allowlisting proxy on Linux).
 *
 * Only the agent's `bash` tool is sandboxed. pi itself, its in-process tools
 * (read, write, edit, grep, find, ls), other extensions, and the user's own `!`
 * commands run on the host; pi-permission-system gates those. The tool keeps
 * the name `bash`, so pi-permission-system still gates every command before it
 * reaches the sandbox.
 *
 * Policy comes only from config.json next to this file. There is no project
 * config: a file the agent can write must not be able to loosen the sandbox.
 * The config is read once per session; edit it and start a new session.
 *
 * On top of the config, writes are always denied to pi's own config (the
 * extensions directory and settings.json, resolved through symlinks) and to an
 * existing `.pi/` in the working directory.
 *
 * `unsandboxedCommands` lists command prefixes (`git push`, `gh`) that need
 * credentials the sandbox hides (ssh-agent socket, gh token). Such a command
 * runs on the host only when it is a single simple command: anything with
 * shell operators, substitutions or redirects stays sandboxed.
 *
 * Enabled by `"enabled": true` in config.json or `pi --sandbox`; `--no-sandbox`
 * wins over both. If the sandbox fails to start, bash is blocked rather than
 * run unsandboxed.
 *
 * Setup: `npm install` in this directory. Linux also needs bwrap, socat, rg.
 */

import { spawnSync } from "node:child_process";
import { existsSync, readFileSync, realpathSync, rmSync, writeFileSync } from "node:fs";
import { homedir, tmpdir } from "node:os";
import { join } from "node:path";
import type { SandboxRuntimeConfig } from "@anthropic-ai/sandbox-runtime";
import type { BashOperations, ExtensionAPI } from "@earendil-works/pi-coding-agent";
import {
	createBashToolDefinition,
	createLocalBashOperations,
	getAgentDir,
	SettingsManager,
} from "@earendil-works/pi-coding-agent";

type SandboxConfig = Partial<Pick<SandboxRuntimeConfig, "network" | "filesystem">> & {
	enabled?: boolean;
	unsandboxedCommands?: string[];
};
type Manager = typeof import("@anthropic-ai/sandbox-runtime").SandboxManager;

const CONFIG_PATH = join(getAgentDir(), "extensions", "srt-sandbox", "config.json");
const SHELL_SYNTAX = /[;&|`$<>(){}\n\\]/;
const GUIDELINE =
	"bash runs in an OS sandbox. Run commands normally. If one fails with 'Read-only file system', " +
	"'Permission denied' on a project file, a missing file under $HOME, or 'CONNECT tunnel failed, " +
	"response 403', the sandbox blocked it: report what was blocked instead of working around it.";

// On Linux, srt protects these names by mounting a read-only placeholder where
// they do not exist yet, so inside the sandbox they show up as untracked files.
const PLACEHOLDER_NAMES = [
	".gitconfig", ".gitmodules", ".bashrc", ".bash_profile", ".zshrc", ".zprofile", ".profile",
	".ripgreprc", ".mcp.json", ".vscode", ".idea", ".claude/commands", ".claude/agents",
];

function loadConfig(): SandboxConfig {
	return JSON.parse(readFileSync(CONFIG_PATH, "utf-8")) as SandboxConfig;
}

function realpathOrNull(path: string): string | null {
	try {
		return realpathSync(path);
	} catch {
		return null;
	}
}

// "." in the config means the session's working directory, not wherever the
// runtime happens to resolve it.
function runtimeConfig(config: SandboxConfig, cwd: string): SandboxRuntimeConfig {
	const atCwd = (paths: string[] = []) => paths.map((p) => (p === "." ? cwd : p));
	const agentDir = getAgentDir();
	const protectedPaths = [
		realpathOrNull(join(agentDir, "extensions")),
		realpathOrNull(join(agentDir, "settings.json")),
		existsSync(join(cwd, ".pi")) ? join(cwd, ".pi") : null,
	].filter((p): p is string => p !== null);

	return {
		network: {
			allowedDomains: config.network?.allowedDomains ?? [],
			deniedDomains: config.network?.deniedDomains ?? [],
		},
		filesystem: {
			denyRead: config.filesystem?.denyRead ?? [],
			allowRead: atCwd(config.filesystem?.allowRead),
			allowWrite: atCwd(config.filesystem?.allowWrite),
			denyWrite: [...(config.filesystem?.denyWrite ?? []), ...protectedPaths],
		},
	};
}

export function isUnsandboxed(command: string, prefixes: string[]): boolean {
	const trimmed = command.trim();
	if (SHELL_SYNTAX.test(trimmed)) return false;
	return prefixes.some((prefix) => trimmed === prefix || trimmed.startsWith(`${prefix} `));
}

// The user's global excludes file is usually under the hidden $HOME, so the
// sandbox gets a copy of it plus the placeholder names, passed to git via env.
function writeGitExcludes(): string {
	const configured = spawnSync("git", ["config", "--global", "--path", "--get", "core.excludesFile"], {
		encoding: "utf-8",
	}).stdout?.trim();
	let userExcludes = "";
	try {
		userExcludes = readFileSync(configured || join(homedir(), ".config", "git", "ignore"), "utf-8");
	} catch {
		// No global excludes file.
	}
	const path = join(tmpdir(), `pi-srt-sandbox-${process.pid}.gitignore`);
	writeFileSync(path, `${userExcludes}\n# srt-sandbox placeholders\n${PLACEHOLDER_NAMES.join("\n")}\n`);
	return path;
}

function withGitExcludes(env: NodeJS.ProcessEnv, excludesFile: string): NodeJS.ProcessEnv {
	const index = Number(env.GIT_CONFIG_COUNT ?? 0) || 0;
	return {
		...env,
		GIT_CONFIG_COUNT: String(index + 1),
		[`GIT_CONFIG_KEY_${index}`]: "core.excludesFile",
		[`GIT_CONFIG_VALUE_${index}`]: excludesFile,
	};
}

function sandboxedOps(manager: Manager, local: BashOperations, excludesFile: string): BashOperations {
	return {
		async exec(command, cwd, options) {
			// A wrap that throws has already released its mount points, so cleanup
			// runs only for a command that was actually wrapped.
			const wrapped = await manager.wrapWithSandbox(command, undefined, undefined, options.signal);
			try {
				const env = withGitExcludes(options.env ?? process.env, excludesFile);
				return await local.exec(wrapped, cwd, { ...options, env });
			} finally {
				manager.cleanupAfterCommand();
			}
		},
	};
}

// SandboxManager is a module singleton shared by every session in this process
// (subagents included), so it is started once and reset when the last one ends.
let manager: Manager | undefined;
let excludesFile = "";
let starting: Promise<Manager> | undefined;
let sessions = 0;

async function startManager(config: SandboxConfig, cwd: string): Promise<Manager> {
	if (manager) return manager;
	starting ??= (async () => {
		const { SandboxManager } = await import("@anthropic-ai/sandbox-runtime");
		if (!SandboxManager.isSupportedPlatform()) throw new Error(`unsupported platform ${process.platform}`);
		await SandboxManager.initialize(runtimeConfig(config, cwd));
		excludesFile = writeGitExcludes();
		manager = SandboxManager;
		return SandboxManager;
	})();
	try {
		return await starting;
	} finally {
		starting = undefined;
	}
}

export default function (pi: ExtensionAPI) {
	pi.registerFlag("sandbox", {
		description: "Run the bash tool in the srt sandbox regardless of config",
		type: "boolean",
		default: false,
	});
	pi.registerFlag("no-sandbox", {
		description: "Run the bash tool without the srt sandbox",
		type: "boolean",
		default: false,
	});

	const settings = SettingsManager.create(process.cwd());
	const shellPath = settings.getShellPath();
	const commandPrefix = settings.getShellCommandPrefix();
	const local = createLocalBashOperations({ shellPath });
	const base = createBashToolDefinition(process.cwd(), { commandPrefix, shellPath });

	let state: "off" | "on" | "failed" = "off";
	let failure = "";
	let config: SandboxConfig = {};

	pi.registerTool({
		...base,
		label: "bash (sandboxed)",
		promptGuidelines: [...(base.promptGuidelines ?? []), GUIDELINE],
		async execute(id, params, signal, onUpdate, ctx) {
			if (state === "failed") {
				throw new Error(`srt sandbox failed to start (${failure}); bash is blocked. Restart pi with --no-sandbox to run unsandboxed.`);
			}
			const sandboxed = state === "on" && manager && !isUnsandboxed(params.command, config.unsandboxedCommands ?? []);
			const tool = createBashToolDefinition(ctx.cwd, {
				commandPrefix,
				shellPath,
				operations: sandboxed ? sandboxedOps(manager!, local, excludesFile) : local,
			});
			return tool.execute(id, params, signal, onUpdate, ctx);
		},
	});

	pi.on("session_start", async (_event, ctx) => {
		if (pi.getFlag("no-sandbox")) return;
		try {
			config = loadConfig();
		} catch (error) {
			state = "failed";
			failure = `cannot read ${CONFIG_PATH}: ${error instanceof Error ? error.message : error}`;
			ctx.ui.notify(`srt sandbox: ${failure}`, "error");
			return;
		}
		if (!config.enabled && !pi.getFlag("sandbox")) return;

		try {
			await startManager(config, ctx.cwd);
			sessions++;
			state = "on";
			const domains = config.network?.allowedDomains?.length ?? 0;
			ctx.ui.setStatus("sandbox", ctx.ui.theme.fg("accent", `sandbox: ${domains} domains`));
		} catch (error) {
			state = "failed";
			failure = error instanceof Error ? error.message : String(error);
			ctx.ui.notify(`srt sandbox failed to start, bash is blocked: ${failure}`, "error");
		}
	});

	pi.on("session_shutdown", async () => {
		if (state !== "on") return;
		state = "off";
		sessions--;
		if (sessions > 0 || !manager) return;
		const current = manager;
		manager = undefined;
		rmSync(excludesFile, { force: true });
		try {
			await current.reset();
		} catch {
			// Nothing left to clean up if the reset itself fails.
		}
	});

	pi.registerCommand("sandbox", {
		description: "Show the srt sandbox state and policy",
		handler: async (_args, ctx) => {
			if (state !== "on") {
				ctx.ui.notify(state === "failed" ? `Sandbox failed: ${failure}` : "Sandbox is off", "info");
				return;
			}
			const rc = runtimeConfig(config, ctx.cwd);
			const list = (values: string[] | undefined) => values?.join(", ") || "(none)";
			ctx.ui.notify(
				[
					`Sandbox on (${CONFIG_PATH})`,
					`Domains: ${list(rc.network.allowedDomains)}`,
					`Deny read: ${list(rc.filesystem.denyRead)}`,
					`Allow read: ${list(rc.filesystem.allowRead)}`,
					`Allow write: ${list(rc.filesystem.allowWrite)}`,
					`Deny write: ${list(rc.filesystem.denyWrite)}`,
					`Unsandboxed: ${list(config.unsandboxedCommands)}`,
				].join("\n"),
				"info",
			);
		},
	});
}
