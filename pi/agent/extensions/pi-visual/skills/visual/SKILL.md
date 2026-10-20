---
name: visual
description: Page contract for render_ui. Read before publishing a visual answer (concept map, process, comparison, chart, interactive explainer, 3D scene) so the page makes full use of a laptop screen, loads its libraries and fits the One Dark shell.
---

# Visual answers with render_ui

Melvin reads pages on a laptop or desktop, rarely on a phone. Design for a 1280–1600px wide
screen. On a phone the page only has to work: wide diagrams and tables may scroll sideways.

## Pick the form

| The answer is... | Draw | Library |
|---|---|---|
| A hierarchy, or under ~12 nodes with few cross-links | Node-link map | Mermaid `flowchart` |
| A network where exploring topology and cross-links is the point | Force-directed graph | D3 force (template below) |
| Layers or components of a system or platform | Layered/component diagram with explicit connections | Mermaid `flowchart` with `subgraph`, or inline SVG |
| Steps, a pipeline, a protocol | Flow or sequence diagram | Mermaid |
| Options against criteria | Table with coloured verdicts, or a small chart | none, or Chart.js |
| Numbers over time or by category | Line or bar chart | Chart.js or D3 |
| A mechanism you understand by changing an input | Sliders driving an SVG or canvas | plain JS |
| Something spatial | 3D scene with orbit controls | Three.js |
| Algorithm behaviour | Step-through animation with play/step buttons | plain JS + SVG |

Prefer the lightest option. A table or an inline SVG beats a library when it does the job.
Choose by the question, not node count: when categories explain the system, let categories lead;
use a force graph when exploring connections is the task. When relationships matter, draw explicit
connectors rather than relying on rows of cards and arrow characters.

## Contract

- Write scripts readable and indented, one statement per line, never minified. Minified code drops
  brackets, and a single syntax error leaves the page blank.
- Inline all data; the page cannot fetch. Load libraries with these snippets:
  - Mermaid:
    ```html
    <script type="module">
    import mermaid from "https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs";
    const css = (v) => getComputedStyle(document.documentElement).getPropertyValue(v).trim();
    mermaid.initialize({
      startOnLoad: false,
      deterministicIds: true,
      theme: "base",
      themeVariables: {
        background: css("--bg"),
        primaryColor: css("--panel"),
        primaryBorderColor: css("--soft"),
        primaryTextColor: css("--fg"),
        secondaryColor: css("--panel"),
        tertiaryColor: css("--bg"),
        lineColor: css("--soft"),
        textColor: css("--fg"),
        clusterBkg: css("--bg"),
        clusterBorder: css("--soft"),
        edgeLabelBackground: css("--bg"),
        actorBkg: css("--panel"),
        actorBorder: css("--soft"),
        actorTextColor: css("--fg"),
        actorLineColor: css("--soft"),
        signalColor: css("--fg"),
        signalTextColor: css("--fg"),
        labelBoxBkgColor: css("--panel"),
        labelBoxBorderColor: css("--soft"),
        labelTextColor: css("--fg"),
        loopTextColor: css("--fg"),
        noteBkgColor: css("--panel"),
        noteBorderColor: css("--soft"),
        noteTextColor: css("--fg"),
        activationBkgColor: css("--panel"),
        activationBorderColor: css("--soft"),
      },
    });
    await mermaid.run();
    for (const svg of document.querySelectorAll(".mermaid svg")) {
      svg.closest(".mermaid").style.overflow = "visible";
      svg.style.width = `${svg.viewBox.baseVal.width}px`;
      svg.style.maxWidth = "none";
      svg.style.height = "auto";
    }
    </script>
    ```
    - Wrap each `.mermaid` in a keyboard-scrollable region, for example
      `<div tabindex="0" role="region" aria-label="System diagram, scroll horizontally" style="overflow-x:auto">…</div>`.
      The snippet preserves the SVG's intrinsic size instead of shrinking its labels to fit,
      and removes inner `.mermaid` scrolling so the labelled outer region owns overflow.
    - `deterministicIds` keeps SVG ids unique when a page has several diagrams; without it two
      diagrams can get the same id and one renders on top of the other.
    - In Mermaid label, message and note text, never use a bare `;` (it ends the statement, so the
      diagram fails with "Syntax error in text") or `#`. Use a comma, or `#59;` / `#35;` for a literal one.
  - D3: `<script src="https://cdn.jsdelivr.net/npm/d3@7"></script>`
  - Chart.js: `<script src="https://cdn.jsdelivr.net/npm/chart.js@4"></script>`
  - Three.js: `<script type="importmap">{"imports":{"three":"https://cdn.jsdelivr.net/npm/three@0.170.0/build/three.module.js","three/addons/":"https://cdn.jsdelivr.net/npm/three@0.170.0/examples/jsm/"}}</script>`
