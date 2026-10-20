---
title: The planner's search is rough: near-identical settings differ by hours (beam width, grain, class-quest charge)
kind: finding
status: open
priority: normal
area: planner
source: claude
raised: 2026-10-21
raised_in: independent algorithm review of PR #38 and the beam rewrite, 2026-10-21
---

## What

The beam compares routes by how far they have got (PR #38; it replaced a beam that compared them after the same number of visits and finished
nothing on the druids). It is much better, and still rough. Runs on the same data, one setting changed (planner totals in hours; greedy is
29.1, 46.0 and 72.8 for the Troll Hunter, the Skyborne and the Tauren Druid):

- Troll Hunter: 21.2 to 24.9 across widths 20 to 60 and 1, 2, 4 or 8 parts to a level; a wider beam (60, 2 parts) was worse than a narrower
  one (30, 2 parts): 23.9 against 21.2.
- Skyborne Druid: 27.0 to 38.7. Tauren Druid: 40.6 to 50.8. The spread comes mostly from when the class quests get done: 4 to 20 hours of
  the totals are the 20-minutes-a-level charge.
- The same search with the old estimate of what the class quests will cost (every undone quest charged at the character's present level) was
  10 to 40% slower on the druids and found nothing at all on the Skyborne.

`beam` is 2 parts to a level, 30 wide (about 40 s a guide); `thorough` runs 2, 4 and 8 parts and keeps the best, and its finalists are walked by
the Monte Carlo. Nobody knows how far the best route found is from the best route there is.

## Why

An install takes the best route the search found. If a different setting would have found one 10% shorter, the guide is 10% slower for everyone,
and the planner cannot say so.

## Done when

- A measure of the spread: the report (or a flag) runs the beam at several settings and says how far apart the results are, so a route that is
  not clearly better than the others is not trusted.
- Or a better estimate of the time to go (it ignores travel, zone changes, the class quests' trips and the work of quests already half done) so
  that the width stops mattering; a test that a wider beam is never worse on the fixtures.
- docs/PLANNER.md says what was learned.

## Notes

- The estimate `to_go` is the greedy walk's pace at each level; `pending_charge` charges an undone class quest for the level the character will
  have when it gets there. Both are optimistic about travel.
- A search by quest (the class chains as milestones) rather than by hub visit may behave better than any estimate.
