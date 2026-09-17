# pi autonomy plan

Working checklist distilled from the pi Autonomy Playbook (Claude Code artifact,
research summary for pi v0.85.1, 2026-09-13).

Source artifact (full 23-item playbook, sources, code snippets):
https://claude.ai/code/artifact/019e93b8-3c00-4458-a816-2fc6ffca4779

Decision (2026-09-13): skip the Neovim / tmux quality-of-life items (playbook
items 13 to 22). Only the autonomy items below are in scope.

Config lives in `~/myprojects/dotfiles/pi/agent/` and is symlinked into
`~/.pi/agent/`. Permission system: gotgenes pi-permission-system, fallback
`"*": "ask"`, no yolo.

## Order

- [x] 1. pi-goal and pi-lsp (DONE 2026-09-13; pi-lens rejected after review, see log)
  - `pi install npm:pi-lens` (or `@narumitw/pi-lsp` for LSP only). Hooks
    `tool_result` on write/edit/bash, feeds formatter, lint and LSP diagnostics
    back to the model. Its subprocesses bypass the bash permission gate; review
    once and decide.
  - `pi install npm:@narumitw/pi-goal`. `/goal <objective>` re-prompts from
    `agent_settled` until the model calls `goal_complete` with evidence.
    Defaults: 25 automatic turns, 3 no-progress turns.
  - Add `lens_diagnostics` and `goal_complete` as `allow` in the permission
    config. Keep fallback `ask`.
  - Keep the ending-a-turn section of `APPEND_SYSTEM.md`; the loop no longer
    depends on it.

- [~] 2. Prompt templates directory and global AGENTS.md (handoff.md DONE
  2026-09-13; rest deferred until after step 3, see log)
  - Create `~/myprojects/dotfiles/pi/agent/prompts/`, symlink to
    `~/.pi/agent/prompts`. Templates use `$1` and `$@` substitution.
  - Start with: `issue.md` (fetch with `gh issue view`, do not trust the
    issue's analysis, verify against code, plan, implement, test, run reviewer
    subagent), `review.md` (reviewer subagent on current diff, act on
    findings), `wrapup.md` (changelog, staged paths only, commit message
    proposal), `handoff.md` (fresh-session prompt: files touched, decisions,
    open items).
  - Global `~/.pi/agent/AGENTS.md` for conventions about you, not a repo:
    preferred test runners, commit style, never `git add -A`, no commit
    attribution trailers.

- [ ] 3. Subagent model tiering
  - pi-subagents `docs/models.md` documents per-role models. `scout` and
    `researcher` on a cheap or local tier (local Qwen 14B via Ollama already in
    `models.json`), `reviewer` on gpt-5.5 with high thinking.
  - Add `enabledModels` to `settings.json` so ctrl+p cycles only the two or
    three models actually used.

- [ ] 4. pi-sandbox, then loosen the bash allowlist
  - https://github.com/carderne/pi-sandbox wraps bash, read, write, edit in
    bubblewrap with path and domain allowlists, never auto-grants.
  - Once on, allow package installs and `curl` inside the project directory;
    the blast radius is the sandbox, not `$HOME`.

- [ ] 5. tmux-backed bash and pi-side-agents (only when running parallel or
  long jobs)
  - `@richardgill/pi-tmux-bash` (replaces bash tool, commands run in a pane)
    or `@romansix/pi-tmux` (lighter: `run` and `peek`). Verify the replacement
    still passes the permission system's bash gate; a tool registered under a
    different name will not.
  - https://github.com/pasky/pi-side-agents: `/agent <task>` spawns a child pi
    in a new tmux window and git worktree with init, branch and merge scripts.
  - Alternative: pi-subagents' worktree option via the gotgenes worktrees
    provider.

## Small items, no dependencies