- Use the theme tokens instead of raw colours: `var(--fg)`, `--strong`, `--soft`, `--muted`, `--panel`, `--line`, `--blue`, `--green`, `--yellow`, `--red`, `--purple`, `--cyan`, `--orange`. For libraries that need hex values, read them with `getComputedStyle(document.documentElement).getPropertyValue("--blue")`.

Use `--soft` for secondary body text, captions and metadata. Reserve `--muted` for non-text
decoration; it does not have readable text contrast. `--line` is for subtle decorative borders;
use `--soft` for diagram edges that must be distinguishable.

## D3 force graph template

Replace `nodes`, `links` and the intro line; keep the interaction and sizing behaviour. Don't shrink nodes or labels and don't
add zoom-to-fit (a reset may go back to `d3.zoomIdentity`, no smaller). Labels at most ~20
characters, with longer names and detail in a `note` field shown in `#info`. At most 7 groups,
one per colour.

Enable `clusterByGroup` only when group membership is meaningful: it pulls groups toward separate
anchors, not discovered communities.
For dense graphs (roughly 40+ links is a starting heuristic), default to selected-node edges and
keep the “Show all connections” control. If the result still needs extensive exploration just to
understand the categories, choose a layered diagram instead.

```html
<p>Click a node or use the selector to inspect its neighbours; drag to move, pinch or scroll to zoom.</p>
<label>Inspect a node <select id="node-picker"><option value="">All nodes</option></select></label>
<label><input id="all-links" type="checkbox"> Show all connections</label>
<div class="split">
  <div id="graph" style="border:1px solid var(--line);border-radius:8px;background:var(--panel);touch-action:none"></div>
  <aside>
    <div id="legend" style="display:flex;flex-wrap:wrap;gap:8px 12px;font-size:.85rem"></div>
    <div id="info" aria-live="polite" style="margin-top:12px;color:var(--soft)">Click a node to see its connections.</div>
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
const clusterByGroup = false;
const picker = document.getElementById("node-picker");
for (const d of nodes) picker.add(new Option(d.id, d.id));
const allLinks = document.getElementById("all-links");
allLinks.checked = links.length <= 40;
const colour = d3.scaleOrdinal(groups, ["--blue", "--green", "--purple", "--yellow", "--cyan", "--red", "--orange"].map(css));
const box = document.getElementById("graph");
const svg = d3.select(box).append("svg").style("display", "block");
const view = svg.append("g");
svg.call(d3.zoom().scaleExtent([0.4, 4]).on("zoom", (e) => view.attr("transform", e.transform)));

const link = view.append("g").attr("stroke", css("--soft")).attr("stroke-width", 1.5)
  .selectAll("line").data(links).join("line");
const node = view.append("g").selectAll("g").data(nodes).join("g").style("cursor", "pointer");
node.append("circle").attr("r", 12).attr("fill", (d) => colour(d.group)); // r 12 + label ≈ 40px tap target
node.append("text").text((d) => d.id).attr("x", 16).attr("y", 4)
  .attr("fill", css("--strong")).attr("font-size", 14).attr("paint-order", "stroke")
  .attr("stroke", css("--panel")).attr("stroke-width", 3);

const sim = d3.forceSimulation(nodes)
  .force("link", d3.forceLink(links).id((d) => d.id))
  .force("charge", d3.forceManyBody().strength(nodes.length > 15 ? -480 : -320))
  .force("collide", d3.forceCollide(34))
  .on("tick", () => {
    // Keep every node and its label inside the box (label ≈ 8px per character at 14px).
    for (const d of nodes) {
      d.x = Math.max(14, Math.min(w - 20 - 8 * d.id.length, d.x));
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
  const angle = (d) => 2 * Math.PI * groups.indexOf(d.group) / groups.length;
  const clustered = clusterByGroup && groups.length > 1;
  sim.force("center", d3.forceCenter(w / 2, h / 2))
    .force("x", d3.forceX((d) => w / 2 + (clustered ? w * 0.28 * Math.cos(angle(d)) : 0)).strength(clustered ? 0.2 : 0.06))
    .force("y", d3.forceY((d) => h / 2 + (clustered ? h * 0.28 * Math.sin(angle(d)) : 0)).strength(clustered ? 0.2 : 0.06));
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
  picked = d;
  picker.value = picked ? picked.id : "";
  const near = picked ? new Set([picked, ...neighbours(picked)]) : null;
  node.attr("opacity", (n) => (!near || near.has(n) ? 1 : 0.15));
  link.attr("opacity", (l) => {
    const connected = picked && (l.source === picked || l.target === picked);
    return allLinks.checked ? (!picked || connected ? 1 : 0.08) : (connected ? 1 : 0);
  });
  info.innerHTML = picked
    ? `<strong style="color:var(--strong)">${picked.id}</strong>${picked.note ? `<p>${picked.note}</p>` : ""}<ul>${neighbours(picked).map((n) => `<li>${n.id}</li>`).join("")}</ul>`
    : "Click a node to see its connections.";
}
node.on("click", (e, d) => { e.stopPropagation(); highlight(picked === d ? null : d); });
svg.on("click", () => highlight(null));
picker.addEventListener("change", () => highlight(nodes.find((d) => d.id === picker.value) ?? null));
allLinks.addEventListener("change", () => highlight(picked));
highlight(null);

document.getElementById("legend").innerHTML = groups
  .map((g) => `<span><span style="display:inline-block;width:10px;height:10px;border-radius:50%;background:${colour(g)}"></span> ${g}</span>`)
  .join("");
</script>
```

