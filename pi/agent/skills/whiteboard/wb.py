#!/usr/bin/env python3
"""whiteboard: turn a git diff into a visual, guided walkthrough page.

  wb.py collect [--base REF] [--head REF | --worktree] [--repo DIR] [--out DIR]
      Parse the diff into addressable hunks, map each hunk to the symbols it
      touches, and use difftastic (structural, tree-sitter based) to flag hunks
      that are formatting-only noise. Writes <out>/hunks.json and prints a
      compact listing for the agent to plan the walkthrough from.

  wb.py render [--out DIR] [--no-open] [--check] [--shot]
      Validate <out>/spec.json against hunks.json (every hunk must be explained
      or flagged as noise; every reference must exist), then write index.html
      and pr-description.md and open the page. --check loads the page in
      headless Chromium and reports diagram/link errors; --shot also saves
      screenshot.png for visual review.

Stdlib only. difftastic (`difft`) is optional but strongly recommended.
"""

import argparse
import codecs
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
CACHE = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "whiteboard"

# Git's built-in hunk-header drivers, enabled without touching the repo.
ATTRIBUTES = """\
*.py diff=python
*.rb diff=ruby
*.go diff=golang
*.rs diff=rust
*.java diff=java
*.kt diff=kotlin
*.cs diff=csharp
*.c diff=cpp
*.h diff=cpp
*.cc diff=cpp
*.cpp diff=cpp
*.hpp diff=cpp
*.php diff=php
*.ex diff=elixir
*.exs diff=elixir
*.md diff=markdown
*.css diff=css
*.html diff=html
*.sh diff=bash
"""

# Definition lines across common languages; group "name" is the symbol.
DEF_PATTERNS = [
    r"(?:async\s+)?def\s+(?P<name>\w+)",
    r"class\s+(?P<name>\w+)",
    r"(?:export\s+)?(?:default\s+)?(?:async\s+)?function\*?\s+(?P<name>\w+)",
    r"(?:export\s+)?(?:abstract\s+)?class\s+(?P<name>\w+)",
    r"(?:export\s+)?(?:interface|type|enum)\s+(?P<name>\w+)",
    r"(?:export\s+)?(?:const|let|var)\s+(?P<name>\w+)\s*(?::[^=]+)?=\s*(?:async\s*)?(?:\([^)]*\)|\w+)\s*(?::[^=]+)?=>",
    r"func\s+(?:\([^)]*\)\s*)?(?P<name>\w+)",
    r"type\s+(?P<name>\w+)\s+(?:struct|interface)",
    r"(?:pub(?:\([^)]*\))?\s+)?(?:async\s+)?(?:unsafe\s+)?fn\s+(?P<name>\w+)",
    r"(?:pub(?:\([^)]*\))?\s+)?(?:struct|enum|trait|mod)\s+(?P<name>\w+)",
    r"impl(?:<[^>]*>)?\s+(?:[\w:<>]+\s+for\s+)?(?P<name>[\w:]+)",
    r"(?:(?:public|private|protected|internal|static|final|override|abstract|virtual|suspend)\s+)+[\w<>\[\],.?\s]*?\b(?P<name>\w+)\s*\([^;]*$",
    r"(?:fun|module)\s+(?P<name>[\w.]+)",
]
DEF_RE = re.compile(r"^(?P<indent>\s*)(?:" + "|".join(
    f"(?:{pat.replace('(?P<name>', f'(?P<n{i}>')})" for i, pat in enumerate(DEF_PATTERNS)) + ")")
NOT_SYMBOLS = {"if", "for", "while", "switch", "catch", "return", "new", "else", "elif"}


def run(cmd, cwd=None, env=None, check=True):
    r = subprocess.run(cmd, cwd=cwd, env=env, capture_output=True, text=True,
                       errors="replace")
    if check and r.returncode != 0:
        sys.exit(f"wb: {' '.join(cmd)} failed:\n{r.stderr}")
    return r.stdout


def git(repo, *args, check=True):
    return run(["git", "-C", str(repo), *args], check=check)