- [x] `APPEND_SYSTEM.md`: run one simple command per bash call (done
  2026-09-13, plus `for *`/`while *`/`if *` allows so the scaffolding of a
  loop no longer asks; inner commands stay gated).
- [ ] Headless runs: `pi -p` denies every `ask` and skips project config while
  `defaultProjectTrust` is `"ask"`. For cron or scripts pass `--approve`, narrow
  with `--tools read,grep,find,ls` for analysis, or run in pi-sandbox for
  writes. Bash tool exports `PI_SESSION_ID` and `PI_SESSION_FILE`; resume with
  `--session-id`.
- [ ] Omarchy theme switcher writes `~/.pi/agent/themes/omarchy-system.json`,
  which is a symlink into the dotfiles repo, so every theme change dirties the
  repo. Gitignore that file or point `themes` at a local directory.
- [ ] Optional: `@gotgenes/pi-permission-model-judge`, a deny-first LLM judge
  that resolves `ask` automatically. Convenience for headless runs, not a
  security control.

## Skip

- oh-my-pi and other forks.
- Swarm and agent-team engines (pi-agent-teams, trimegisto, pi-fabric).
- MCP unless a specific server is unavoidable (then pi-mcp-adapter lazy proxy).
- Todo tools; a TODO.md in the repo is enough.
- Ralph loops (pi-ralph): use rarely, for multi-hour jobs only. Both pi
  authors are sceptical of unattended loops on code they care about.

## Log

- 2026-09-13: plan written.
- 2026-09-13: reviewed pi-lens, @narumitw/pi-goal, @narumitw/pi-lsp before installing.
  - pi-goal 0.54.4: same monorepo and author as the already-trusted pi-plan-mode
    (narumiruna/pi-extensions, 551 stars, 7 open issues, weekly releases, 26
    pi-goal issues all closed). Tarball 868K, no install scripts, no network
    or child_process use. Registers goal_complete, goal_blocked, goal_wait and
    /goal. Defaults: 25 automatic turns, 3 no-progress turns. Coexists with
    plan-mode >= 0.52 (we have ^0.58). INSTALLED. Added the three tools as
    allow in pi-permission-system config.json. Verified offline via scratch
    extension: all three resolve to allow; model lists them as tools.
  - pi-lens 4.1.6: most-downloaded option (89k/month, 406 stars) but heavy:
    30 MB / 1541 files, native deps (@ast-grep/napi), prepare script downloads
    tree-sitter grammars, 257 open issues and ~3000 issue numbers in 6 months
    (top committer is an AI account). By default it auto-installs ~40 external
    tools via npm/pip/go/gem and GitHub-release binaries into ~/.pi-lens/bin,
    runs autoformat + autofix on every write (file writes outside the
    permission gate), enables the opengrep scanner, and a read-guard that
    blocks edits of files the model has not read. Opt-outs exist
    (PI_LENS_DISABLE_LSP_INSTALL=1, PI_LENS_DISABLE_TOOL_INSTALL=1,
    --no-autofix, --no-autoformat, --no-read-guard, --no-opengrep). NOT
    installed pending decision.
  - @narumitw/pi-lsp 0.49.7: same author as pi-goal. 300K, no deps, never
    downloads anything, starts a language server only for an explicit
    lsp_diagnostics / lsp_fix call, lsp_fix writes only with write:true.
    Lighter and safer; loses the automatic feed-back-on-every-edit behaviour.
  - Decision: pi-lsp instead of pi-lens. INSTALLED pi-lsp 0.49.7. Allowed
    lsp_diagnostics and lsp_fix in the permission config. Wrote
    `pi/agent/pi-lsp.json` (symlinked to ~/.pi/agent/pi-lsp.json) using the
    servers already on PATH: ruff, pyright-langserver, typescript-language-server,
    vscode-json-language-server, rust-analyzer, lua-language-server, clangd.
    Custom config replaces the built-in catalog entirely, so add servers there.
    Added a bullet to APPEND_SYSTEM.md "Fixing and validating": call
    lsp_diagnostics on touched files after editing. Verified headlessly:
    ruff, pyright, tsserver and json server each reported the planted error.

