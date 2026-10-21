---
title: The level line is up to 2 levels optimistic at the start of a long chapter (the Skyborne island's tails)
kind: finding
status: open
priority: normal
area: engine, planner
source: claude
raised: 2026-10-21
raised_in: WP-B, the level term made robust, 2026-10-21
---

## What

The level line of Find my place (`Engine/Placement.lua`, now straight in experience) is up to about 2 levels too optimistic in the first steps of a chapter that spans many levels: in the Skyborne guide's island chapter (levels 1 to 15) the simulator has level 1.1 where the line says 2.6 at step 3, and 3.8 where it says 5.6 at step 9. Against the levels `tools/guide_sim.py` walks (`python tools/placement_report.py`, the second table) this leaves tails in the Skyborne guide that the Troll and Tauren guides do not have: of the runs with no history at all 1.9 percent are three or more levels off, of those who did half the quests in no order 1.3 percent, of those who stopped following it at 40 percent 0.6 percent (the Troll and Tauren guides: none, except 0.2 percent of the Troll's no-history runs). Under the spec's own truth (`warp`) there is no such tail: 27,000 no-history draws, none three levels off, the worst 2.76 levels, so `levelonly.catastrophic == 0` in the spec is only about 0.24 levels from failing on a regenerated guide.

## Why

Quests do not give equal experience: they give more as the character levels, which a line that is straight in experience between the chapter's two levels cannot know. A player who installs the add-on at level 3 to 5 with no quest history is put several steps ahead of where the guide has them.

## Done when

The first steps of a long chapter are placed by something that knows the quests' sizes, and the Skyborne tails above are gone or explained. Options, none tried: the planner writes a `.level` gate or a finer `#chapter` range inside a chapter that spans more than about six levels (the placement already reads both), the line reads each quest's own level from the private pack at build time and a small table of the expected level at a few steps is written into the guide, or the line is bent by a fixed exponent (a fit to the three guides; the three only agree to about 0.5 levels, so be careful not to tune it to one). `BIAS` 0.4 or 0.3 hides it (the island's no-history tail goes from 1.6 to 0.7 percent) at the price of being wrong in the short chapters, where 0.48 was measured: not a fix.

## Notes

Found while making the level term robust for the Skyborne guide (WP-B); numbers in docs/ENGINE.md ("Expected levels", "How the constants were chosen"). `Sim.WARP_BASE` and `WARP_SPAN` in `tests/helpers/placement_sim.lua` are the size of the spec's stress; a better line would let them go down.