# ---------------------------------------------------------------- diff parsing

HUNK_RE = re.compile(r"^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@ ?(.*)$")


def decode_path(path):
    """Decode Git's C-quoted UTF-8 paths (including octal byte escapes)."""
    if path.startswith('"') and path.endswith('"'):
        return codecs.escape_decode(path[1:-1].encode("utf-8"))[0].decode("utf-8", errors="replace")
    return path


def parse_diff(text):
    files, f, h = [], None, None
    for line in text.splitlines():
        if line.startswith("diff --git "):
            m = re.match(r'diff --git ("(?:\\.|[^"\\])*"|a/.*?) ("(?:\\.|[^"\\])*"|b/.*)$', line)
            if not m:
                sys.exit(f"wb: could not parse diff paths: {line}")
            old_token, new_token = m.groups()
            # An unquoted path can itself contain " b/". For same-path
            # changes the two equal halves identify the actual separator.
            tokens = line.removeprefix("diff --git ")
            mid = (len(tokens) - 1) // 2
            if (tokens.startswith("a/") and tokens[mid:mid + 1] == " "
                    and tokens[mid + 1:] == "b/" + tokens[2:mid]):
                old_token, new_token = tokens[:mid], tokens[mid + 1:]
            f = {"old": decode_path(old_token).removeprefix("a/"),
                 "new": decode_path(new_token).removeprefix("b/"),
                 "status": "modified", "binary": False, "metadata": [], "hunks": []}
            files.append(f)
            h = None
            continue
        if f is None:
            continue
        if h is None or line[:1] not in (" ", "+", "-", "\\"):
            if line.startswith(("old mode ", "new mode ", "new file mode ", "deleted file mode ",
                                "rename from ", "rename to ", "similarity index ", "Binary files ")):
                f["metadata"].append(line)
            if line.startswith("new file mode"):
                f["status"] = "added"
            elif line.startswith("deleted file mode"):
                f["status"] = "deleted"
            elif line.startswith("rename from "):
                f["status"] = "renamed"
                f["old"] = decode_path(line.removeprefix("rename from "))
            elif line.startswith("rename to "):
                f["new"] = decode_path(line.removeprefix("rename to "))
            elif line.startswith("Binary files"):
                f["binary"] = True
            elif line.startswith("--- ") and line[4:] != "/dev/null":
                f["old"] = decode_path(line[4:].split("\t", 1)[0]).removeprefix("a/")
            elif line.startswith("+++ ") and line[4:] != "/dev/null":
                f["new"] = decode_path(line[4:].split("\t", 1)[0]).removeprefix("b/")
            m = HUNK_RE.match(line)
            if m:
                h = {"old_start": int(m.group(1)), "old_len": int(m.group(2) or 1),
                     "new_start": int(m.group(3)), "new_len": int(m.group(4) or 1),
                     "context": m.group(5).strip(), "lines": []}
                f["hunks"].append(h)
            continue
        h["lines"].append(line)
    return files


SPLIT_MIN = 40  # hunks with more changed lines than this get split per definition


