"""Focused whiteboard regressions; run with make check-whiteboard (Python + Node)."""

import argparse
import contextlib
import html.parser
import importlib.util
import io
import json
from pathlib import Path
import re
import subprocess
import tempfile
import unittest

HERE = Path(__file__).resolve().parent
MODULE = importlib.util.spec_from_file_location("wb", HERE / "wb.py")
wb = importlib.util.module_from_spec(MODULE)
MODULE.loader.exec_module(wb)


class CopyButtonParser(html.parser.HTMLParser):
    def __init__(self):
        super().__init__()
        self.command = None

    def handle_starttag(self, tag, attrs):
        if tag == "button":
            self.command = dict(attrs).get("data-copy", self.command)


class EditorCommandTests(unittest.TestCase):
    def test_copied_command_preserves_literal_paths(self):
        template = (HERE / "template.html").read_text()
        helpers = "\n".join(line for line in template.splitlines()
                            if line.startswith(("const shellQuote =", "const editorCommand =")))
        card = re.search(r"function hunkCard\(id, note\) \{.*?^\}", template, re.M | re.S).group()
        # Exercise the real card, including HTML escaping and attribute decoding.
        script = """
const input = JSON.parse(process.argv[1]);
const M = {repo: input.repo};
const H = {test: {file: input.file, symbols: [], added: 1, removed: 0, new_start: 7, index: 1}};
const hunkChapter = {}, hid = s => s;
let hunkInstance = 0;
const esc = s => String(s).replace(/[&<>"']/g,
    c => ({'&':'&amp;', '<':'&lt;', '>':'&gt;', '"':'&quot;', "'":'&#39;'}[c]));
""" + helpers + "\n" + card + '\nconsole.log(hunkCard("test"));'
        filenames = [
            "normal.txt", "space in name.txt", "quote's.txt", '-leading.txt',
            "$(touch WB_COPY_EXECUTED).txt", "`touch WB_COPY_EXECUTED`.txt",
            "semi;touch WB_COPY_EXECUTED;.txt", "line\nbreak.txt", 'double"&<name>.txt',
            "back\\slash.txt", "日本語.txt",
        ]
        with tempfile.TemporaryDirectory() as tmp:
            repo = str(Path(tmp) / "repo's directory")
            for filename in filenames:
                with self.subTest(filename=filename):
                    page = subprocess.run(
                        ["node", "-e", script, json.dumps({"repo": repo, "file": filename})],
                        check=True, capture_output=True, text=True,
                    ).stdout
                    parser = CopyButtonParser()
                    parser.feed(page)
                    self.assertIsNotNone(parser.command)
                    # Replace the editor with an argv recorder in a disposable directory.
                    result = subprocess.run(
                        ["bash", "-c", 'nvim() { printf "%s\\0" "$@"; }\n' + parser.command],
                        cwd=tmp, check=True, capture_output=True,
                    )
                    expected = ["+7", "--", f"{repo}/{filename}"]
                    self.assertEqual(result.stdout.decode().split("\0")[:-1], expected)
                    self.assertFalse((Path(tmp) / "WB_COPY_EXECUTED").exists())


class EmbeddedDataTests(unittest.TestCase):
    def test_script_tokens_are_escaped_and_round_trip(self):
        attack = '<!-- <script> </script><script>alert("bad")</script> & 日本語'
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp)
            data = {
                "meta": {"repo": tmp, "repo_name": "fixture", "base": "main", "head": "WORKTREE"},
                "files": [],
                "hunks": [{"id": "file#1", "file": "file", "noise": False, "patch": attack}],
            }
            spec = {"title": "Regression", "summary": attack,
                    "chapters": [{"id": "fixture", "hunks": ["file#1"]}]}
            (out / "hunks.json").write_text(json.dumps(data))
            (out / "spec.json").write_text(json.dumps(spec))
            with contextlib.redirect_stdout(io.StringIO()):
                wb.cmd_render(argparse.Namespace(out=tmp, check=False, shot=False, no_open=True))
            page = (out / "index.html").read_text()
            blob = page.split("const D = ", 1)[1].split(";\nconst S =", 1)[0]
            self.assertNotIn("<", blob)
            restored = json.loads(blob)
            self.assertEqual(restored["hunks"]["file#1"]["patch"], attack)
            self.assertEqual(restored["spec"]["summary"], attack)
            self.assertEqual(page.count("</script>"), 5)


if __name__ == "__main__":
    unittest.main()
