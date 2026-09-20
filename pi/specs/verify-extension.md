# Spec: `verify` extension for pi — autonomous builder/verifier loop

Self-contained implementation spec. Everything needed to build this is in this
file plus the referenced source files on this machine. No other conversation
context is required.

## 1. Background and environment

**pi** is a minimal, extensible AI coding agent (npm package
`@earendil-works/pi-coding-agent`). Where it is installed depends on the OS
and install method (Homebrew/npm global, mise, standalone binary) — never
hard-code it; locate it as described in §4. It ships four built-in tools
(read, bash, edit, write), a ~200-token system prompt, and a TypeScript
extension API. Extensions are single `.ts` files auto-discovered from
`~/.pi/agent/extensions/`, which is version-controlled in the dotfiles repo
at `pi/agent/extensions/` (`~/.pi/agent/extensions` is a symlink into that
checkout, so both paths name the same directory).

Path conventions in this spec: `~` means the user's home directory and
`<pi-install>` means the pi install root (§4). In code, build paths with
`os.homedir()`, `os.tmpdir()` and `path.join` — no literal `/Users/...`,
`/home/...`, `/opt/homebrew/...` or `/tmp/...` strings.

Existing extensions in that directory to use as style/API references:

- `flow-log.ts` — subscribes to agent-loop events, writes a markdown trace.
  Best reference for event handler signatures and `pi.registerCommand`.
- `clear.ts` — shows module-level state surviving session replacement, and
  `ctx.ui.notify`.
- `startup-info.ts` — shows custom TUI entries and reading pi internals.

The user's default builder model is `openai-codex/gpt-5.5` (see
`~/.pi/agent/settings.json`). Sessions are stored as JSONL files under
`~/.pi/agent/sessions/`.

## 2. Why this extension exists (motivation)

Two human bottlenecks exist in agentic coding: planning and reviewing. This
extension automates reviewing, for unattended/long-running sessions where the
human is not watching (the user runs goal-based autonomous sessions via
`@narumitw/pi-goal` and a strongly autonomous APPEND_SYSTEM.md).

The design is a **builder + verifier** pair:

- The **builder** is the normal interactive pi session doing the work.
- The **verifier** is a separate, freshly spawned, headless pi process that
  activates automatically when the builder finishes, and checks the work
  against the *user's original prompt* — not against the builder's summary of
  what it did.

Why a separate process rather than self-review in the same session:

1. **No shared blind spots.** A model reviewing its own turn reasons from the
   same (possibly wrong) context that produced the mistake. The verifier
   starts cold and re-derives what "done" means from the original prompt and
   the raw session transcript.
2. **No sycophancy.** The verifier's only job is to falsify claims; it has no
   investment in the work passing.
3. **Different tool policy.** The verifier runs read-only (`read`, `grep`,
   `find`, `ls`; no bash, no edit, no write, no extensions, no skills). One
   session cannot have two tool policies; two processes can.
4. **Forcing function.** The verifier takes no interactive input. Every bad
   verification must be fixed by editing the verifier's system prompt file,
   so review standards accumulate there instead of evaporating in chat.

The verifier's report always includes "what I could not verify and what I
would need to verify it" — the user reads this and adds rules to the verifier
prompt, so the system gets stricter over time.

Cost expectation: verification adds roughly 2–5x tokens per builder turn.
That is accepted; it trades tokens for trust in unattended runs. It is OFF by
default and enabled per session.

## 3. Architecture

```
                YOU (or a goal run)
                     │ prompt
                     ▼
┌──────────────────────────────────┐      spawn per verification
│ BUILDER — normal pi TUI session  │      (child process, exits when done)
│                                  │     ┌──────────────────────────────────┐
│  verify.ts extension:            │     │ VERIFIER — headless pi:          │
│   on("agent_settled")            │     │  pi -p --no-extensions           │
│     if enabled && tools ran ─────┼────▶│     --no-skills --no-session     │
│       spawn verifier, passing:   │     │     --no-context-files           │
│        - session file path       │     │     --tools read,grep,find,ls    │
│        - original user prompt    │     │     --system-prompt VERIFIER.md  │
│                                  │     │                                  │
│   parse verdict JSON from stdout │◀────┼── prints ONE JSON object as its  │
│   write report .md to disk       │     │   entire final answer            │
│   if fail && rounds < MAX:       │     └──────────────────────────────────┘
│     pi.sendUserMessage(feedback) │                    │ reads (read tool)
│     → builder runs again         │                    ▼
│     → agent_settled fires again  │        builder session .jsonl
│     → re-verify (round++)        │        (~/.pi/agent/sessions/…)
└──────────────────────────────────┘
             │ writes
             ▼
  ~/.pi/agent/verify/reports/<timestamp>-round<N>.md   ← human reads these;
  VERIFIER.md "couldn't verify" items → user adds rules → system improves
```

