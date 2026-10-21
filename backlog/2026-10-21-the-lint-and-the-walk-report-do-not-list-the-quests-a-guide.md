---
title: The lint and the walk report do not list the quests a guide leaves out through #skipquest
kind: feature
status: open
priority: low
area: tools
source: claude
raised: 2026-10-21
raised_in: the completeness work of the planner worker (E1, batch 1), 2026-10-21
---

## What

The Route Planner now writes a `#skipquest <id> >> not finished by this route: <reason with numbers>` line into the guide for every quest it picked up on the way and did not finish (28 on the Skyborne, 41 on the Troll Hunter, 16 on the Tauren Druid in the current beam routes), and lists them with the numbers in its report (`unfinished`) and in plan.json (`left_out`). The lint and the simulator's walk report only use those lines to check that a quest of a chain is accounted for; neither prints a "left out" list per guide.

## Why

The plan the user approved (2026-10-21, after the missing Infestation Investigation) is that nothing is dropped silently, and the brief for it said that the lint or the walk report should be able to show what a guide leaves out. A list printed after a lint or a walk of an installed guide would let the user see, without running the planner, which quests the guide does not do and why.

## Done when

- `tools/guide_lint.py` (or `tools/guide_sim.py`) prints, per guide, the quests it leaves out through `#skipquest`: how many, grouped by reason, with the quest names from the data pack and the reasons as written.
- A test with a guide that has several `#skipquest` lines (different reasons) checks the list; mutation-checked.

## Notes

- The planner side is complete; this is only the display in the two other tools (not part of the planner worker's files).
