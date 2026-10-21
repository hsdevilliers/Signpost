---
title: A left-out line says a quest pays 265% of the route's pace and is still left out
kind: bug
status: open
priority: low
area: planner
source: claude
raised: 2026-10-21
raised_in: WP-A1 regeneration with the island exit required, 2026-10-21
---

## What

The Skyborne guide's `#skipquest 93160 >> not finished by this route: its work is 26 s away and pays 10.22 XP/s against the route's 3.85 (265%); completeness 2.65 or less would finish it` says that the quest
(The Forest's Bounty, level 13, picked up on the island) pays far more than the route's pace and is within the trip, yet it is left out because completeness is off. The code is `price` ("near but not worth
the trip"), which reads wrong for 265%. 92462 Infestation Investigation's line (71%, "completeness 0.71 or less would finish it") reads right.

## Why

The line is what the user reads to decide the completeness setting; a quest that would pay well but is left out with "not worth the trip" looks like a bug in the planner or in the data.

## Done when

The planner says why a quest paying more than the pace is left out (completeness off, or the search's own reason), or finishes it; a test pins the wording for a ratio above 1.