There is no socket and no persistent second instance in this version: the
`agent_settled` hook plus a spawned child process *is* the plumbing.

## 4. Verified API facts (checked against v0.85.x type declarations)

Re-check against whatever version is installed (`pi --version`) if anything
below does not compile; do not guess.

Locating `<pi-install>` (pick whichever matches the machine):

- npm/Homebrew global install:
  `$(npm root -g)/@earendil-works/pi-coding-agent`
- mise or standalone binary: the directory containing the real `pi`
  executable — resolve symlinks/shims from `command -v pi` (with mise it
  is the `pi/` subdirectory of `mise where pi`).

Source of truth, in order of preference:

1. Type declarations, present in npm installs:
   `<pi-install>/dist/core/extensions/types.d.ts` and
   `<pi-install>/dist/core/session-manager.d.ts`.
2. Bundled docs, present in every install including standalone binaries
   (which ship no `dist/*.d.ts`): `<pi-install>/docs/extensions.md`,
   `<pi-install>/docs/session-format.md`, `<pi-install>/docs/sdk.md`.

Extension entry point (same shape as `flow-log.ts`):

```ts
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
export default function (pi: ExtensionAPI) { /* register handlers */ }
```

Events (handler: `pi.on(name, async (event, ctx) => {...})`):

- `"session_start"` — fires on startup, `/new`, `/resume`, `/fork`; event has
  `reason`. Reset all per-session state here.
- `"before_agent_start"` — fires per user prompt. `event.prompt` is the raw
  user prompt text; `event.systemPrompt` is the assembled system prompt.
  Use this to capture the original prompt (and to detect our own injected
  feedback — see §5.4).
- `"agent_settled"` — fires after an agent run has fully settled and **no
  automatic retry, compaction, or queued continuation will run**. This is the
  verification trigger. Prefer it over `"agent_end"`, which can fire before
  retries/compaction finish.
- `"tool_execution_start"` — `event.toolName`, `event.args`. Count these per
  run to skip verification of pure-chat turns.

Context (`ctx: ExtensionContext`):

- `ctx.sessionManager.getSessionFile()` — absolute path of the current
  session JSONL. (`ReadonlySessionManager` also exposes `getSessionId()`,
  `getSessionDir()`.)
- `ctx.isIdle()` — true when the agent is not streaming.
- `ctx.ui.notify(text, "info" | "warning" | "error")`.
- `ctx.cwd` — builder's working directory; pass to the verifier spawn.

ExtensionAPI methods:

- `pi.sendUserMessage(content, { deliverAs?: "steer" | "followUp" })` —
  injects a user message into the builder session; **always triggers a
  turn**. This is the feedback path.
- `pi.exec(command, args, options): Promise<ExecResult>` — run a child
  process. Check the `ExecOptions`/`ExecResult` types for cwd/timeout/stdout
  fields before use. (Fallback if it is awkward: `node:child_process`
  `execFile` with `maxBuffer` raised — extensions are plain Node-side TS and
  may import `node:*` modules, as `flow-log.ts` does.)
- `pi.registerCommand(name, { description, handler })` — for the `/verify`
  command.
- `pi.appendEntry(customType, data)` — optional, persist state into the
  session (not sent to the LLM).

Headless pi CLI (verified via `pi --help`):

```
pi -p "<prompt>"                 non-interactive: process prompt, print, exit
   --no-extensions               CRITICAL: prevents verify.ts loading into the
                                 verifier (no recursion) and drops all other
                                 extensions (permission system, goal, etc.)
   --no-skills --no-context-files --no-session
   --tools read,grep,find,ls     allowlist: read-only verifier. `grep`,
                                 `find`, and `ls` are needed for independent
                                 completeness checks; mutation and shell tools
                                 remain unavailable.
   --system-prompt "<text>"      replaces the system prompt entirely
   --provider <name> --model <pattern>
```

## 5. Requirements

### 5.1 Files

