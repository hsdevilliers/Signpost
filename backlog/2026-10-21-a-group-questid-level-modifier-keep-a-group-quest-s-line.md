---
title: A .group <questID>[,<level>] modifier: keep a group quest's line until it is done or 5 levels low
kind: feature
status: open
priority: normal
area: engine, planner, ui
source: claude
raised: 2026-10-21
raised_in: batch 1, WP-C (step card): the engine part of the user's group quest wish
---

## What

A `.group <questID>[,<level>]` modifier for GUIDE-FORMAT, written by the planner and the drafter in place of `.optional <questID> -- group quest: <name>`, so
that the step card can keep a group quest in front of the player until it is done or too low, which the engine cannot decide today because it does not know a
quest's level (the data pack has it, the public addon without the pack must not need it).

What the step card does now (branch `feat/step-card-polish`, batch 1): a step made only of `.optional` quests never holds the player up (`Conditions:IsComplete`),
and a group quest whose step is among the next three steps, and that the player has neither taken nor done, is a line beside the current step: `Optional: <quest>
(group quest)` (up to two lines). The line goes when the quest is in the log or done, or its step is passed. See GUIDE-FORMAT "Optional-only steps".

The proposal:

- `.group <questID>[,<level>]` is a modifier like `.optional` and implies it (the quest's directives stop counting when anything else decides the step; a step of
  nothing else is an optional-only step); `<level>` is the quest's level, optional so that an old guide and a quest of unknown level still work. Parser, lint
  (`tools/signpost_tools/guidefile.py`, `tools/guide_lint.py`) and docs/GUIDE-FORMAT.md take it; `.optional` stays.
- The planner (`Planner._step`) and the drafter (`guide_draft.py`) emit `.group <id>,<level>` for a group (elite) quest of a normal route, from the pack's quest
  level.
- The card keeps the line for a quest the player has neither taken nor done **until the character is five levels above the quest's level**, and not only for the
  next three steps: the quest's own steps are passed automatically, so the line is the only offer, and it should stay while the quest is still worth doing.
  The engine remembers which group quests the route passed untaken (derived from the route behind the current step, nothing saved).

## Why

The user's wish (2026-10-20, PLAN "Group quests in a normal guide", PROGRESS): "group quests as an additional line beside the current step until completed or 5
levels below the character". Group quests are optional (PLAN §2: offered again about 5 levels later). The part that needs the quest's level was left out of the
card work on purpose (batch 1, WP-C): no guess at a level the engine cannot know.

## Done when

- GUIDE-FORMAT, Parser, `guidefile.py` and the lint accept `.group <questID>[,<level>]` (documented, with specs); the planner and the drafter emit it.
- The step card shows a group quest's line from the step before its first step until it is in the log, done, or the character's level is the quest's level + 5, at
  most two lines, with specs for each end (a quest handed in, a level gained) and for a quest with no level (the old rule: the next three steps).
- The decision about a `>> <quest name>` on `.group` is made (see Notes).

## Notes

- Without the data pack the line reads `Optional: Quest #442 (group quest)`, the same fallback as every quest line. The tools write the quest's name as a trailing
  comment (`-- group quest: Assault on Fenris Isle`), which the parser drops. A `>> <name>` on `.group` (today `>>` is refused on `.optional`) would carry the
  name into the public addon without the pack.
- A group quest the player takes **after** the route passed its steps (they were passed because the quest was not in the log) has no current step any more: its
  `.complete` and `.turnin` steps are behind the pointer, the card names nothing, and only the quest log's own tracker shows it. This is the usual case for a
  group quest written as one step (accept, do, hand in): the step is passed the moment the step before it completes, so a player who walks up to the NPC afterwards
  finds no step and no card line. The line that stays "until completed or 5 levels low" is the answer; a way back to a quest taken late (the line turning into
  "Complete: <quest>" while the quest is in the log, or the engine stepping back to its step) is part of this item.
- A group quest accepted beside ordinary quests at one NPC (a mixed step, e.g. `.accept 6283` and `.optional 6283` in the Stonetalon chapter) is not an optional-only
  step: its `Accept "<quest>"` line stays in the body. With `.group` the card could show it as the same kind of line instead.
- The Troll Hunter route of this branch has six optional-only steps and five mixed steps that mention an optional quest (a scan of
  `Guides/Chapters/troll-hunter-*.lua` through the engine; the earlier count of nine was of an older planned route).
