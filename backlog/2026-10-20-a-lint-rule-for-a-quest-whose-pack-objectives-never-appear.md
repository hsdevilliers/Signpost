---
title: A lint rule for a quest whose pack objectives never appear as a .complete
kind: feature
status: done
priority: low
area: tools
source: claude
raised: 2026-10-20
raised_in: independent review of the installed Troll Hunter guide, 2026-10-20
closed: 2026-10-21
resolution: tools/guide_lint.py objective_checks: with the data pack, a quest the pack gives objectives that the route accepts and turns in with no .complete for it (and no .todo naming it) is an error (missing-complete); some objectives but not all is a warning (partial-complete); a quest whose objectives are all talk-to the NPC that starts or ends it is exempt; without the pack the objectives are unknown, so the rule is skipped and the note says so. Tests in tools/tests/test_guide_lint.py; the three shipped guides are clean; deleting one explore .complete from the Troll and Tauren guides in a scratch copy gives the two errors. Branch feat/tools-lint-pricing.
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
