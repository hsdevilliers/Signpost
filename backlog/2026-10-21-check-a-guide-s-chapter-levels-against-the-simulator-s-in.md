---
title: Check a guide's chapter levels against the simulator's in the lint
kind: task
status: open
priority: normal
area: tools, planner
source: claude
raised: 2026-10-21
raised_in: WP-B, the level term made robust, 2026-10-21
---

## What

Find my place trusts a guide's `#chapter lo-hi` headers: they decide where the level term puts a character. If a planner or drafter writes them wider than the route really is (a chapter that says 5-8 and is really level 6 to 7), the placement degrades with it: against headers one level too wide at each end the clean followers still hold, but 0 to 2.7 percent of the no-history runs are three or more levels off (8.0 percent against the simulator's levels in the worst guide); two levels too wide at each end, 14 to 20 percent, and a clean follower is 2 to 3 quest steps off at the 90th percentile (docs/ENGINE.md, "How the constants were chosen"). Nothing checks the headers of a guide against what the route does.

## Why

The three shipped guides' headers agree with the simulator's levels to about half a level at the 90th percentile (the Tauren guide's no longer run 1.6 levels low, which the old drafted guide's did), but a guide regenerated tomorrow is checked by nothing here.

## Done when

`guide_lint` (or the planner, when it writes the header) compares each chapter's `lo-hi` with the level the route simulator (`tools/guide_sim.py`, `tools/placement_levels.py` already walks it) has at the chapter's first step and after its last, and warns beyond a level.

## Notes

The suggestion first came with the item "Re-run the placement simulation when the druid guides are regenerated" (closed with the final guides).
