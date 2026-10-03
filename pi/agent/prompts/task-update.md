---
description: Update this worktree's TASK.md in place from the current session
argument-hint: "[focus]"
---
Bring `TASK.md` at the git repository root up to date with this session, so a
fresh session, another model, or a post-compaction turn can continue from it
alone. ${@:-Cover the whole session.}

Steps:

1. Run `git rev-parse --show-toplevel`, `git status --short` and
   `git diff --stat` so the file reflects the actual working tree, not your
   memory of it.
2. Read `<toplevel>/TASK.md` if it exists. Edit it in place: keep entries that
   are still true, update ones that changed, remove ones that are done or
   obsolete. Do not append a dated log. If it does not exist, create it.
3. Reply with only the path and a one-line summary of what changed. Do not
   repeat the file in the reply.

Do not commit or stage anything, and do not modify any other file. `TASK.md`
is globally gitignored.

The file uses exactly these sections:

## Objective
One or two sentences: what the work is for and what "done" looks like.

## State
- Working tree: clean, or the list of modified / untracked paths.
- Verification: the last check run, its command and result, or "not run".
- What is complete and verified, and what is in progress and how far.

## Decisions
One bullet per decision: the choice, the reason, and the alternatives that
were rejected and why. Include anything the user explicitly asked for or
rejected. These are the entries a newcomer would be tempted to reverse.

## Open items
Numbered, in the order they should be picked up. For each: what to do, and
what is known that makes it easier (commands, file locations, prior attempts
that failed and why).

## Gotchas
Non-obvious facts about this codebase or environment that cost time to learn.
Leave the heading with no bullets if there are none.

Be concrete: paths, commands, function names, exact error text. Leave out
narrative of how the session went and anything a new session can trivially
rediscover by reading the code.