## Layout

- Use the width. Don't add your own `max-width` wrapper; the shell sets the page width. Put
  controls, legends and detail panels beside the visual with `<div class="split">visual + <aside></div>`
  (side by side from 1000px, stacked below). Comparisons, annotations and multi-column sections
  can sit side by side; let them stack below 1000px.
- Size canvas, SVG and charts from the container width (`clientWidth`) and, for tall visuals, the
  window height (`innerHeight`). Redraw on `resize`. Don't scale a diagram down until its labels
  are unreadable; keep its natural size in a scroll region instead.
- Draw one connected diagram rather than several small fragments. The relationships the
  explanation depends on belong in the picture, not only in the prose. Give a large diagram the
  full row.
- In hand-drawn SVG, route lines clear of labels and put captions outside the diagram.
- Mermaid direction follows the shape of the content: `LR` with `subgraph`s for systems,
  architectures and pipelines; `TD` for hierarchies and deep trees. Labels up to about 8 words.
- Tables: use real tables for comparisons, with readable column widths. Wrap a wide one in
  `<div tabindex="0" role="region" aria-label="…" style="overflow-x:auto">` so it scrolls on a
  phone; never shrink body text to make columns fit.
- No hover-only information: anything shown on hover must also show on click. Interactive
  diagrams need a keyboard path too: native controls (such as the node selector above), visible
  focus indicators and text details.

## Shape of a good page

The shell already shows the title as an H1. Start with the takeaway, not another hero heading.

1. One sentence at the top saying what the visual shows and the main takeaway.
2. The visual.
3. Optional: a short "how to read this" line, a legend and controls.

Answer one question per page; sections and depth toggles are fine when each earns its place.
A follow-up question gets a new page, not an edit. Optionally pass `summary` to `render_ui`: a
plain-text, one-sentence takeaway (at most 240 characters) shown in the index.

Link authoritative sources for technical explanations and operational caveats so readers can
verify the claims; distinguish simplified diagrams from exact execution traces.
