---
title: The class-quest charge counts levels, so experience gained early costs time in the planner total
kind: finding
status: open
priority: normal
area: planner
source: claude
raised: 2026-10-21
raised_in: the completeness measurements of the planner worker (E1, batch 1), 2026-10-21
---

## What

The planner charges a class quest `--class-push` minutes (20) for every level the character is past the level the quest opens at when it is handed in. The charge counts **levels, not time**. So a route that finishes a quest earlier, and is therefore a level higher at a later class-quest hand-in, is charged more for the very same hand-in, although the clock at the hand-in is not later (a stop costs a little, the quest pays more).

Seen in the completeness measurements (docs/PLANNER.md, Measurements), Skyborne Druid: with the setting on the play time and the full simulation of the written route stay within +0.5% and -0.2%, while the class-quest charge in the planner total goes from 4h20 up to 6h20 and the total from 28h52 to 30h57 (+7.2%). The Tauren Druid's one row: charge 17h40 to 19h00, total +3.1%, play time +0.2%.

## Why

The total is what the searches rank routes by and what the reports compare, so it biases the search against any route that gains experience early while a class quest is waiting, and it makes an honest improvement look like a loss. The class-quest charge is deliberate (a class quest is due when its level is reached, no deadline: user, 2026-10-20), so the question is how to charge it.

## Done when

- A decision, with numbers: charge the lateness in time (for example the levels' worth of clock at the route's pace, from the level the quest opens at to the hand-in) instead of in levels, or leave it and have the reports show the total without the charge beside the one with it (the report already prints the charge on its own line).
- If the charge changes: the totals of the three guides before and after, and the reference totals in docs/PLANNER.md (22h33, 28h52, 44h40) updated.

## Notes

- Relevant code: `Planner.lateness`, `Planner.pending_charge` and `Settings.class_push`, `class_grace`, `class_levels` in tools/planner.py.
- Related: the item about the search being rough (the charge is 15% of the Skyborne total and 40% of the Tauren total).
