---
title: Skyborne guide: two same-area quests are still left out after completeness (92598, 86784)
kind: finding
status: open
priority: normal
area: planner, guides
source: claude
raised: 2026-10-21
---

## What

After the Skyborne guide was planned again with completeness on (T 45 s, F 0.6; the quick PR after batch 1), two quests offered in the same area as the route's steps are still missing (A1's walk report for that generation):

- **92598**: its work is 49 s away, just over the 45 s trip the user chose.
- **86784 Sticks and Bones**: the guide has no line for it; not investigated (is it a data gap, an availability rule, a quest the planner judged slower than grinding?).

## Why

The user's rule: a quest offered where the route is, with its objectives in the same area, should be taken. The setting now covers the cases that were measured (92462 and 92463 are in, plus four more quests); these two show where its edges are.

## Done when

- 86784 is traced (the planner's reason for leaving it out, from the left-out list or a replay of the route) and either routed or explained in the guide's `#skipquest` lines.
- Whether 92598 should be reached by a slightly longer trip is the user's call (T 60 s is the next measured step); decide with the numbers of the later regeneration pass, not before.

## Notes

- Related: the finding `the-skyborne-guide-leaves-out-a-quest-offered-in-the-same` and the task `completeness-default-f-0-6-t-45-s-regenerate-the-three`.