def split_hunk(h, new_owner):
    """Split a large hunk where a new top-level definition starts, so each
    function/test/class is separately addressable. Each piece is a valid hunk."""
    if sum(1 for l in h["lines"] if l[:1] in "+-") <= SPLIT_MIN:
        return [h]
    cuts, n = [], h["new_start"]
    lines = h["lines"]
    for i, line in enumerate(lines):
        tag = line[:1]
        if tag in (" ", "+"):
            owner = new_owner[n - 1] if 0 < n <= len(new_owner) else None
            prev = new_owner[n - 2] if 1 < n <= len(new_owner) + 1 else None
            body = line[1:]
            is_def = DEF_RE.match(body) and owner and "." not in owner and owner != prev
            if is_def and i > 0:
                # Move the cut above a (possibly multi-line) decorator block:
                # the contiguous non-blank lines above the def, if the topmost
                # one is a decorator at the def's indentation.
                j, indent = i, len(body) - len(body.lstrip())
                while j > 0 and lines[j - 1][:1] != "-" and lines[j - 1][1:].strip():
                    j -= 1
                top = lines[j][1:] if j < i else ""
                if j < i and top.lstrip().startswith("@") and len(top) - len(top.lstrip()) == indent:
                    cuts.append(j)
                else:
                    cuts.append(i)
            n += 1
    cuts = sorted({c for c in cuts if c > 0})
    if not cuts:
        return [h]
    pieces, o, n, start = [], h["old_start"], h["new_start"], 0
    for end in cuts + [len(lines)]:
        seg = lines[start:end]
        o_len = sum(1 for l in seg if l[:1] in " -")
        n_len = sum(1 for l in seg if l[:1] in " +")
        if any(l[:1] in "+-" for l in seg):
            pieces.append({"old_start": o if o_len else max(o - 1, 0), "old_len": o_len,
                           "new_start": n if n_len else max(n - 1, 0), "new_len": n_len,
                           "context": h["context"], "lines": seg})
        o += o_len; n += n_len; start = end
    return pieces


def prune_nested(symbols):
    """Drop symbols nested inside one that is itself newly added/removed."""
    whole = {s["name"] for s in symbols if s["kind"] != "modified"}
    return [s for s in symbols
            if not any(s["name"].startswith(w + ".") for w in whole)]


def hunk_changes(h):
    """Line numbers (1-based) of removed old lines and added new lines."""
    o, n, old, new = h["old_start"], h["new_start"], [], []
    for line in h["lines"]:
        tag = line[:1]
        if tag == " ":
            o += 1; n += 1
        elif tag == "-":
            old.append(o); o += 1
        elif tag == "+":
            new.append(n); n += 1
    return old, new


# ------------------------------------------------------------- symbol mapping

def symbol_table(lines):
    """For each line index, the qualified name of its innermost definition."""
    owner, stack = [None] * len(lines), []  # stack of (indent, name)
    for i, line in enumerate(lines):
        if not line.strip():
            owner[i] = stack[-1][1] if stack else None
            continue
        indent = len(line) - len(line.lstrip())
        stripped = line.strip()
        closes_only = stripped in ("}", "};", "})", "end", ")")
        while stack and (indent < stack[-1][0] or (indent == stack[-1][0] and not closes_only)):
            stack.pop()
        m = DEF_RE.match(line)
        name = next((v for k, v in m.groupdict().items() if k != "indent" and v), None) if m else None
        if name and name not in NOT_SYMBOLS:
            qual = f"{stack[-1][1]}.{name}" if stack else name
            stack.append((indent, qual))
        owner[i] = stack[-1][1] if stack else None
    return owner


def symbols_for(owner, line_numbers):
    return {owner[n - 1] or "(top level)" for n in line_numbers if 0 < n <= len(owner)}


# -------------------------------------------------------- difftastic analysis

def difft_semantic_lines(old_text, new_text, name):
    """Return (old_lines, new_lines, language) that difftastic considers changed,
    or None if difft is unavailable / failed."""
    if not shutil.which("difft"):
        return None
    with tempfile.TemporaryDirectory() as d:
        a, b = Path(d, "a"), Path(d, "b")
        a.mkdir(); b.mkdir()
        (a / name).write_text(old_text)
        (b / name).write_text(new_text)
        env = {**os.environ, "DFT_UNSTABLE": "yes", "DFT_DISPLAY": "json", "DFT_COLOR": "never"}
        try:
            r = subprocess.run(["difft", str(a / name), str(b / name)], env=env,
                               capture_output=True, text=True, timeout=60)
            data = json.loads(r.stdout)
        except Exception:
            return None
    old, new = set(), set()
    for chunk in data.get("chunks", []):
        for entry in chunk:
            if entry.get("lhs"):
                old.add(entry["lhs"]["line_number"] + 1)
            if entry.get("rhs"):
                new.add(entry["rhs"]["line_number"] + 1)
    return old, new, data.get("language")


# -------------------------------------------------------------------- collect

