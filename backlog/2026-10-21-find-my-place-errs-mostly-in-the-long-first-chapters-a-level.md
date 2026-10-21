---
title: Find my place errs mostly in the long first chapters (a level 8 Tauren is put at step 29, not 21)
kind: finding
status: done
priority: normal
area: engine, planner
source: claude
raised: 2026-10-21
raised_in: batch 1, independent review R-guides-A
closed: 2026-10-21
resolution: feat/find-my-place (WP-B): the line through a chapter is straight in experience, not in level, which fixes the long first chapters (against the simulator's levels the straight line was +1.68 levels on average and 3.18 at the 90th percentile in chapters of nine or more levels; the experience line is -0.12 and 1.10). On the final Tauren guide a level 8 character with nothing done is put at step 19, where the simulator has level 8 at steps 19 to 21 (it was step 29). Tables re-run in docs/ENGINE.md.
---

## What

The planner writes `#chapter 1-11 Mulgore` (45 steps) over a chapter that spans eleven levels; the placement interpolates levels in a straight line over its steps. A level 8 Tauren is put at step 29
under every scenario, even the exact follower (true step 21: +8 steps, confidence low). The same straight-line fit is off by 2.0 levels in Durotar and 2.7 in Mulgore; every other chapter is within 1.5 levels.
At level 8 a Troll lands exact 0, with skips -2, level only -10. From level 10 up it is sensible. Found by the independent review R-guides-A (batch 1) with the placement harness
(`python tools/placement_report.py`). The tables in docs/ENGINE.md predate the integrated guides.

## Done when

- The level model of a long chapter is better than a straight line (for example the planner writes a level gate or a finer `#chapter` range, or the placement reads the `.level` lines and the quests' own levels),
  and the tables in docs/ENGINE.md are re-run on the shipped guides.
