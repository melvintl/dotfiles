---
name: visual
description: Page contract for render_ui. Read before publishing a visual answer (concept map, process, comparison, chart, interactive explainer, 3D scene) so the page works from laptop to phone width, loads its libraries and fits the One Dark shell.
---

# Visual answers with render_ui

Melvin reads most pages on a laptop, sometimes on a phone over Tailscale.

## Pick the form

| The answer is... | Draw | Library |
|---|---|---|
| A hierarchy, or under ~12 nodes with few cross-links | Node-link map | Mermaid `flowchart` |
| A network: ~12+ nodes where many link across groups (alliances, influences, dependencies, citations) | Force-directed graph | D3 force (template below) |
| Steps, a pipeline, a protocol | Flow or sequence diagram | Mermaid |
| Options against criteria | Table with coloured verdicts, or a small chart | none, or Chart.js |
| Numbers over time or by category | Line or bar chart | Chart.js or D3 |
| A mechanism you understand by changing an input | Sliders driving an SVG or canvas | plain JS |
| Something spatial | 3D scene with orbit controls | Three.js |
| Algorithm behaviour | Step-through animation with play/step buttons | plain JS + SVG |

Prefer the lightest option. A table or an inline SVG beats a library when it does the job. The
exception is a network: don't flatten it into boxes, cards or a Mermaid tree, which hides the
cross-links.

## Contract

- Write scripts readable and indented, one statement per line, never minified. Minified code drops
  brackets, and a single syntax error leaves the page blank.
- Inline all data; the page cannot fetch. Load libraries with these snippets:
  - Mermaid: `<script type="module">import mermaid from "https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs"; mermaid.initialize({ startOnLoad: true, theme: "dark" });</script>`
    - In Mermaid label, message and note text, never use a bare `;` (it ends the statement, so the
      diagram fails with "Syntax error in text") or `#`. Use a comma, or `#59;` / `#35;` for a literal one.
  - D3: `<script src="https://cdn.jsdelivr.net/npm/d3@7"></script>`
  - Chart.js: `<script src="https://cdn.jsdelivr.net/npm/chart.js@4"></script>`
  - Three.js: `<script type="importmap">{"imports":{"three":"https://cdn.jsdelivr.net/npm/three@0.170.0/build/three.module.js","three/addons/":"https://cdn.jsdelivr.net/npm/three@0.170.0/examples/jsm/"}}</script>`
- Use the theme tokens instead of raw colours: `var(--fg)`, `--strong`, `--muted`, `--panel`, `--line`, `--blue`, `--green`, `--yellow`, `--red`, `--purple`, `--cyan`, `--orange`. For libraries that need hex values, read them with `getComputedStyle(document.documentElement).getPropertyValue("--blue")`.

## D3 force graph template

Replace `nodes`, `links` and the intro line; keep the rest. Don't shrink nodes or labels and don't
add zoom-to-fit (a reset may go back to `d3.zoomIdentity`, no smaller). Labels at most ~12
characters ("Tywin", not "Tywin Lannister"), with full names and detail in a `note` field shown in
`#info`. At most 7 groups, one per colour.

