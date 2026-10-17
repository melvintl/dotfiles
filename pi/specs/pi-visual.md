# Spec: `pi-visual` extension for pi: visual answers you can open on a phone

Self-contained handover spec. Everything needed to continue is in this file
plus the code on branch `feat/pi-visual`. No earlier conversation context is
required.

Status on 2026-10-17: first cut written and committed. The pi-free half
(`core.ts`, `server.ts`) passes a smoke test and renders correctly in Chromium
at phone width. The pi wrapper (`index.ts`) has **never been loaded by pi**:
the machine it was written on has no pi install. §7 lists what to do next, in
order.

## 1. Objective

Let pi answer with a page instead of prose when the shape of the answer
matters (concept maps, processes, comparisons, charts, small interactive
explainers, 3D scenes). The page must be:

- **one tool call away:** the model calls `render_ui(title, html)` and gets a URL
- **readable on a phone:** most reading happens on the phone, reached over Tailscale
- **safe enough to run model-written JS:** scripts only from a CDN allowlist, and no network calls out
- **inside the permission model:** the tool writes only to its own directory, with no bash or write grants
- **portable to pi-durable:** the logic lives in pi-free modules, so only a thin wrapper changes when pi's runtime does

## 2. Background and decisions already made

### 2.1 Where the idea came from

