---
title: The thorough preset returned the greedy route after a few quests were skipped (a reproducible case)
kind: finding
status: open
priority: normal
area: planner
source: claude
raised: 2026-10-21
raised_in: review of the Skyborne Druid planner route (WP-A1), 2026-10-21
---

## What

On the Skyborne Druid, `python tools/route_planner.py windshaper --preset all` with the rules of PR #42 ended with a thorough route 41.8% faster than the greedy
one (26h43 against 45h55 in the planner's accounting). With the rules of the Skyborne review (tools/hardcore_rules.json and tools/drafts.json at commit 20254b3 of
branch feat/skyborne-guide: eleven quests skipped, eleven notes) the same command reported, for `thorough`: "29,296 complete routes reached the cap during the
search, none faster than the greedy one once tidied: this is the greedy route" (46h55). Its five finalists were then slower than the beam in the Monte Carlo
(median 32h19 against 20h36), so the install took the beam route (24h41 of play, 37h23 with the planner's charges). A plain beam run on an earlier state of
the review's rules (18 of the 22) came out at 47h45 against 28h52 for the rules of PR #42: a few skipped quests move the result by hours.

## Why

The guides are regenerated whenever a rule is added, and each regeneration is a lottery: the Skyborne route got 2h41 and then 3h50 of level-gate grinding
(0h37 before), and the Moonglade trip moved from level 20 to 24, with no change in what a player can do. This is the family of the open item "The planner's
search is rough: near-identical settings differ by hours".

## Done when

- The cause is found (candidates: the tidy step removes the quests a route left in the log and every finished route gets slower than greedy; the hopeless pruning
  drops the routes that would finish; the class-quest estimate) and the planner is fixed or the preset says when it cannot be trusted.
- A test pins the case on a fixture with a few skipped quests: thorough is never slower than greedy.

## Notes

- Reproduce: check out 20254b3 of feat/skyborne-guide (the chapters in the tree do not matter: the planner starts from the guide's first place) and run
  `python tools/route_planner.py windshaper --preset thorough --no-write`; read the "finished" line of the report. A search is deterministic.