def default_base(repo):
    for ref in ("origin/HEAD", "origin/main", "origin/master", "main", "master"):
        if git(repo, "rev-parse", "--verify", "-q", ref, check=False).strip():
            return ref
    sys.exit("wb: could not guess a base branch; pass --base")


def slug(s):
    return re.sub(r"[^\w.-]+", "-", s).strip("-") or "head"


def cmd_collect(a):
    repo = Path(git(a.repo, "rev-parse", "--show-toplevel").strip())
    base = a.base or default_base(repo)
    head = "WORKTREE" if a.worktree else (a.head or "HEAD")
    mb = git(repo, "merge-base", base, "HEAD" if a.worktree else head).strip()
    head_label = head if a.worktree else git(repo, "rev-parse", "--abbrev-ref", head, check=False).strip()
    if head_label in ("HEAD", ""):
        head_label = git(repo, "rev-parse", "--short", head).strip()
    out = Path(a.out).resolve() if a.out else CACHE / repo.name / slug(head_label + ("-wt" if a.worktree else ""))
    out.mkdir(parents=True, exist_ok=True)

    with tempfile.NamedTemporaryFile("w", suffix=".gitattributes", delete=False) as af:
        af.write(ATTRIBUTES)
    diff_args = ["-c", f"core.attributesFile={af.name}", "diff", "-M", "--no-color",
                 "--no-ext-diff", "--src-prefix=a/", "--dst-prefix=b/", "-U3", mb] + ([] if a.worktree else [head])
    text = git(repo, *diff_args)
    if a.worktree:  # include untracked files
        for path in git(repo, "ls-files", "--others", "--exclude-standard", "-z").split("\0"):
            if not path or (repo / path).resolve().is_relative_to(out):
                continue
            text += "\n" + run(["git", "-C", str(repo), "diff", "--no-index", "--no-color",
                                "--src-prefix=a/", "--dst-prefix=b/", "/dev/null", path], check=False)
    os.unlink(af.name)

    def read(rev, path):
        if rev == "WORKTREE":
            p = repo / path
            return p.read_text(errors="replace") if p.is_file() else ""
        return git(repo, "show", f"{rev}:{path}", check=False)

    files_out, hunks_out = [], []
    for f in parse_diff(text):
        path = f["new"] if f["status"] != "deleted" else f["old"]
        old_text = "" if f["status"] == "added" else read(mb, f["old"])
        new_text = "" if f["status"] == "deleted" else read(head, f["new"])
        old_owner = symbol_table(old_text.splitlines())
        new_owner = symbol_table(new_text.splitlines())
        old_defs, new_defs = set(filter(None, old_owner)), set(filter(None, new_owner))
        sem = None
        if f["status"] in ("modified", "renamed") and not f["binary"]:
            sem = difft_semantic_lines(old_text, new_text, Path(path).name)
        language = sem[2] if sem else None
        file_hunks = []
        pieces = [x for h in f["hunks"] for x in split_hunk(h, new_owner)]
        for i, h in enumerate(pieces, 1):
            old_ch, new_ch = hunk_changes(h)
            touched = symbols_for(old_owner, old_ch) | symbols_for(new_owner, new_ch)
            symbols = []
            for s in sorted(touched):
                kind = "modified"
                if s != "(top level)":
                    if s in new_defs and s not in old_defs:
                        kind = "added"
                    elif s in old_defs and s not in new_defs:
                        kind = "removed"
                symbols.append({"name": s, "kind": kind})
            symbols = prune_nested(symbols)
            if len(symbols) > 1:
                symbols = [s for s in symbols if s["name"] != "(top level)"]
            noise = bool(sem) and not (set(old_ch) & sem[0]) and not (set(new_ch) & sem[1])
            hid = f"{path}#{i}"
            hunk = {
                "id": hid, "file": path, "index": i,
                "old_path": f["old"], "new_path": f["new"],
                "header": f"@@ -{h['old_start']},{h['old_len']} +{h['new_start']},{h['new_len']} @@ {h['context']}".rstrip(),
                "new_start": h["new_start"], "old_start": h["old_start"],
                "added": len(new_ch), "removed": len(old_ch),
                "symbols": symbols, "noise": noise,
                "patch": "\n".join(h["lines"]),
            }
            file_hunks.append(hunk)
        # Metadata must participate in coverage, even when Git emits no text hunks.
        if not file_hunks or f["status"] == "renamed" or any(
                line.startswith(("old mode ", "new mode ")) for line in f["metadata"]):
            index = len(file_hunks) + 1
            change = "\n".join(f["metadata"]) or f"{f['status']}: {path} (no textual patch)"
            file_hunks.append({
                "id": f"{path}#{index}", "file": path, "index": index,
                "old_path": f["old"], "new_path": f["new"], "type": "metadata",
                "change": change, "header": "", "patch": "",
                "new_start": 0, "old_start": 0, "added": 0, "removed": 0,
                "symbols": [], "noise": False,
            })
        hunks_out += file_hunks
        files_out.append({
            "path": path, "old_path": f["old"], "status": f["status"], "binary": f["binary"],
            "language": language, "difftastic": sem is not None,
            "added": sum(h["added"] for h in file_hunks),
            "removed": sum(h["removed"] for h in file_hunks),
            "hunks": [h["id"] for h in file_hunks],
        })

    meta = {
        "repo": str(repo), "repo_name": repo.name, "base": base, "merge_base": mb,
        "head": head_label, "worktree": a.worktree,
        "head_sha": None if a.worktree else git(repo, "rev-parse", head).strip(),
        "commits": [] if a.worktree else git(repo, "log", "--format=%h %s", f"{mb}..{head}").splitlines(),
        "difftastic": bool(shutil.which("difft")),
    }
    (out / "hunks.json").write_text(json.dumps({"meta": meta, "files": files_out, "hunks": hunks_out}, indent=1))

    # Compact listing for the agent.
    total_a = sum(f["added"] for f in files_out)
    total_r = sum(f["removed"] for f in files_out)
    print(f"out: {out}")
    print(f"diff: {base} ({mb[:9]}) .. {head_label}   files={len(files_out)} hunks={len(hunks_out)} +{total_a} -{total_r}")
    if not meta["difftastic"]:
        print("note: difft not found, formatting-noise detection disabled")
    for c in meta["commits"][:30]:
        print(f"commit: {c}")
    for f in files_out:
        print(f"\n{f['path']}  [{f['status']}{', ' + f['language'] if f['language'] else ''}]  +{f['added']} -{f['removed']}")
        for hid in f["hunks"]:
            h = next(x for x in hunks_out if x["id"] == hid)
            syms = ", ".join(f"{s['name']}{'' if s['kind'] == 'modified' else ' (' + s['kind'] + ')'}" for s in h["symbols"])
            marker = "METADATA " if h.get("type") == "metadata" else "NOISE " if h["noise"] else ""
            print(f"  {hid:<40} +{h['added']:<4} -{h['removed']:<4} {marker}{syms}")


