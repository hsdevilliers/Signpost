---
title: tidy can leave a quest accepted and never finished, with no record, in extreme settings
kind: finding
status: open
priority: low
area: planner
source: claude
raised: 2026-10-21
raised_in: batch 1, independent review R-tools
---

## What

`tools/planner.py` (`tidy`, about line 1097) bounds its rounds at 4 (6 with completeness). The independent review found settings where a quest stays accepted in the route's final state
without being finished and without a `left_out` record or a `#skipquest` line: Troll greedy with `--quest-log 2` leaves quest 509 in `plan.final.active`; `--completeness 0.01
--completeness-trip 100000` leaves 5 quests (366, 5482, 99152, 99153, 99156). At the defaults (and with limits 12, 25 and 40, completeness 0.4 to 0.6 with trips up to 90 s) it does not
happen: 15 tidy calls per guide leave none, and a 1,152-case fixture fuzz found none either.

## Why

The rule of the planner is "nothing is dropped silently, and what the route accepts it finishes".

## Done when

- `tidy` runs to a fixpoint (or a final pass drops what is still unfinished, with a record), and a test uses a limit of 2 or an extreme completeness to show it.
