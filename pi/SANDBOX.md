# pi sandbox

The agent's `bash` tool can run inside an OS sandbox built on Anthropic's
[sandbox-runtime](https://github.com/anthropic-experimental/sandbox-runtime)
(srt). On Linux, srt uses bubblewrap for the filesystem, seccomp to block
Unix sockets, and a proxy that only lets allowlisted domains through. The
extension lives in `agent/extensions/srt-sandbox/`.

Status: built and tested headless, still in trial. `enabled` is `false` in
`config.json`, so the sandbox is off unless you start pi with `--sandbox`.

## What is sandboxed

| Runs in the sandbox | Runs on the host |
|---|---|
| The agent's `bash` tool | pi itself, including the LLM connection and `auth.json` |
| | The in-process tools: `read`, `write`, `edit`, `grep`, `find`, `ls` |
| | Other extensions (pi-web-access, pi-lsp language servers, ...) |
| | Your own `!` / `!!` commands |
| | `unsandboxedCommands` (see below) |

pi-permission-system still gates everything, sandboxed or not. The extension
keeps the tool name `bash`, so every command passes the permission check
first and then runs in the sandbox.

## How the two layers split the work

- **The sandbox decides what is possible.** The kernel enforces it for every
  process the command starts, including `python -c`, npm install scripts and
  build tools, however the command is written.
- **pi-permission-system decides what is wise** inside that boundary:
  commits, pushes, history rewrites, `rm -r`, `gh` writes. It also covers the
  in-process tools, which the sandbox never sees.

## Policy (`agent/extensions/srt-sandbox/config.json`)

| Setting | Value |
|---|---|
| Read | `denyRead: ["~"]`, so all of `$HOME` is hidden except the `allowRead` entries: the project, `~/code`, `~/mynotes`, `~/myprojects`, `~/Work`, git and mise config, `~/.local/bin`, `~/.local/share/mise`, and the package caches |
| Write | the project, `/tmp`, `~/.cache`, `~/.npm`, `~/.cargo/registry`, `~/.cargo/git` |
| Never writable | `.env*`, `*.pem`, `*.key`, `*.p12`, `*.pfx`; added by the extension: pi's extensions directory, `settings.json` (both resolved through symlinks) and the project's `.pi/` if it exists; added by srt: `.git/hooks`, `.git/config`, shell rc files, `.vscode`, `.idea`, `.mcp.json` |
| Network | GitHub, and the npm, PyPI, crates.io and Go module registries; every other domain is blocked |
| `unsandboxedCommands` | `git push`, `git fetch`, `git pull`, `gh` |

Commands in `unsandboxedCommands` need credentials the sandbox hides (the
ssh-agent socket, the `gh` token). They run on the host only when written as a
single plain command: one with `;`, `&`, `|`, `$`, a backtick, a redirect,
brackets or a newline stays sandboxed. This stops `git push && something-else`
from carrying another command out of the sandbox. The permission system still
asks before `git push` and before any `gh` command that isn't read-only.

The policy is global only. There is no per-project sandbox file, because the
agent can write in the project and must not be able to loosen its own
sandbox. The config is read once per session; start a new session after
editing it.

## Usage

```bash
pi --sandbox      # sandbox on for this run, whatever config.json says
pi --no-sandbox   # sandbox off for this run, whatever config.json says
pi                # config.json "enabled" decides
```

Both flags come from the extension, not from pi itself.

Inside a session, `/sandbox` shows the state and the resolved policy. When the
sandbox is on, the footer shows `sandbox: N domains`.

If the sandbox fails to start, bash is blocked rather than run unsandboxed.
Restart with `--no-sandbox` to work without it.

## Setup on a new machine

```bash
cd ~/myprojects/dotfiles/pi/agent/extensions/srt-sandbox
npm install            # @anthropic-ai/sandbox-runtime, pinned
```

Linux also needs `bwrap` (bubblewrap), `socat` and `rg` (ripgrep) on `PATH`.
`bin/pi_setup.sh` does not run the `npm install`. While `enabled` is `false`
the extension never loads srt, so a machine without it still works.

## What a blocked command looks like

There is no prompt when the sandbox blocks something. On Linux, srt has no
violation monitor, so the command just fails:

| Output | Cause |
|---|---|
| `Read-only file system` | write outside the allowed paths, or to a protected file |
| `Permission denied` on `.env*` or a key file | `denyWrite` |
| `No such file or directory` for a file under `~` | hidden by `denyRead` |
| `CONNECT tunnel failed, response 403` | domain not in `allowedDomains` |

The extension adds a line to the system prompt telling the model to report
these blocks instead of working around them. To allow something, edit
`config.json` and start a new session.

## Known limitations

- **Unix sockets are blocked**, so `hunk session`, `tmux`, `docker` and
  `systemctl --user` fail inside the sandbox.
- **Tools that read config elsewhere in `$HOME`** (for example `~/.config/ruff`
  or pyright settings) can't see it until it's added to `allowRead`.
- **Placeholder files:** srt protects names like `.bashrc` or `.vscode` that
  don't exist yet by mounting an empty read-only placeholder for as long as a
  command runs. The extension hides these from sandboxed git through a
  temporary `core.excludesFile`, which holds your global excludes plus those
  names. Host tools may briefly see the placeholders while a command runs.
- **`.` means the session's working directory** when the session starts. If
  pi switches projects mid-process, start a new session.
- **SSH remotes:** `git fetch` and `git pull` over SSH work only as plain
  commands, through `unsandboxedCommands`. Inside a pipeline they fail,
  because the sandbox hides `~/.ssh` and the agent socket.

## Why not pi-sandbox

[carderne/pi-sandbox](https://github.com/carderne/pi-sandbox) was reviewed on
2026-10-02 and rejected:

- It depends on a fork of srt that removes the write protection on
  `.git/hooks` and `.git/config`. A sandboxed command could then plant a hook
  that runs unsandboxed on your next `git commit`.
- The fork is 174 commits behind upstream and misses its September proxy and
  Linux deny-path fixes.
- It reads a `.pi/sandbox.json` the agent can write.
- It doesn't check paths for `grep`, `find` or `ls`.
- It has no way to run `git push` or `gh` outside the sandbox.

The full review is in the log of `agent/AUTONOMY-PLAN.md` (step 4).

## Testing

Still to check live in `~/Work/test1` with `pi --sandbox`:

- `git push` and a `gh` command, which should run outside the sandbox
- an npm or uv install
- a pi-subagents run
- the Unix-socket tools above, which are expected to fail

After the trial, the plan is to set `bash."*"` to `allow` in the
pi-permission-system config and cut it down to a short ask/deny list.