# --------------------------------------------------------------------- render

def expand_ref(ref, by_id, by_file):
    if ref in by_id:
        return [ref]
    if ref in by_file:
        return by_file[ref]
    m = re.match(r"^(.*)#(\d+)-(\d+)$", ref, re.S)  # path#2-5
    if m and m.group(1) in by_file:
        start, end = int(m.group(2)), int(m.group(3))
        if start > end or end - start + 1 > len(by_file[m.group(1)]):
            return None
        ids = [f"{m.group(1)}#{i}" for i in range(start, end + 1)]
        return ids if all(r in by_id for r in ids) else None
    return None


CODE_TERM = re.compile(r"(?<![`\w])(?:[a-z]+_[a-z_]+|[a-z]+[A-Z]\w*|\w+\(\))(?![`\w])")
JARGON_LIMIT = 5  # code terms per 100 words in the plain-language layer


def code_density(text):
    """Code terms (backtick spans and bare identifiers) per 100 words."""
    text = re.sub(r"\]\(#hunk:[^)]*\)", "]", text or "")  # link targets aren't prose
    spans = re.findall(r"`[^`]+`", text)
    rest = re.sub(r"`[^`]+`", " ", text)
    words = len(re.findall(r"[A-Za-z']+", rest)) + len(spans)
    return (len(spans) + len(CODE_TERM.findall(rest))) * 100 / max(words, 1), words


