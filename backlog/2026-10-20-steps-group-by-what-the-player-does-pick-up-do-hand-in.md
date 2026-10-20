---
title: Steps group by what the player does: pick up, do, hand in (replaces one NPC per step)
kind: feature
status: open
priority: normal
area: engine, ui, guides
source: user
raised: 2026-10-20
raised_in: the user, 2026-10-20, dictated while the Route Planner was being merged
---

## What

From the user (2026-10-20), who says this goes against their earlier rule "one step per NPC, kills and collecting are steps of their own"
and that they now think it is better:

A step is built around one activity, not one NPC.

- **Pick up.** In an area where quests can be picked up (one to N of them) a single step accepts all of them: "you then accept N amount of
  quests".
- **Do.** The next step is doing quests, and the quests in one step are grouped by how near their objectives are to each other:
  geographically, by coordinates, "kind of close to each other at least". The step does not track each quest's progress. The quest log
  already does that ("the quest log is awesome as it is"). The step only needs to know which of its quests are complete, and once all of
  them are, the guide moves on.
- **Hand in.** The next step is moving back, or on, to where the quests are handed in, and handing in all of them.
- **Any mixed sequence.** It does not have to be pick up, do, hand in. It can be three different places where quests are picked up,
  followed by five different places where they are done, then picking up again, then handing in.

## Why

The game's own quest log tracks the progress of every objective and shows where to go. The guide only has to steer the player from place
to place and say what to do there, so fewer and larger steps read faster and ask less of the step frame.

## Done when

- `docs/GUIDE-FORMAT.md` and `docs/ENGINE.md` describe the three kinds of step and when each is complete (pick up: every quest of the step
  is in the log; do: every quest of the step is complete in the quest log; hand in: every quest of the step is turned in), and what becomes
  of `.accept`, `.turnin`, `.complete <quest>,<objective>` and the lint rules that read them.
- The engine implements it, with busted specs. The step frame shows it (see the step frame item) and the markers follow it (see the
  markers item).
- The tools write it and the guides are rebuilt (see the tools item).

## Notes

Added by Claude, to settle with the user before building:

- Today a step holds directives and the engine completes it from them (`Engine/Conditions.lua`). GUIDE-FORMAT lists `.complete
  <questID>[,<objective>]` as done when "that objective ... or all are finished, or the quest is complete or turned in", so a doing step over
  several quests could already list `.complete <quest>` for each. Whether that is enough, or a new directive for "all of these quests are
  complete" is clearer, is open.
- How a step has its kind: inferred from its directives, or written in the step.
- What "close to each other" means when doing steps are grouped: a radius in yards (the Route Planner's hubs are about 150), the objective
  areas of the quests, or the author's call.
- A quest picked up in one place and handed in in another, or with objectives in two places, spans steps: which step it counts in, and
  what a skipped or abandoned quest does to its step.
- The group-quest line (an extra line beside the current step until the quest is done or the character is 5 levels above it; PROGRESS) is
  a second line next to the step and has to fit the new steps.
- Decided with the user (2026-10-20): the step kind is inferred from the directives (no new syntax); "hand in" and "pick up" at one place is one
  step; a doing step shows neither a marker nor words about where, only its quests with a done mark (the quest log marks the objectives, and the
  guide sets the quest tracker to them: see the tracker item); neighbouring steps of one kind within 250 yards of the first become one.
- Until this is built the drafter and the planner keep writing one NPC per step, with kills and collecting as steps of their own.
