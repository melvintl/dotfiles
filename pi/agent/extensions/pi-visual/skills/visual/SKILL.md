---
name: visual
description: Page contract for render_ui. Read before publishing a visual answer (concept map, process, comparison, chart, interactive explainer, 3D scene) so the page works on a phone, loads its libraries and fits the One Dark shell.
---

# Visual answers with render_ui

Melvin reads most pages on a phone, often over Tailscale. Draw when the shape of
the answer matters: things that connect, flow, compare, change over time, or
are worth poking at. A list of facts is still text.

## Pick the form

| The answer is... | Draw | Library |
|---|---|---|
| Concepts and how they relate | Node-link map | Mermaid `flowchart` or D3 force |
| Steps, a pipeline, a protocol | Flow or sequence diagram | Mermaid |
| Options against criteria | Table with coloured verdicts, or a small chart | none, or Chart.js |
| Numbers over time or by category | Line or bar chart | Chart.js or D3 |
| A mechanism you understand by changing an input | Sliders driving an SVG or canvas | plain JS |
| Something spatial | 3D scene with orbit controls | Three.js |
| Algorithm behaviour | Step-through animation with play/step buttons | plain JS + SVG |

Prefer the lightest option. A table or an inline SVG beats a library when it does the job.

## Contract

- Send body markup only. The shell adds `<head>`, the viewport, the title header and the theme.
- Inline everything: data, styles, scripts. The page cannot fetch from anywhere except the CDNs below.
- Load libraries only from these, pinned to a major version:
  - Mermaid: `<script type="module">import mermaid from "https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs"; mermaid.initialize({ startOnLoad: true, theme: "dark" });</script>`
  - D3: `<script src="https://cdn.jsdelivr.net/npm/d3@7"></script>`
  - Chart.js: `<script src="https://cdn.jsdelivr.net/npm/chart.js@4"></script>`
  - Three.js: `<script type="importmap">{"imports":{"three":"https://cdn.jsdelivr.net/npm/three@0.170.0/build/three.module.js","three/addons/":"https://cdn.jsdelivr.net/npm/three@0.170.0/examples/jsm/"}}</script>`
- Use the theme tokens instead of raw colours: `var(--fg)`, `--strong`, `--muted`, `--panel`, `--line`, `--blue`, `--green`, `--yellow`, `--red`, `--purple`, `--cyan`. For libraries that need hex values, read them with `getComputedStyle(document.documentElement).getPropertyValue("--blue")`.

## Phone first

- Design for a 390px wide screen. Nothing may scroll sideways except a `<pre>` or a wide table inside its own `overflow-x: auto` wrapper.
- Diagrams flow top to bottom (`flowchart TD`, not `LR`) and keep labels under about 5 words.
- Tap targets at least 40px high. No hover-only information; anything shown on hover must also show on tap.
- Canvas and SVG size from the container width (`clientWidth`), not fixed pixels, and redraw on `resize`.

## Shape of a good page

1. One sentence at the top saying what the visual shows and the main takeaway.
2. The visual.
3. Optional: a short "how to read this" line or a legend, and controls under the visual.

Keep it to one idea per page. A follow-up question gets a new page, not an edit.

## After publishing

Reply with the URL and at most two lines. If render_ui reports the server is not
running, give the file path instead.

## Drawing on Sage

When the question is about something Melvin has watched or noted, ground the page
in his knowledge base first:

```bash
cd ~/myprojects/sage && ./venv/bin/python kb.py search "<query>"
```

Cite the sources it returns in a small footer list on the page.
