---
title: Completeness: which values of F and T should be the defaults?
kind: question
status: open
priority: normal
area: planner
source: claude
raised: 2026-10-21
raised_in: the completeness measurements of the planner worker (E1, batch 1), 2026-10-21
---

## What

The Route Planner can now finish a quest it picked up on the way and would otherwise have left out of the route (the Skyborne guide's Infestation Investigation was the case). It is switched on with `--completeness F --completeness-trip T` and is **off by default**; the user chooses the default values from the table in docs/PLANNER.md, "Measurements".

In plain words:
- **F** is how good a deal the quest must be compared with what the route earns anyway: 0.6 means the quest must pay at least 60% as much experience a second as the route does at that level (the walk to its objectives and to the hand-in included).
- **T** is how far, in seconds of walking, the guide may send the player back from where the quest was picked up to its objectives (30 s is about 210 yards, 45 s about 315, 60 s about 420).

What the table shows (beam, all three guides, 10 settings each; every run deterministic):
- **T matters, F hardly does.** At T = 30 s only the Skyborne gains a quest (Infestation Investigation, at F = 0.6 or lower: it pays 71% of the route's pace); the Troll Hunter and the Tauren Druid gain none.
- **T = 45 s with F = 0.6 is the smallest of the measured settings (30, 45, 60 and 90 s) that brings both 92462 and its follow-up 92463 (The Cirrusfly Queen) into the Skyborne route**: 3 quests finished (Infestation Investigation, The Cirrusfly Queen, Flutterfly Dust) and 2 more opened by them, the play time is 0.2% shorter (planner and full simulation); the Troll Hunter gets 1 small quest (and 2 it opens, 0.1% shorter) and the Tauren Druid none.
- Larger T finishes a few more small quests (the Skyborne 5 to 8, the Troll Hunter 1 to 5, the Tauren Druid 0 to 1) and moves the play time by -0.9% to +0.5%, which is inside the search's own roughness.
- None of the quests added has an objective with no position in the data.
- The planner's *total* for the Skyborne rises by 2 to 7% with the setting on, only because of the class-quest charge (see the finding about that charge); the play time does not.

## Why

The user said (2026-10-21) that a quest picked up in an area with its kills a short trip away should be done, and also that enlarging an area was a shot in the dark. How short a trip is "short" is a taste as much as a measurement, so the user decides; a default of "off" keeps today's behaviour and still lists every quest left out with its reason.

## Done when

- The user has said which F and T to use as the defaults (or to keep it off), in the Settings defaults and the `--completeness` help.
- The three installed guides are regenerated with that choice and the Skyborne route is checked for 92462 and 92463.
- docs/PLANNER.md says what was chosen and why.

## Notes

- Suggested answer, for the user to take or change: F = 0.6 and T = 45 s.
- The setting acts after the search, when the route is written; it does not change where the search goes. The search choosing the shared hunting ground itself is the item about shared hunting spots.
