---
name: whiteboard
description: Build a visual, guided walkthrough of a code change (branch, PR, commit range, or uncommitted work) as a local HTML page with diagrams, call traces, structural diffs and a coverage check, plus a PR description. Use when the user says "whiteboard", asks to explain/visualize/walk through a diff, branch or PR, wants to understand a large (often agent-written) change without reading it line by line, or wants a PR description for a big change.
argument-hint: "[PR number | base..head | --worktree] [focus]"
---

# Whiteboard

You turn a diff into a page the user can *walk through* instead of read. The work splits cleanly:

- **`wb.py collect`** (mechanical): splits the diff into addressable hunks, maps each to the symbols it touches, and uses difftastic (tree-sitter structural diff) to flag formatting-only hunks.
- **You** (understanding): read the change and write `spec.json`, which holds the story, chapters, diagrams, traces, decisions and risks.
- **`wb.py render`** (mechanical): validates the spec against the real diff, renders `index.html` and `pr-description.md`, and opens the browser.

Code shown on the page always comes from git, never from your spec. Your job is the explanation and the pointers.

Script: `~/.claude/skills/whiteboard/wb.py` (stdlib Python; uses `difft` and `chromium` when present).

## 1. Collect

Pick the range from the user's request:

| Request | Command |
|---|---|
| current branch vs main | `wb.py collect` (base guessed: origin/HEAD, main, master) |
| uncommitted / agent's working tree | `wb.py collect --worktree` |
| explicit range | `wb.py collect --base A --head B` |
| GitHub PR N | `git fetch origin pull/N/head:pr-N`, base = `origin/$(gh pr view N --json baseRefName -q .baseRefName)`, then `--base … --head pr-N`. If the PR is already merged, the merge-base equals head; use `--base pr-N~<commits>` or the PR's base commit instead. |

Run from inside the repo (or pass `--repo`). Output goes to `~/.cache/whiteboard/<repo>/<head>/` unless you pass `--out`. The printed listing shows every hunk id (`path#N`), its +/- counts, the symbols it touches (`added`/`removed`/modified), and `NOISE` for formatting-only hunks. Binary changes, renames, mode changes and files with no textual patch get addressable metadata hunks too; these count toward coverage and are never noise. Their code cards show Git's change metadata rather than a textual diff.

## 2. Understand the change

Read the actual diff (`git diff <merge-base> <head> -- <paths>`), not just the listing. Read surrounding code where a hunk's meaning depends on callers or callees. For large diffs, go file group by file group. Source first, then tests, since tests tell you the intended contract.

Find out, and write down only what you verified:
- What the change does in behavior terms, and what *doesn't* change.
- The order a reader needs: what the new concept is, then where it's wired in, then what tests cover it. Use dependency order, not file order.
- The call paths a request or event takes through changed code.
- Which tests exercise new behavior and which only pin existing behavior. Agent-written PRs often have a lot of the second kind.
- Non-obvious decisions, behavior changes at the edges, and anything a human must judge.

## 3. Write `<out>/spec.json`

```jsonc
{
  "title": "Short name of the change",          // `backticks` render as code
  "risk": "low|medium|high",
  "summary": "markdown: what and why in 3-6 sentences; say explicitly if behavior does NOT change",
  "overview_diagrams": [ /* diagram objects, optional, e.g. a module map */ ],
  "chapters": [{
    "id": "slug",
    "title": "…", "summary": "one line", "risk": "low|medium|high",
    "narrative": "markdown, PLAIN LANGUAGE (see Voice). Link plain words to code with [the safety check](#hunk:path#N).",
    "diagrams": [{
      "title": "…",
      "mermaid": "flowchart LR\n  A[\"label\"] --> B[\"other\"]",
      "links": { "exact node or participant text": "path#N" },   // makes the node clickable
      "caption": "markdown, optional"
    }],
    "trace": { "title": "Call stack when …", "frames": [
      { "symbol": "Outer.call", "file": "src/x.py", "note": "markdown", "changed": true, "hunk": "src/x.py#3" }
    ]},
    "review_hints": ["markdown bullet", "…"],
    "under_the_hood": "markdown, collapsed by default: function names, mechanisms, edge-case detail",
    "hunk_notes": { "path#N": "one-line note shown above that hunk" },
    "hunks": ["path#N", "path#2-5", "whole/file.py"]           // the code behind this chapter
  }],
  "decisions": [{ "title": "…", "choice": "…", "why": "markdown", "alternatives": ["…"], "hunks": ["path#N"] }],
  "check": [{ "risk": "high", "text": "markdown: what a human should verify and why", "hunks": ["path#N"] }],
  "pr_description": "markdown PR body; end with the attribution line from the system prompt if one is given"
}
```

Hunk refs: `path#N` (one hunk), `path#N-M` (inclusive range; every hunk must exist), `path` (all hunks in a file, including metadata hunks). They work in `hunks` lists, in diagram `links`, and in markdown links of the form `[plain words](#hunk:path#N)`. `render` validates all three.

## Voice: write for someone who hasn't read the code

