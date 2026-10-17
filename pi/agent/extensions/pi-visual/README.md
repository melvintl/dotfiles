# pi-visual

Lets pi answer with a page instead of prose: concept maps, flows, charts, force
graphs, interactive explainers, 3D scenes. The model calls
`render_ui(title, html)` and gets back a URL.

| File | Role |
|---|---|
| `core.ts` | Validates the body, wraps it in the One Dark page shell with a CSP, saves it, rebuilds `index.html`. No pi imports |
| `server.ts` | Static `.html`-only server on `127.0.0.1`. A second pi session reuses the running server. No pi imports |
| `index.ts` | pi wrapper: the `render_ui` tool, the `/visuals` command, and the skill path |
| `skills/visual/SKILL.md` | Page contract the model reads on demand: which library for which shape, snippets, layout, D3 force template |
| `smoke.ts` | Tests for `core.ts` and `server.ts`: `node pi/agent/extensions/pi-visual/smoke.ts` |

Pages go to `~/.pi/agent/visuals/`; `http://localhost:4178/` lists them newest
first. `/visuals` shows the URL and `/visuals open` opens the newest page.
`render_ui` is allowed in `pi-permission-system/config.json`.

## Settings

| Var | Default | Meaning |
|---|---|---|
| `PI_VISUAL_DIR` | `~/.pi/agent/visuals` | Where pages go |
| `PI_VISUAL_PORT` | `4178` | Server port |
| `PI_VISUAL_URL` | `http://localhost:<port>` | Base URL in returned links |

For the phone, run `tailscale serve --bg 4178` and set `PI_VISUAL_URL` to the
`https://<host>.<tailnet>.ts.net` address it prints. Don't bind to `0.0.0.0`.

## Page security

The CSP lets scripts, styles and images load only from cdn.jsdelivr.net,
cdnjs.cloudflare.com and unpkg.com (plus Google Fonts for styles), and blocks
fetch to anywhere else. That stops background requests, but CSP can't stop a
page navigating away (`location.href`, `window.open`, a link you tap), so a
malicious page could still carry its content out in a URL. Those CDNs serve
any npm package or GitHub repo, so the allowlist is not a trust boundary for
the code itself.

## Known limits

- The server lives in a pi process. When that pi exits, the next `render_ui`
  or `/visuals` call from another pi takes the port over, but links are dead
  while no pi is running. A launchd agent would keep it up.
- Old pages are never pruned.
- Later: live reload over SSE; under pi-durable, `index.ts` becomes a browser
  facet and pages become documents, while `core.ts`, `server.ts` and the skill
  carry over.
