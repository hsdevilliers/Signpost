---
title: The quest log limit counts quests the search takes out again, so it steers the search too hard
kind: finding
status: open
priority: low
area: planner
source: claude
raised: 2026-10-21
raised_in: WP-E1 (batch 1), measurements of 2026-10-21
---

## What

The Route Planner's quest log limit (`Settings.quest_log_limit`, `--quest-log N`, default 40) is checked against every quest a partial route has accepted
and not handed in, including the ones `Planner.tidy` takes out of the written route again because the route never finished them. The beam's partial
routes hold a lot of those: with the log unlimited, 29% of the situations the Troll Hunter beam makes hold more than 40 quests, 67% more than 25, at most 68,
while the written routes hold at most 16 (Troll Hunter), 15 (Skyborne Druid) and 11 (Tauren Druid) (41 quests of the best Troll Hunter route were accepted
and never finished). So the limit steers the search far harder than it constrains the guide.

Measured (beam, default settings, planner total with the charges, written route's most held in brackets):

| limit | Troll Hunter | Skyborne Druid | Tauren Druid |
| --- | --- | --- | --- |
| none | 22h33 (16) | 28h52 (15) | 44h40 (11) |
| 40 | 22h49 (16) | 28h52 (15) | 44h40 (11) |
| 25 | 23h40 (20) | 31h22 (14) | 44h52 (11) |
| 12 | 23h30 (12) | | |

## Why

At the default (40) the Troll Hunter beam is 16 minutes (1.2%) slower for quests the guide never holds; if the client says the limit is 25 the Troll Hunter
is 5% and the Skyborne 8.7% slower. The size is that of the search's own roughness (`the-planner-s-search-is-rough...`), but it has a cause that can be removed:
the search counts quests it will take out again.

## Done when

A search that does not count the quests it will not finish against the limit (for instance by accepting only the quests a route is going to work on, or by
checking the limit on the part of the route that is finished), with the totals above measured again, or a measurement that shows the difference is noise.
docs/PLANNER.md "Measurements" updated.

## Notes

- Tried and not kept (WP-E1, 2026-10-21): a relaxed search that obeys no limit while it looks and the real limit only when `tidy` walks the route again. It is the
  unlimited search while the limit does not bind, but at a limit of 12 the Troll Hunter came out at 28h51 against 23h30 with the limit applied everywhere, because
  the replay that has to obey the limit throws away quests the search counted on.
- `Planner.offered` is the one place the limit is checked (a visit, `options`, `overdue_hubs` and the replay of `tidy` go through it); `Planner.grind` skips
  the quests it would otherwise wait for a level to accept.
- Quests held for hours before they are handed in (`the-planner-does-not-limit-the-quest-log...`, review of 2026-10-20: 6365 held 612 minutes) are the same
  root: an accept costs the planner 12 seconds and nothing else.