```html
<p>Tap a node to highlight its neighbours; drag to move, pinch or scroll to zoom.</p>
<div class="split">
  <div id="graph" style="border:1px solid var(--line);border-radius:8px;background:var(--panel);touch-action:none"></div>
  <aside>
    <div id="legend" style="display:flex;flex-wrap:wrap;gap:8px 12px;font-size:.85rem"></div>
    <div id="info" style="margin-top:12px;color:var(--muted)">Tap a node to see its connections.</div>
  </aside>
</div>
<script src="https://cdn.jsdelivr.net/npm/d3@7"></script>
<script>
const nodes = [
  { id: "C", group: "systems", note: "Bell Labs, 1972" }, { id: "Lisp", group: "functional" },
  { id: "Python", group: "scripting" }, { id: "Rust", group: "systems" }, { id: "Haskell", group: "functional" },
];
const links = [
  ["C", "Python"], ["Lisp", "Python"], ["Haskell", "Python"], ["C", "Rust"], ["Haskell", "Rust"],
].map(([source, target]) => ({ source, target }));

const css = (v) => getComputedStyle(document.documentElement).getPropertyValue(v).trim();
const groups = [...new Set(nodes.map((d) => d.group))];
const colour = d3.scaleOrdinal(groups, ["--blue", "--green", "--purple", "--yellow", "--cyan", "--red", "--orange"].map(css));
const box = document.getElementById("graph");
const svg = d3.select(box).append("svg").style("display", "block");
const view = svg.append("g");
svg.call(d3.zoom().scaleExtent([0.4, 4]).on("zoom", (e) => view.attr("transform", e.transform)));

const link = view.append("g").attr("stroke", css("--line")).attr("stroke-width", 1.5)
  .selectAll("line").data(links).join("line");
const node = view.append("g").selectAll("g").data(nodes).join("g").style("cursor", "pointer");
node.append("circle").attr("r", 12).attr("fill", (d) => colour(d.group)); // r 12 + label ≈ 40px tap target
node.append("text").text((d) => d.id).attr("x", 16).attr("y", 4)
  .attr("fill", css("--strong")).attr("font-size", 13).attr("paint-order", "stroke")
  .attr("stroke", css("--panel")).attr("stroke-width", 3);

const sim = d3.forceSimulation(nodes)
  .force("link", d3.forceLink(links).id((d) => d.id))
  .force("charge", d3.forceManyBody().strength(nodes.length > 15 ? -480 : -320))
  .force("collide", d3.forceCollide(34))
  .on("tick", () => {
    // Keep every node and its label inside the box (label ≈ 7.5px per character at 13px).
    for (const d of nodes) {
      d.x = Math.max(14, Math.min(w - 20 - 7.5 * d.id.length, d.x));
      d.y = Math.max(14, Math.min(h - 14, d.y));
    }
    link.attr("x1", (d) => d.source.x).attr("y1", (d) => d.source.y).attr("x2", (d) => d.target.x).attr("y2", (d) => d.target.y);
    node.attr("transform", (d) => `translate(${d.x},${d.y})`);
  });

// Size from the box width and the window height: tall on a phone, wide on a laptop.
let w, h;
function size() {
  w = box.clientWidth;
  h = Math.round(w < 600 ? Math.min(w * 1.3, 640) : Math.max(480, Math.min(innerHeight * 0.75, 900)));
  svg.attr("viewBox", [0, 0, w, h]).attr("width", w).attr("height", h);
  sim.force("link").distance(Math.max(60, Math.min(w, h) / 5));
  sim.force("center", d3.forceCenter(w / 2, h / 2))
    .force("x", d3.forceX(w / 2).strength(0.06)).force("y", d3.forceY(h / 2).strength(0.06));
  sim.alpha(0.5).restart();
}
size();
let resizing;
addEventListener("resize", () => { clearTimeout(resizing); resizing = setTimeout(size, 150); });

node.call(d3.drag()
  .on("start", (e, d) => { if (!e.active) sim.alphaTarget(0.3).restart(); d.fx = d.x; d.fy = d.y; })
  .on("drag", (e, d) => { d.fx = e.x; d.fy = e.y; })
  .on("end", (e, d) => { if (!e.active) sim.alphaTarget(0); d.fx = d.fy = null; }));

// Tap to highlight a node and its neighbours; tap it again or the background to clear.
let picked = null;
const info = document.getElementById("info");
const neighbours = (d) => links.filter((l) => l.source === d || l.target === d).map((l) => (l.source === d ? l.target : l.source));
function highlight(d) {
  picked = picked === d ? null : d;
  const near = picked ? new Set([picked, ...neighbours(picked)]) : null;
  node.attr("opacity", (n) => (!near || near.has(n) ? 1 : 0.15));
  link.attr("opacity", (l) => (!picked || l.source === picked || l.target === picked ? 1 : 0.08));
  info.innerHTML = picked
    ? `<strong style="color:var(--strong)">${picked.id}</strong>${picked.note ? `<p>${picked.note}</p>` : ""}<ul>${neighbours(picked).map((n) => `<li>${n.id}</li>`).join("")}</ul>`
    : "Tap a node to see its connections.";
}
node.on("click", (e, d) => { e.stopPropagation(); highlight(d); });
svg.on("click", () => picked && highlight(picked));

document.getElementById("legend").innerHTML = groups
  .map((g) => `<span><span style="display:inline-block;width:10px;height:10px;border-radius:50%;background:${colour(g)}"></span> ${g}</span>`)
  .join("");
</script>
```

## Any width

Design for the laptop, and check the page still works at 390px.

- Use the width. Don't add your own `max-width` wrapper; the shell sets the page width. Put
  controls, legends and detail panels beside the visual with `<div class="split">visual + <aside></div>`
  (side by side from 1000px, stacked below). Comparisons can sit side by side on wide screens.
- Size canvas, SVG and charts from the container width (`clientWidth`) and, for tall visuals, the
  window height (`innerHeight`), never fixed pixels. Redraw on `resize`.
- Mermaid: `LR` suits a short linear pipeline (about 6 steps or fewer); long or branching diagrams
  use `TD`. Keep labels under about 5 words.
- Wrap a wide table in `<div style="overflow-x:auto">`.
- No hover-only information: anything shown on hover must also show on click/tap. Click targets
  at least 40px high.

## Shape of a good page

1. One sentence at the top saying what the visual shows and the main takeaway.
2. The visual.
3. Optional: a short "how to read this" line, a legend and controls.

Keep it to one idea per page. A follow-up question gets a new page, not an edit.

## Drawing on Sage

When the question is about something Melvin has watched or noted, ground the page
in his knowledge base first:

```bash
cd ~/myprojects/sage && ./venv/bin/python kb.py search "<query>"
```

Cite the sources it returns in a small footer list on the page.
