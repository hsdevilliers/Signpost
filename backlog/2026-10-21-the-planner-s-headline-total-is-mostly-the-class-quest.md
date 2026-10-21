---
title: The planner's headline total is mostly the class-quest charge and reads like play time
kind: finding
status: open
priority: normal
area: planner
source: claude
raised: 2026-10-21
raised_in: review of the Tauren Druid planner route, batch 1 (WP-A2), 2026-10-21
---

## What

The Route Planner prints, and docs/PROGRESS.md and the PRs quote, a "total" that is the play time plus what the planner charges: 3 minutes for every change of zone, and 20 minutes for every level a class quest is undone past the level it opens at (up to six levels). For the Tauren Druid the beam's 44h40 is 24h57 of play + 2h03 of zone-change cost + 17h40 of class-quest charge. The HARDCORE rules explain none of it: the same beam as a normal route, on the same data, is 24h36 of play and 42h18 in all. With the charge switched off (`--class-push 0`) the play time is the same (24h33), but then every class quest but the first two waits for level 30. The charge steers the search; it is not time anyone plays. The written route, simulated in full, takes 18 to 24 hours.

## Why

"44h40" reads as "the Tauren guide takes 44 hours" and raised the question why it is twice the Troll Hunter's. The report does say "(+ 17h40 for class quests done late the planner charged)", but its summary line and the docs lead with the sum.

## Done when

The report's summary, docs/PLANNER.md and PROGRESS lead with the play time and the simulated time of the written route, and show the charges apart.

## Notes

- Area: planner (WP-E1's files). Raised by the review of the Tauren Druid planner route (batch 1, WP-A2); the numbers are from its first run, 2026-10-21.