CopilotKit's **Open Intelligent UI** (https://www.copilotkit.ai/blog/introducing-open-intelligent-ui,
repo https://github.com/CopilotKit/OpenIntelligentUI, MIT) has agents generate
interfaces on the fly. The agent calls a `generateSandboxedUi` tool that streams
HTML, CSS and JS into a sandboxed iframe, with an approved-CDN restriction.
Stack: Next.js + CopilotKit frontend, a Python LangGraph "Deep Agent" behind
FastAPI, and the AG-UI protocol (https://docs.ag-ui.com) between them. It needs
an `OPENAI_API_KEY` plus a Typesafe key for a format-routing model ("Jev"). It
supports LangChain, Mastra, Google ADK and Microsoft Agent Framework. **pi is
not supported.**

### 2.2 Options considered

| Option | What it is | Verdict |
|---|---|---|
| A. Use OIU as-is | Their Python agent; reach Sage via MCP | Rejected: doesn't use pi, extra API keys, MCP goes against the stance in §2.4 |
| B. AG-UI bridge | Keep their Next.js frontend; a Node server runs pi via the SDK (`createAgentSession`) and translates pi events into AG-UI events | Deferred: about a day of work, heavy stack. Revisit if streaming and chat beside the visual turn out to matter |
| C. pi-visual (this spec) | pi extension: `render_ui` writes a self-contained page; a tiny server and Tailscale put it on the phone | **Chosen** for the first step |

What C gives up compared with OIU: no streaming (the page appears when done), no
chat beside the visual (follow-ups go back to pi), and a CSP page rather than a
locked iframe. What it gains: no new stack, no new keys, and it runs on the
existing GPT model login.

### 2.3 pi-durable and the seam

`pi-durable` (https://earendil.com/posts/pi-durable/) is pi's experimental
next runtime:

- SQLite-committed turns with crash resume
- several clients attached to one session (TUI plus browser)
- typed JSON **documents** stored atomically with the transcript
- conversation fork
- extensions split into **facets** that run in the process they belong to (worker, TUI, browser)
- a CBOR/WebSocket client protocol

It is not yet what the pi CLI runs on, and its APIs may change.

Design rule taken from the local pi strategy notes ("build on pi's own
boundaries, with a seam for pi-durable"): the logic goes in pure modules with
no pi imports, and the pi-specific part is a thin adapter. Under pi-durable,
`index.ts` becomes a browser facet and pages become documents. `core.ts`,
`server.ts` (or its replacement) and the skill carry over.

### 2.4 User constraints (from the dotfiles)

- Deny-first permissions via `@gotgenes/pi-permission-system`
  (`pi/agent/extensions/pi-permission-system/config.json`): `"*": "ask"`, no yolo.
  Any new tool needs an explicit allow or it prompts on every call.
- Stance: small composable tools, local first, no MCP unless unavoidable,
  sceptical of heavy plugins and of anything that writes outside the permission gate.
- One Dark theme everywhere (`pi/agent/themes/one-dark-tmux.json`).
- Default model `openai-codex/gpt-6.1-sol`. Local Qwen 2.5 Coder through Ollama is
  the fallback and is expected to be poor at writing HTML/JS visuals.
- Reads results on the phone, over Tailscale.

## 3. Architecture

```
 pi session (TUI)                       visuals dir (~/.pi/agent/visuals)
 ┌──────────────────────────┐  save    ┌──────────────────────────────┐
 │ model ── render_ui ──────┼────────► │ 2026-10-17-1432-<slug>.html  │
 │   ▲      (index.ts)      │          │ index.html  (newest first)   │
 │   │ URL                  │          └──────────────┬───────────────┘
 │   └──────────────────────┤                         │ read
 │ skill "visual" (loaded   │          ┌──────────────▼───────────────┐
 │  on demand via           │          │ server.ts  127.0.0.1:4178    │
 │  resources_discover)     │          └──────────────┬───────────────┘
 └──────────────────────────┘                         │ tailscale serve --bg 4178
                                                      ▼
                                       phone / desktop browser (HTTPS on tailnet)
```

### 3.1 Files (all under `pi/agent/extensions/pi-visual/`)

| File | Role | pi imports |
|---|---|---|
| `core.ts` | Validate the body, wrap it in the page shell (One Dark CSS, viewport, CSP meta), save with a unique name, regenerate `index.html`, map request paths to files safely | none |
| `server.ts` | `serve(dir, host, port)`: static `.html`-only server; returns `"shared"` on `EADDRINUSE`; `unref()`s so it never keeps pi alive | none |
| `index.ts` | Registers the `render_ui` tool and the `/visuals` command; contributes the skill path via `resources_discover`; starts the server lazily | yes |
| `skills/visual/SKILL.md` | Page contract: when to draw, form → library table, CDN snippets, theme tokens, phone layout rules, reply format, optional Sage grounding | n/a |
| `smoke.ts` | Tests for `core.ts` + `server.ts`. Run: `node pi/agent/extensions/pi-visual/smoke.ts` (Node 23.6+) | none |

pi loads only `index.ts` from a subdirectory, so `smoke.ts`, `core.ts` and
`server.ts` are never loaded as extensions on their own.

## 4. API facts used, and how sure they are

Checked against `earendil-works/pi` main on 2026-10-17 (pi settings show
`lastChangelogVersion` 1.1.0):

- `import { Type } from "@earendil-works/pi-ai"` and
  `import { defineTool, type ExtensionAPI } from "@earendil-works/pi-coding-agent"`.
  Source: `packages/coding-agent/examples/extensions/hello.ts`.
- `ToolDefinition` fields used: `name`, `label`, `description`,
  `promptSnippet` (one line in "Available tools"; custom tools without it are
  left out of that section), `promptGuidelines` (bullets appended to the
  Guidelines section), `parameters` (TypeBox), and
  `execute(toolCallId, params, signal, onUpdate, ctx)` returning
  `{ content: [{ type: "text", text }], details }`.
  Source: `packages/coding-agent/src/core/extensions/types.ts`.
- `pi.on("resources_discover", () => ({ skillPaths: [...] }))` fires after
  `session_start`. Skill dirs are scanned recursively for `SKILL.md`.
  Source: `types.ts` (`ResourcesDiscoverResult`), `docs/skills.md`.
- `pi.registerCommand(name, { description, handler(args, ctx) })` and
  `ctx.ui.notify(msg, "info" | "error")`. Same usage as the existing `clear.ts`
  and `flow-log.ts`.
- Extension discovery: top-level `.ts` files and subdirectories containing
  `index.ts` in `~/.pi/agent/extensions/`.

## 5. Behaviour (as implemented)

### 5.1 `render_ui`

- Params: `title` (2-6 words), `html` (body markup with inline `<style>`/`<script>`).
- Rejects, with a message the model can act on: empty title or body, a body over
  1 MB, or any `<!doctype>`, `<html>`, `<head>` or `<body>` tag.
- Saves `<dir>/<YYYY-MM-DD>-<HHMM>-<slug>.html` in local time. A clash in the same
  minute appends `-2`, `-3` and so on. Then regenerates `index.html`.
- Starts the server if no session in this process has started it yet. If the
  server can't start, the result still succeeds and gives the file path.
- Returns `Published "<title>": <BASE_URL>/<name>`, with details `{ url, file }`.
- Opens the page in the desktop browser when `PI_VISUAL_OPEN=1`.

### 5.2 Page shell (`core.ts` `pageShell`)

- `<meta viewport>`, a One Dark `:root` token set (`--bg --panel --line --fg
  --strong --muted --red --green --yellow --blue --purple --cyan --sans --mono`),
  16px gutter, `max-width: 960px`, no sideways scroll, and responsive
  `svg/canvas/img`.
- Header: escaped title, timestamp, and an "all" link to the index.
- CSP meta tag. It works when the page is served and when opened from disk:
  - scripts: inline, plus `cdn.jsdelivr.net`, `cdnjs.cloudflare.com`, `unpkg.com`
  - styles: inline, plus those CDNs and Google Fonts
  - images: `data: blob: https:`
  - `connect-src`: the CDNs only
  - `default-src 'none'`, `base-uri 'none'`, `form-action 'none'`
  - no `unsafe-eval`

### 5.3 Server

- Binds `PI_VISUAL_HOST:PI_VISUAL_PORT` (default `127.0.0.1:4178`).
- Handles GET/HEAD only. Serves `.html` inside the directory; `/` serves the
  index; anything else is 404.
- Headers: `no-store`, `nosniff`, `no-referrer`.
- Use `tailscale serve`, not `0.0.0.0`, to reach it from the phone.

### 5.4 Environment

| Var | Default | Meaning |
|---|---|---|
| `PI_VISUAL_DIR` | `$PI_CODING_AGENT_DIR/visuals` or `~/.pi/agent/visuals` | Where pages go |
| `PI_VISUAL_HOST` | `127.0.0.1` | Bind address |
| `PI_VISUAL_PORT` | `4178` | Port |
| `PI_VISUAL_URL` | `http://localhost:<port>` | Base URL in returned links. Set it to the `tailscale serve` URL for links that work on the phone |
| `PI_VISUAL_OPEN` | unset | `1` opens each new page in the desktop browser |

### 5.5 `/visuals` command

`/visuals` shows the index URL and the directory. `/visuals open` opens the
newest page in the browser.

### 5.6 Skill `visual`

Loaded on demand (the description routes it), so the guidance costs no context
until a visual is needed. Libraries are pinned by major version: Mermaid 11
(ESM), D3 7, Chart.js 4, Three.js 0.170.0 via import map. Mermaid diagrams flow
top to bottom, tap targets are at least 40px, nothing is hover-only, and charts
size from container width. One idea per page; a follow-up gets a new page. The
reply is the URL plus at most two lines. Sage grounding is optional:
`cd ~/myprojects/sage && ./venv/bin/python kb.py search "<query>"`.

## 6. Verified so far

- `node pi/agent/extensions/pi-visual/smoke.ts` passes all 17 checks: naming,
  clash suffix, slug fallback, rejecting full documents, traversal and encoded
  traversal blocked, `.html` only, index served, port sharing, page served with
  CSP, title escaped, index lists pages, 404.
- A Mermaid test page rendered in headless Chromium (Playwright) at 390×600 with
  the CSP on: no console errors, `scrollWidth` 390 (no sideways scroll), diagram
  visible.

## 7. Next steps (in order)

1. **Allow the tool.** In `pi/agent/extensions/pi-permission-system/config.json`,
   add `"render_ui": "allow",` next to the other tool allows (after
   `"lsp_fix": "allow",`). Without it, every call prompts.
2. **Load it.** Run `make setup-pi` (links `pi/agent/extensions` to
   `~/.pi/agent/extensions`), then start pi. Check:
   - pi starts with no extension load error
   - `render_ui` is in the tool list
   - the `visual` skill is listed (`/skill:visual` resolves)
   - `/visuals` shows the URL

   If loading fails, see §8.
3. **Run the smoke test** on this machine:
   `node pi/agent/extensions/pi-visual/smoke.ts`.
4. **Phone access.** Run `tailscale serve --bg 4178` and note the
   `https://<host>.<tailnet>.ts.net` URL. Export `PI_VISUAL_URL` with it from a
   local, untracked shell file (it's a hostname, not a secret, but it is
   machine-specific). Open `<url>/` on the phone and confirm the index loads.
5. **End-to-end prompts** with the default GPT model. Each should produce a working
   page on the phone:
   - "Show me AG-UI vs MCP visually" (Mermaid concept map)
   - "Visualise how binary search narrows the range, step by step" (interactive SVG)
   - "Compare tmux, zellij and wezterm multiplexing on 4 criteria" (table/chart)
   - "Show a rotating 3D model of a DNA helix" (Three.js import map under CSP)
   - a plain factual question should get **no** page
6. **Tune the skill** from step 5: failure modes, library snippets that break
   under CSP, layouts that overflow at 390px.
7. **Optional polish:**
   - a compact TUI renderer for `render_ui` results (one line with the URL;
     `codemode-compact.ts` shows how to use `registerToolRenderer`)
   - prune old pages (age or count limit)
   - a launchd agent so the server outlives pi sessions (§8)

## 8. Known unknowns: resolve on the pi machine, don't assume

- **`.ts` import specifiers.** `index.ts` imports `./core.ts` and `./server.ts`
  with the extension, which Node's type stripping needs for `smoke.ts`. pi's
  loader is expected to accept that. If it doesn't, try extensionless imports
  in `index.ts` only.
- **`import.meta.url` under pi's loader.** `HERE` uses it to find `skills/`. If
  the skill doesn't appear, log `HERE` and fall back to `__dirname`.
- **Server lifetime.** The server lives in whichever pi process started it and
  dies with it. Links stay valid while any pi session runs; the next
  `render_ui` or `/visuals` restarts the server. If dead links on the phone
  annoy, add a launchd agent that runs the server on its own, which needs a
  tiny `serve-cli.ts` entry.
- **Subagents** (`pi-subagents`) may run in separate processes. They'd get
  `"shared"` and reuse the running server, which is fine as long as they use the
  same `PI_VISUAL_DIR`.
- **Ask mode in headless runs.** If `render_ui` isn't allowed (§7 step 1), a
  headless pi run has no one to answer the prompt.
- **Local model quality.** Expect Qwen 2.5 Coder to produce broken pages.
  Consider `render_ui` a GPT-only feature unless proven otherwise.
- **CSP vs libraries.** Mermaid 11 is verified. D3, Chart.js and Three.js are
  not yet. Anything needing `eval` will fail; prefer fixing the skill over
  loosening the CSP.

## 9. Later phases (out of scope for this branch)

- **Live update / streaming:** an SSE endpoint so an open page reloads when it
  is republished, which gets closer to OIU's streaming feel.
- **pi-durable:** when it graduates from experimental (or the CLI gains a flag
  to run on it), replace `index.ts` with a browser facet that renders pages
  inside an attached web client, and store each page as a typed **document**
  with the turn that made it. Forks then give branching explorations for free.
- **AG-UI bridge (option B):** a Node server running pi via `createAgentSession`
  and emitting AG-UI events (`RUN_STARTED`, `TEXT_MESSAGE_CONTENT`,
  `TOOL_CALL_START`/`ARGS`/`END`, ...), with OIU's Next.js frontend pointed at
  it. Do this only if streaming and chat beside the visual prove worth the stack.

## 10. Acceptance criteria for merging the branch

- §7 steps 1 to 5 done, with the five prompts passing on the phone.
- `smoke.ts` passes.
- No writes outside `PI_VISUAL_DIR`, and no new bash or write permission grants.
- `make check` still passes.
