---
description: Write a handoff file so a fresh session can continue this work
argument-hint: "[focus]"
---
Write a handoff brief for a fresh session that has none of this conversation's
context, save it to a file in the project root, and give me a one-line prompt
to resume from it. ${@:-Cover the whole session.}

Steps:

1. Run `git status --short` and `git diff --stat` so the brief reflects the
   actual working tree, not your memory of it.
2. Write the brief to `handoff-<YYYY-MM-DD>-<slug>.md` in the project root.
   Use today's date. Derive the slug from the focus given above, or from the
   objective if none was given: lowercase, hyphens, at most four words.
   If a file with that name already exists, overwrite it.
3. Reply with only the path you wrote and the resume prompt. Do not repeat
   the brief in the reply.

Do not commit or stage anything, and do not modify any other file.
`handoff-*.md` is globally gitignored, so it will not appear in git status;
do not list it under Files touched.

The file uses exactly these sections:

## Objective
One or two sentences: what the work is for and what "done" looks like.

## State
- Working tree: clean, or the list of modified / untracked paths.
- What is complete and verified (name the command or test that verified it).
- What is in progress, and how far.

## Files touched
One line per file: path, and what changed or why it matters.

## Decisions
Choices made and the reason for each, especially ones a newcomer would be
tempted to reverse. Include anything the user explicitly asked for or rejected.
Do not restate the instructions of this handoff request as decisions.

## Open items
Numbered, in the order they should be picked up. For each: what to do, and
what is known that makes it easier (commands, file locations, prior attempts
that failed and why).

## Gotchas
Non-obvious facts about this codebase or environment that cost time to learn.
Omit the section if there are none.

Be concrete: paths, commands, function names, exact error text. Leave out
narrative of how the session went and anything the new session can trivially
rediscover by reading the code.

The reply has this shape and nothing else:

Wrote <path>

Resume: Read <path>, then continue from its Open items in order. <One clause
naming the first open item.> Do not commit unless asked.