| Path | Purpose |
|---|---|
| `agent/extensions/verify.ts` (dotfiles) → `~/.pi/agent/extensions/verify.ts` | the extension |
| `~/.pi/agent/verify/VERIFIER.md` | verifier system prompt (create with starter content, §6) |
| `~/.pi/agent/verify/reports/` | one markdown report per verification run |

Add `verify/reports/` to the dotfiles gitignore; `VERIFIER.md` should be
version-controlled (it is the accumulating asset).

### 5.2 Configuration (constants at top of `verify.ts`)

- `MAX_FEEDBACK_ROUNDS = 2` — max verifier→builder feedback injections per
  original user prompt.
- `VERIFIER_TIMEOUT_MS = 300_000` — kill the verifier child after this;
  treat as "unverified", notify, do not inject feedback.
- `VERIFIER_PROVIDER` / `VERIFIER_MODEL` — default `"openai-codex"` /
  `"gpt-5.5"`. Comment in code: prefer a *different model family* from the
  builder when auth for one is available (cross-checking models don't share
  blind spots); keep as constants for now.
- `FEEDBACK_PREFIX = "[verifier feedback]"` — prepended to injected messages.

### 5.3 Enablement

- Default **off**.
- `/verify on` / `/verify off` / `/verify` (status) via `registerCommand`.
- Also enabled at startup if env `PI_VERIFY=1` (for goal/headless-launched
  sessions where nobody types commands).
- When off, the extension must be inert apart from the command.

### 5.4 Behavior

Per-session state (reset on `session_start`): `enabled`, `originalPrompt`,
`round`, `toolCallsThisRun`, `generation` (monotonic counter), `verifying`
flag, and `pendingVerification` flag.

1. On `before_agent_start`:
   - If `event.prompt` starts with `FEEDBACK_PREFIX`: this is our own
     injection — do **not** overwrite `originalPrompt`, do not reset `round`.
   - Otherwise: `originalPrompt = event.prompt`, `round = 0`,
     `generation++`.
   - Reset `toolCallsThisRun = 0`.
2. On `tool_execution_start`: `toolCallsThisRun++`.
3. On `agent_settled`:
   - Skip (silently) if: disabled, `toolCallsThisRun === 0`, or
     `originalPrompt` is empty.
   - If a verification is already in flight, set `pendingVerification = true`
     and return. This prevents a race where a stale verifier result is
     discarded but the newer settled run is never verified.
   - Otherwise call `runVerificationForLatest()`:
     - Set `verifying = true`, `pendingVerification = false`.
     - Capture `const gen = generation`, `const prompt = originalPrompt`,
       `const roundAtStart = round`, and `const sessionFile =
       ctx.sessionManager.getSessionFile()`.
     - Spawn the verifier (§5.5) with the session file path, captured prompt,
       captured round, and `ctx.cwd`.
     - When it returns: if `generation !== gen` (the user prompted again while
       we verified), discard the result entirely and do not write a report or
       inject feedback for the stale generation.
     - Parse the verdict (§5.6). Write the report file. Notify
       (`ctx.ui.notify`) with status + report path — green info on pass,
       warning on fail.
   - If `status === "fail"` and `round < MAX_FEEDBACK_ROUNDS` and
     `ctx.isIdle()`: `round++`, then
     `pi.sendUserMessage(FEEDBACK_PREFIX + " " + feedback)`. The resulting
     run will fire `agent_settled` again and re-verify — that loop is
     intentional and bounded by `MAX_FEEDBACK_ROUNDS`.
   - If `status === "fail"` and rounds are exhausted: notify error
     "verification still failing after N rounds — see report", inject
     nothing.
   - On timeout / crash / unparseable output: notify warning "unverified",
     write whatever raw output was captured to the reports dir, inject
     nothing. Never let a verifier failure block or crash the builder.
   - In `finally`, set `verifying = false`. If `pendingVerification === true`
     and the extension is still enabled, call `runVerificationForLatest()`
     once more for the latest generation. This follow-up pass must re-check
     `toolCallsThisRun`, `originalPrompt`, and current state before spawning.

### 5.5 Spawning the verifier

Build the child argv exactly as:

```
pi -p --no-extensions --no-skills --no-context-files --no-session \
   --tools read,grep,find,ls \
   --provider $VERIFIER_PROVIDER --model $VERIFIER_MODEL \
   --system-prompt "<contents of ~/.pi/agent/verify/VERIFIER.md>" \
   "<task prompt, see below>"
```

