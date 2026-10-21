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

`beam` is 2 parts to a level, 30 wide (about 40 s a guide); `thorough` runs 2, 4 and 8 parts (each on its own: an earlier grain's best route used to
prune a later one, which made the answer depend on the order of the grains, 21h09 to 23h33 on the Troll Hunter; fixed in PR #38) and keeps the best
finished routes as they would be written, and its finalists are walked by the Monte Carlo. Nobody knows how far the best route found is from the
best route there is. More the final review measured:

- The default beam does not dominate: on the Tauren Druid the lookahead technique (4 s) makes 41h39 against the beam's 44h40 (the beam is better
  on the Skyborne, 28h52 against 37h53, and on the Troll Hunter, 22h42 against 27h01). `--preset all` takes the best of all of them.
- Skyborne totals as written, by grain: 53.8, 28.9, 30.5, 38.0, 27.0 and 26.2 h for 1, 2, 3, 4, 6 and 8 parts to a level.
- The headline gains are totals with the class-quest charges. Play time alone, greedy to beam: Troll Hunter 24h17 to 20h52, Skyborne 29h47 to
  22h59, Tauren 32h43 to 24h57 (the old beam's play time was 21h31, 29h46 and 29h49).
- A route is tidied when written (the quests the search left in the log are taken out). The search ranks routes before that, so its best route and the
  best route as written can differ by hours on the wrong settings (Skyborne, 1 part: 35.0 h before, 53.8 h after); the beam now compares its finalists
  as written, but it still searches with the free experience.

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

## Update (planner worker WP-E1, batch 1, 2026-10-21)

- The first "Done when" (a measure of the spread, so that a route that is not clearly better than the others is not trusted) is met by the `grains` table of the
  report: each grain of progress is searched on its own, its best route is written out the way a guide would have it, and the report says how far apart they are,
  with a warning above 5%. It is not enough to close the item: the other two points stand.
- Measured with it (`--preset thorough --runs 10 --no-check`, docs/PLANNER.md "Measurements"): Troll Hunter at 1, 2, 3, 4, 6 and 8 parts to a level: 26h37, 22h04,
  21h50, 34h36, 21h43, 21h54 (59% apart); Skyborne at 2, 4, 8: 27h56, 41h11, 26h43 (54%); Tauren at 2, 4, 8: 45h46, 40h46, 44h45 (12%). Four parts is the worst
  grain on two guides and the best on the third. The best of the three default grains is 7.4% (Skyborne) and 8.7% (Tauren) shorter than the beam's single grain.
- Settings that look alike differ by hours in other ways too: the hub radius (150, 250, 400 yards) and the walk inside a hub (a flat 8 s or by the map's distance)
  move the Skyborne beam from 27h42 to 42h34 and the Troll Hunter beam from 21h01 to 29h03 (planner totals; full simulation 17h20 to 24h54 and 16h50 to 22h27).
- The class-quest charge is 15% of the Skyborne beam's total (4h20 of 28h52) and 40% of the Tauren beam's (17h40 of 44h40), and it counts levels, not time
  (`the-class-quest-charge-counts-levels-so-experience-gained`): single-run differences of a few percent in the planner total are not evidence. Completeness
  (a tidy after the search) changes the Skyborne total by 2 to 7% through that charge while the play time moves by less than 0.5%.