def plain_language_report(spec):
    """Fields of the visible (non under-the-hood) layer that read like code."""
    fields = [("summary", spec.get("summary", ""))]
    for ch in spec.get("chapters", []):
        fields.append((f"chapter {ch['id']!r}", ch.get("narrative", "")))
        fields.append((f"chapter {ch['id']!r} hints", " ".join(ch.get("review_hints", []))))
    fields += [(f"check item {i + 1}", c.get("text", "")) for i, c in enumerate(spec.get("check", []))]
    for where, text in fields:
        d, words = code_density(text)
        if words >= 25 and d > JARGON_LIMIT:
            yield where, round(d, 1), words


def cmd_render(a):
    out = Path(a.out).resolve() if a.out else None
    if out is None:
        candidates = sorted(CACHE.glob("*/*/spec.json"), key=lambda p: p.stat().st_mtime)
        if not candidates:
            sys.exit("wb: no spec.json found; pass --out")
        out = candidates[-1].parent
    data = json.loads((out / "hunks.json").read_text())
    try:
        spec = json.loads((out / "spec.json").read_text())
    except json.JSONDecodeError as e:
        sys.exit(f"wb: spec.json is not valid JSON: {e}")

    by_id = {h["id"]: h for h in data["hunks"]}
    by_file = {}
    for h in data["hunks"]:
        by_file.setdefault(h["file"], []).append(h["id"])

    errors, covered = [], set()

    def resolve(ref, where):
        ids = expand_ref(ref, by_id, by_file)
        if ids is None:
            errors.append(f"{where}: unknown hunk reference {ref!r}")
            return []
        return ids

    for ci, ch in enumerate(spec.get("chapters", [])):
        ch.setdefault("id", f"ch{ci + 1}")
        where = f"chapter {ch['id']!r}"
        ch["hunks"] = [i for r in ch.get("hunks", []) for i in resolve(r, where)]
        covered.update(ch["hunks"])
        for d in ch.get("diagrams", []):
            d["links"] = {k: (resolve(v, f"{where} diagram link {k!r}") or [None])[0]
                          for k, v in d.get("links", {}).items()}
        for fr in (ch.get("trace") or {}).get("frames", []):
            if fr.get("hunk"):
                fr["hunk"] = (resolve(fr["hunk"], f"{where} trace frame") or [None])[0]
    for sec in ("decisions", "check"):
        for item in spec.get(sec, []):
            item["hunks"] = [i for r in item.get("hunks", []) for i in resolve(r, sec)]
    for d in spec.get("overview_diagrams", []):
        d["links"] = {k: (resolve(v, f"overview diagram link {k!r}") or [None])[0]
                      for k, v in d.get("links", {}).items()}

    # [plain words](#hunk:REF) links inside any markdown field must resolve too
    def md_fields():
        yield "summary", spec.get("summary", "")
        for ch in spec.get("chapters", []):
            for k in ("narrative", "risk_note", "under_the_hood"):
                yield f"chapter {ch['id']!r} {k}", ch.get(k, "")
            for x in ch.get("review_hints", []):
                yield f"chapter {ch['id']!r} hint", x
        for sec in ("decisions", "check"):
            for item in spec.get(sec, []):
                yield sec, " ".join(str(item.get(k, "")) for k in ("why", "text", "choice"))
    for where, text in md_fields():
        for ref in re.findall(r"\(#hunk:([^)\s]+)\)", text or ""):
            resolve(ref, f"{where} link")

    noise = [h["id"] for h in data["hunks"] if h["noise"] and h["id"] not in covered]
    unexplained = [h["id"] for h in data["hunks"] if not h["noise"] and h["id"] not in covered]

    if errors:
        print("wb: spec errors (fix these and re-run render):", *errors, sep="\n  ", file=sys.stderr)
        sys.exit(1)

    page = {"meta": data["meta"], "files": data["files"], "hunks": by_id, "spec": spec,
            "noise": noise, "unexplained": unexplained}
    template = (HERE / "template.html").read_text()
    # Escape every '<': HTML script parsing also treats '<!-- <script>' specially.
    blob = json.dumps(page).replace("<", "\\u003c")
    title = spec.get("title", "Whiteboard")
    html = template.replace("__TITLE__", title.replace("<", "&lt;")).replace("/*__DATA__*/null", blob)
    (out / "index.html").write_text(html)

    pr = spec.get("pr_description")
    if pr:
        (out / "pr-description.md").write_text(pr.strip() + "\n")

    print(f"page: {out / 'index.html'}")
    if pr:
        print(f"pr description: {out / 'pr-description.md'}")
    for where, n, words in plain_language_report(spec):
        print(f"plain language: {where} has {n} code terms per 100 words (aim for 5 or fewer; "
              f"move detail to under_the_hood)")
    print(f"coverage: {len(covered)}/{len(data['hunks'])} hunks in chapters, "
          f"{len(noise)} formatting noise, {len(unexplained)} unexplained")
    if unexplained:
        print("unexplained hunks (assign them to a chapter, or the page shows them in red):")
        for u in unexplained:
            print(f"  {u}")
    failed = False
    if a.check or a.shot:
        failed = check_page(out, a.shot)
    if failed:
        sys.exit(2)
    if not a.no_open:
        opener = shutil.which("xdg-open") or shutil.which("open")
        if opener:
            subprocess.Popen([opener, str(out / "index.html")], stdout=subprocess.DEVNULL,
                             stderr=subprocess.DEVNULL, start_new_session=True)