Run it with the builder's `cwd`. The task prompt (user message) is:

```
Original user request to the builder agent:
<originalPrompt>

Builder session transcript (JSONL, one entry per line):
<absolute session file path>

Allowed read scope:
- The session transcript above.
- Files under the builder working directory: <ctx.cwd>.
- Files explicitly referenced in the transcript as created, edited, read, or
  tested by the builder.
Do not read secrets, credentials, auth stores, `.env` files, SSH/AWS/cloud
configuration, or unrelated home-directory files. If verification would require
one of those, mark the claim unverifiable and say what safe evidence would be
needed.

Feedback round: <round> of <MAX_FEEDBACK_ROUNDS>.
Read the transcript and the files it mentions, then verify per your
instructions. Reply with the single JSON object only.
```

Notes:
- `--system-prompt` takes text, not a path: read `VERIFIER.md` yourself and
  pass the contents. If the file is missing, notify error once and stay
  inert. Keep the starter prompt compact; if this file grows enough to risk OS
  argv limits, replace the inline prompt with a minimal system prompt that
  instructs the verifier to read `VERIFIER.md` from the allowed config path.
- The verifier discovers everything else (what files were touched, what was
  claimed) by reading the session JSONL with its `read` tool and using `grep`,
  `find`, and `ls` for independent read-only completeness checks. Session
  entries include user/assistant messages and tool calls with args and
  results — the implementer should open one real file from
  `~/.pi/agent/sessions/` once to confirm the shape before writing the
  VERIFIER.md guidance about it.

### 5.6 Verdict contract

The verifier's entire final answer must be one JSON object (enforced by
VERIFIER.md, §6):

```json
{
  "status": "pass" | "fail",
  "claims": [ { "claim": "...", "verdict": "verified" | "failed" | "unverifiable", "evidence": "..." } ],
  "feedback": "only when status=fail: a direct, specific instruction to the builder naming what to fix and which rule/claim failed",
  "cannot_verify": [ "what I could not verify and what access/rule I would need to verify it next time" ]
}
```

Parsing: take the **last complete JSON object** found in stdout (models
sometimes emit a preamble; `-p` prints the final assistant text). Do not use a
naive greedy regex; implement a small brace scanner that tracks strings and
escapes, walks candidate object starts from the end, and attempts
`JSON.parse`. If parsing fails → "unverified" path (§5.4).

Verdict semantics: `status: "pass"` is allowed only when every required claim
from the original request is verified. Any failed or unverifiable required
claim makes `status: "fail"`. Non-required observations may be listed in
`cannot_verify`, but the report must make clear they were not part of the
acceptance decision.

Report file `~/.pi/agent/verify/reports/<ISO-timestamp>-round<N>.md`
(timestamp colons replaced, same style as flow-log): render status, the
original prompt, the claims table, `cannot_verify` items under a heading
**"Add rules for these"**, and the feedback sent (if any).

## 6. Starter `~/.pi/agent/verify/VERIFIER.md`

Create it with this content (it will grow over time; that is the point):

```markdown
You are a verification agent. You take no conversational input. You audit the
work of a separate "builder" coding agent and output a machine-readable
verdict. You are skeptical by default: your job is to falsify, not to approve.

Procedure:
1. Read the builder's session transcript (JSONL path given in the task).
   Identify what the ORIGINAL USER REQUEST asked for. Ignore the builder's
   own summary of its work except as a source of claims to check.
2. Decompose the request + the builder's claims into atomic claims — small
   statements that are individually provable true or false (e.g. "file X
   exists", "X contains a function that does Y", "the tests were actually
   run and passed", "ALL matching items were found, not just some").
3. Verify each claim with read-only tools: open the files, check the tool
   results in the transcript (a claimed command run must appear as a real
   tool call with real output), and use grep/find/ls when needed to look for
   counterexamples. Completeness claims ("all", "every") require independent
   counterexample search.
4. Stay inside the allowed read scope from the task. Do not read secrets,
   credentials, auth stores, `.env` files, SSH/AWS/cloud configuration, or
   unrelated home-directory files. If a claim would require that access, mark
   it unverifiable and explain what safe evidence would verify it.
5. A required claim you cannot check with read-only access is
   "unverifiable" and causes status fail. Never silently pass it; list what
   you would need in cannot_verify.

Contract rules (violating any rule = status fail):
- R1: Every file the builder claims to have created or edited must exist and
  contain the claimed change.
- R2: Any command the builder claims to have run must appear in the
  transcript as an executed tool call; claimed test/lint results must match
  the actual tool output.
- R3: The work must satisfy the original request, including its scope words
  ("all", "each", "every"), not a narrowed version of it.
- R4: A pass verdict requires every required original-request claim to be
  verified. Failed or unverifiable required claims must produce status fail.

Output: your ENTIRE final reply must be exactly one JSON object, no markdown
fences, no prose, with this shape:
{"status":"pass|fail","claims":[{"claim":"...","verdict":"verified|failed|unverifiable","evidence":"..."}],"feedback":"...","cannot_verify":["..."]}
"feedback" is present only when status is fail, is addressed to the builder,
and must name the failed claim/rule and the concrete fix required.
```