The reader knows what the project is for. They haven't read this code, and they don't want to; if the page reads like the code, they might as well open the diff. Every visible sentence should still make sense to them.

**Two layers.** `summary`, `narrative`, `review_hints`, `check` and `decisions` are the plain layer, and they're what the reader sees. Each chapter's `under_the_hood` is the technical layer, collapsed by default. Function names, regexes, hook names, data formats and line-level mechanics go there. A reader who stops at the plain layer should still know what changed, why, and what could go wrong.

In the plain layer:
- **Lead with the effect, then the reason.** Write "Plan mode only checks how a command *starts*, so anything chained after a harmless start still runs", not "`isSafeCommand` tests SAFE_PATTERNS with a `^` anchor".
- **Use everyday words for the things in the code.** "the safety check", "the settings file", "the session picker". To point at code, link those words: `[the safety check](#hunk:…)`. Don't drop a function name into the sentence.
- **Define a term the first time you can't avoid it**, in a short clause: "Ollama (runs AI models on your own computer)".
- **Use short sentences, and give one idea per paragraph.** Use lists for steps. Use tables only for side-by-side comparisons, such as "command → what it does → allowed?", and keep their cells in plain words too.
- **Make concrete examples beat abstractions.** "`ls && npm test` gets through" lands; "chained commands bypass the prefix check" doesn't. Commands and file names the reader would type are fine in backticks. Internal identifiers aren't.
- **Phrase risks as consequences for the reader:** "it won't start on your Linux machine", not "hard-coded darwin paths".
- **Write diagram labels as plain steps** ("Check the command", "Jump to that pane"), not function names. The node links still reach the code.

`render` prints a `plain language:` warning for any visible field with more than 5 code terms per 100 words. Treat each warning like an unexplained hunk: rewrite the field, or move the detail into `under_the_hood`.

### Authoring rules
- **Cover every non-noise hunk, including metadata hunks.** Explain binary assets, renamed paths, executable-bit changes and empty-file changes where applicable. Each one belongs to some chapter. `render` lists leftovers, and the page shows them in a red "Unexplained changes" section. Aim for zero, but never stretch a chapter's narrative to absorb a hunk you don't understand; leaving it unexplained is the honest result.
- **4 to 9 chapters** for a typical PR. Each one should have a title that states a claim ("Option now tracks explicit names") rather than a topic ("core.py changes").
- **One focused diagram per chapter at most**, with no more than about 15 nodes. Choose the type by what you're explaining:
  - `sequenceDiagram`: calls or messages across components. Use this for runtime flow.
  - `flowchart`: decisions, pipelines, data flow.
  - `classDiagram` / `erDiagram`: new or changed types and data models.
  - `stateDiagram-v2`: state machines and lifecycles.
  - `pie`: where the lines went (source vs tests vs docs), useful in the overview for large PRs.
- **Trace** is for "follow one concrete request through the stack". Mark the changed frames and link them to hunks. Its frames are code-level by nature, so use one only when the path matters to the reader; otherwise describe the flow in plain steps and put the call chain in `under_the_hood`.
- **Link diagram nodes** to the hunks that implement them. The link key must equal the node's rendered text exactly (case-insensitive), so keep linked labels on one line, with no `<br/>`.
- **Mermaid hygiene:** quote labels that contain punctuation (`A["foo(bar)"]`); don't use `end` as a node id; in sequence diagrams use `participant X as Display Name` and link on the display name.
- `check` is where the walkthrough earns trust. List behavior changes at the edges, risky assumptions, things the tests don't cover, and anything you're unsure of. Don't pad it.
- Explain in behavior terms ("now warns when…"). Don't paraphrase the code line by line, since the user can expand the code. Follow **Voice** above for everything outside `under_the_hood`.

## 4. Render and verify

```
wb.py render --out <out> --check
```

- Exit 1 means invalid hunk refs. Fix the spec and re-run.
- `plain language:` lines mean a visible field reads like code. Rewrite it, or move the detail into `under_the_hood`, before you finish.
- The check expands all code cards and verifies diff rendering as well as diagrams and diagram links.
- Exit 2 means verification failed: rendering errors, unmatched diagram-link labels, unavailable page libraries, or no Chromium-based browser. Read the reported reason, fix it and re-run; a missing browser is not successful verification.
- Markdown is sanitized before display. The page requires network access to load marked, DOMPurify, Mermaid and diff2html from their CDNs.
- Use `--shot` to also write `<out>/screenshot.png`. Look at it (Read the PNG) the first time, or after big layout changes.
- Drop `--no-open` on the final run so the page opens in the user's browser. Use `--no-open` while iterating.

## 5. Report back

Tell the user, briefly:
- The page path (`<out>/index.html`) and `pr-description.md`.
- The coverage line (chapters / noise / unexplained), and confirm there are no `plain language:` warnings left.
- The 1-3 most important `check` items, in one line each.
- On first use, mention the page's keys: `j`/`k` move between chapters, `/` jumps to any file or symbol, `u` goes back after a jump, and `?` lists the rest.

Don't paste the walkthrough into the terminal; the page is the deliverable.