def find_browser():
    for b in ("chromium", "chromium-browser", "google-chrome-stable", "google-chrome", "brave"):
        if shutil.which(b):
            return shutil.which(b)
    return None


def check_page(out, shot):
    """Render the page headlessly; report errors the page recorded. Returns True on failure."""
    b = find_browser()
    if not b:
        print("check: NOT VERIFIED — no Chromium-based browser found")
        return True
    url = (out / "index.html").as_uri() + "#expand"
    with tempfile.TemporaryDirectory() as prof:
        base = [b, "--headless=new", "--disable-gpu", f"--user-data-dir={prof}",
                "--virtual-time-budget=25000", "--hide-scrollbars"]
        for _ in range(2):  # one retry: CDN fetches occasionally fail in headless runs
            r = subprocess.run(base + ["--dump-dom", url], capture_output=True, text=True, timeout=180)
            if "not loaded" not in r.stdout:
                break
        if shot:
            subprocess.run(base + ["--window-size=1400,5000", f"--screenshot={out / 'screenshot.png'}", url],
                           capture_output=True, text=True, timeout=180)
            print(f"screenshot: {out / 'screenshot.png'}")
    m = re.search(r'<script type="application/json" id="wb-status">(.*?)</script>', r.stdout, re.S)
    if not m:
        print("check: page did not finish rendering (CDN unreachable or script error)")
        return True
    st = json.loads(m.group(1))
    print(f"check: {st['diagrams']} diagram(s) rendered, {len(st['errors'])} error(s)")
    for e in st["errors"]:
        print(f"  {e}")
    return bool(st["errors"])


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)
    c = sub.add_parser("collect")
    c.add_argument("--repo", default=".")
    c.add_argument("--base")
    c.add_argument("--head")
    c.add_argument("--worktree", action="store_true", help="diff merge-base against uncommitted working tree")
    c.add_argument("--out")
    r = sub.add_parser("render")
    r.add_argument("--out")
    r.add_argument("--no-open", action="store_true")
    r.add_argument("--check", action="store_true", help="verify diagrams render in headless Chromium")
    r.add_argument("--shot", action="store_true", help="--check plus save screenshot.png")
    a = p.parse_args()
    {"collect": cmd_collect, "render": cmd_render}[a.cmd](a)


if __name__ == "__main__":
    main()