## 7. Acceptance tests

Run from a scratch project directory, referred to below as `<scratch>`
(e.g. `mkdir -p "${TMPDIR:-/tmp}/verify-test" && cd "$_"`).
Interactive TUI tests first; observe reports in `~/.pi/agent/verify/reports/`
and notifications in the TUI.

1. **Inert by default**: start `pi`, prompt something with tool use, confirm
   no verifier spawn, no report file.
2. **Happy path**: `/verify on`, prompt "create hello.txt containing exactly
   'hello world'". Expect: builder finishes → short pause → info notification
   `pass` → report file with all claims verified → no extra builder turn.
3. **Failure + feedback loop**: add a canary rule to VERIFIER.md, e.g.
   "R4: any created markdown file must contain a `## Summary` section". Then
   `/verify on`, prompt "create notes.md with three bullet points about git".
   Expect: verifier fails R4 → builder receives a `[verifier feedback]`
   message → builder adds the section → second verification passes. Exactly
   the bounded loop, then silence. Remove the canary rule after the test.
4. **Round cap**: make a rule impossible (canary: "R5: notes.md must be
   empty AND contain a Summary section"), repeat test 3. Expect feedback
   injected at most `MAX_FEEDBACK_ROUNDS` times, then an error notification
   and stop. Remove the rule.
5. **Chat turns skipped**: `/verify on`, prompt "what does 2+2 equal" (no
   tools). Expect no verifier spawn.
6. **New prompt cancels stale verdict and verifies latest run**: start a
   verification (use a slow prompt), immediately type a new tool-using prompt;
   confirm the stale verdict is discarded (no report/feedback for the old
   generation) and the newer settled run still gets its own verification
   report/feedback decision.
7. **Verifier is read-only**: temporarily add to the task prompt "also
   attempt to create a file <scratch>/pwned"; confirm the file is not
   created (verifier has only `read`, `grep`, `find`, and `ls`).
8. **Verifier absence of recursion**: while a verification runs, confirm no
   second-level verifier process appears (`pgrep -fl "pi -p"` shows one).
9. **Typecheck**: the extension compiles against the installed
   `@earendil-works/pi-coding-agent` types (match how existing extensions in
   the directory are checked; at minimum `npx tsc --noEmit` with the same
   settings the other `.ts` extensions satisfy). Standalone/mise installs
   ship no type declarations — there, typecheck against the npm package
   installed as a throwaway dev dependency in `<scratch>`, pinned to the
   `pi --version` in use.

## 8. Known unknowns — resolve during implementation, don't assume

- Exact `ExecOptions`/`ExecResult` shape for `pi.exec` (timeout? stdout
  capture limits?). Read the type declarations; fall back to
  `node:child_process.execFile` if needed.
- Whether `-p` mode prints only the final assistant text or also tool chatter
  — hence the "parse last JSON object" rule. Confirm with one manual run.
- Session JSONL entry schema — inspect a real file under
  `~/.pi/agent/sessions/` before finalizing the VERIFIER.md wording about
  transcripts.
- Whether `sendUserMessage` after `agent_settled` needs `deliverAs` set when
  the builder is idle. Test; default (no option) is expected to work when
  idle.
- Whether the verifier can reliably respect read-scope instructions with only
  tool prompting. If not, phase 1.1 should add a small verifier-specific read
  gate instead of relying on prompt discipline.

## 9. Explicitly out of scope (possible phase 2)

- Persistent verifier instance / Unix socket transport / live TUI pane.
- A footer widget showing verify status.
- Multiple specialist verifiers (per-domain VERIFIER files).
- Cross-machine operation.
- Verifying in `-p` (headless builder) mode — interactive + goal sessions
  only for now.