- 2026-09-13: test project for step 1 at ~/Work/test1 (inventory package, 4
  planted problems, README only, no AGENTS.md). Scenario script kept OUT of the
  repo and outside ~/Work at ~/notes/pi-test1-TESTING.md so the agent cannot
  read the answers.
- 2026-09-13: first live test surfaced two issues, both fixed.
  (a) Model ran `find ..` looking for AGENTS.md/pyproject in parent dirs.
      APPEND_SYSTEM.md step 5 now says: files inside the project directory
      (README added to the list), do not search parent directories.
  (b) `~/Work/*` in external_directory_read matches contents only, not the
      directory entry, so `find ..` from ~/Work/test1 hit the `*: ask`
      fallback. Added a bare entry (`~/Work`, `~/myprojects`, ...) beside
      every starred one. Verified with real headless tool calls from
      ~/Work/test1: `find ..` allowed, `cat ../../notes/...` denied. Note:
      checkPermission("bash", cmd) only evaluates the command allowlist; the
      directory gate composes at tool-call time, so test it with a real run.
- 2026-09-13: scenario 2 hit an ask on a `for` loop (rule `*`). Verified live
  that loop/if/while bodies are gated per inner command (rm -rf and git push
  --force inside loops were denied by their own rules), so `"for *": "allow"`
  only allows the scaffolding. Proposed adding `for *`, `while *`, `if *`
  allows after `"[ *"`; Claude Code refused to write the allow rule itself, so
  the user adds it by hand. Still to do: APPEND_SYSTEM.md "one simple command
  per bash call" line (plan small item).
- 2026-09-13: user added `for *`, `while *`, `if *` allows. Verified live from
  ~/Work/test1: benign loop/if/while bodies run; rm -rf and git push --force
  inside them are still denied by their own rules; sudo and curl inside them
  still ask. Added APPEND_SYSTEM.md line: one simple command per bash call,
  no set -e preambles, loops, or cd-chains. Small item from the plan done.
- 2026-09-13: scenario 6 (cache cleanup) showed the model asking for
  confirmation before any deletion, per the APPEND_SYSTEM Boundaries line.
  Narrowed that line: confirm only for deletions the toolchain cannot
  regenerate (caches, build outputs, lockfile-restorable dependencies are
  exempt). Worded as a category test, not a list, so it generalises across
  languages. The `rm -r*` deny is
  unchanged, so cache cleanup still routes through `find -delete` or
  per-file `rm`, which ask. Allowing those silently is a by-hand config edit.
- 2026-09-13: step 2, handoff only. Created `pi/agent/prompts/` (symlinked to
  ~/.pi/agent/prompts) with `handoff.md`: `/handoff [focus]` runs git status
  and diff --stat, then prints a brief with Objective, State, Files touched,
  Decisions, Open items, Gotchas. Rewritten same day: the brief is written to
  `handoff-<YYYY-MM-DD>-<slug>.md` in the project root (slug from the focus
  argument or the objective), and the reply is only the path plus a one-line
  resume prompt ("Read <path>, then continue from its Open items"). Added
  `handoff-*.md` to the global gitignore (dotfiles/.gitignore, symlinked to
  ~/.gitignore) so the file never dirties a repo. Verified in a scratch repo
  with `pi -p --approve --tools read,bash,write "/handoff <focus>"`: file
  written with the expected name, absent from git status, reply shape
  correct. Deferred issue.md, review.md, wrapup.md
  until subagent tiering (step 3) settles the reviewer/scout invocation.
  Global AGENTS.md deferred: it would duplicate APPEND_SYSTEM.md; the two
  missing git rules (never `git add -A`, no attribution trailers) are a
  two-line addition to the Boundaries section instead.
