---
title: A lint rule for a quest whose pack objectives never appear as a .complete
kind: feature
status: open
priority: low
area: tools
source: claude
raised: 2026-10-20
raised_in: independent review of the installed Troll Hunter guide, 2026-10-20
---

## What

The lint finds a quest accepted and handed in with no `.complete` between only when it can see the objective in a step it checks. An independent
review of the guides (2026-10-20) found four such quests in the Troll Hunter guide and three in the druid guides, all with explore objectives the
generators used to drop (fixed in the planner and the drafter). A lint rule would catch the next hole of this kind.

## Why

A hole in a generator's objectives is invisible to the lint today and gives the player a step that cannot be finished, or free experience in the
simulator.

## Done when

`guide_lint.py` reports (as an error with the pack, a warning without) a quest the pack gives objectives that is accepted and turned in with no
`.complete` and no `.todo` for them, with a test.
