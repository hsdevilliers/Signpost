# The backlog

What is left over: findings, doubts, shortcuts, follow-ups, questions nobody has answered yet, and whatever the user tells us to note. One
Markdown file per item in this folder, so two branches never collide and every item has its own history. The tool is
`tools/backlog.py`; the tool tests check every item, so CI does.

```
python tools/backlog.py                         the open items, by priority
python tools/backlog.py show steps-group        one item (any unique part of its id)
python tools/backlog.py add "Title" --kind finding --source claude --area planner --body-file notes.md
python tools/backlog.py status ID doing         while it is being worked on
python tools/backlog.py close ID --resolution "PR #36: what was done"
python tools/backlog.py drop ID --reason "why"  (an item the user raised also needs --agreed "the user, date: what they said")
python tools/backlog.py check
```

## The rules (user, 2026-10-20, standing)

1. **Nothing is left only in conversation.** Before a PR is pushed and before a session ends, every open question asked of the user and every
   problem found and not fixed is either closed (answered, fixed, verified) or written up here first. A question nobody answered is an item
   of kind `question`. The PR description lists the items it adds and closes.
2. **The user's notes go in as they said them** (`source: user`): "add this to the backlog" is written down in their words and
   their order, with nothing dropped, softened or "improved"; what Claude adds (open design points, the files concerned) goes under *Notes*.
   Findings Claude makes are `source: claude`.
3. **An item is closed in the change that resolves it** (`close`, with the PR or commit) and never deleted. Closed items stay as the record.
   A closed item is not reopened: a new item points to it.
4. **Only the user drops what the user raised.** `drop` on a `source: user` item needs their agreement, written into the resolution.
   Claude's own findings can be dropped with a reason (no longer true, superseded by ...).
5. The backlog is public and follows the repository's data rules: no Wowhead-derived text, no data pack tables; quest IDs and coordinates
   only where the guides already carry them.

## An item

`YYYY-MM-DD-slug.md` (the day it was raised, then lower-case words). Front matter, then Markdown:

```
---
title: One line: what is left over (at most 110 characters)
kind: feature | bug | finding | question | task | verify
status: open | doing | done | dropped
priority: high | normal | low
area: engine, ui, planner          (lower-case tags, optional)
source: user | claude
raised: 2026-10-20
raised_in: where it came up         (optional: a PR, a session, a file)
closed: 2026-10-21                  (done or dropped only)
resolution: PR #36: what was done   (done or dropped only)
---

## What
## Why
## Done when
## Notes
```

- **kind**: `feature` something to build; `bug` something wrong that is known; `finding` something noticed that needs a decision or work;
  `question` waiting for the user's answer; `task` plain work; `verify` something only the game (or the user in it) can confirm.
- **priority** is `normal` unless the user says otherwise, or it blocks a release or hurts a player.
- The body says what it is, why it matters, and what *done* looks like, so a reader with no memory of the session can act on it.

## What does not belong here

- The phase checklists of `docs/PLAN.md` (progress and evidence live in `docs/PROGRESS.md`).
- Open probes of the client (`docs/FOREVER-API-NOTES.md`, "Open probes", and the `VERIFY(...)` comments next to the code).
  An item may point to them.
