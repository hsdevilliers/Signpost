---
title: Is Forever's experience table Classic's? Find-my-place and the planners assume it
kind: verify
status: open
priority: normal
area: engine, data
source: claude
raised: 2026-10-21
raised_in: WP-B, the level term made robust, 2026-10-21
---

## What

`Engine/Placement.lua` draws a chapter's expected levels straight in experience, from `XP_TO_NEXT`: Classic's table (levels 1 to 59), the one `tools/sim_params.json` assumes. Nothing says it is Forever's. The one data point: a level 1 character's `UnitXPMax("player")` is 400 (docs/probes/1.60.1.70450.json), Classic's first entry. Forever has different XP tuning (CLAUDE.md, "Forever is not Classic"), so the rest of the table is unknown.

## Why

Only the table's shape matters to the placement (the first levels cost little experience), so a different table moves the lines by a fraction of a level, not by a chapter. But the tolerance and the spec's stress were sized against the Classic table, so a table that is much flatter or steeper would show as more error in the long chapters.

## Done when

`UnitXPMax("player")` is known for every level the guides reach (1 to 30 for the beta, 60 at launch), from play or from the friend's data, and `XP_TO_NEXT` is Forever's, or the Classic table is confirmed. The pace recorder (`Core/Pace.lua`) could store `UnitXPMax` at each level-up so that the table arrives with the data that already comes in; `python tools/guide_sim.py` and the Route Planner have the same assumption (`tools/sim_params.json`) and would take the table too. After that: `python tools/placement_report.py`, update the tables in docs/ENGINE.md.

## Notes

`VERIFY(launch)` in `Engine/Placement.lua`; an open probe in docs/FOREVER-API-NOTES.md.
