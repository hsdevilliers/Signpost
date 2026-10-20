---
title: The planner and the simulator price travel differently: a route simulates 13-17% under the estimate
kind: finding
status: open
priority: low
area: planner, simulator
source: claude
raised: 2026-10-20
raised_in: Route Planner runs, PR #35
---

## What

The Route Planner and the simulator price travel differently. The planner prices a leg by distance (walking speed, a detour factor, a flat
ferry time between continents). The simulator charges a flat few minutes for a border it has not learned yet. A planned route written as
guide steps and walked by the simulator comes out 13% to 17% shorter than the planner's own estimate: Troll Hunter 18h17 against 15h52,
Tauren Druid 25h00 against 20h41, Skyborne Druid 25h20 against 21h34.

## Why

The search optimises the planner's numbers. Where the two disagree it can prefer routes the simulator prices differently (many short zone
changes, for one). The ranking of routes is more trustworthy when both agree.

## Done when

- One travel model serves both (the simulator's learned and hand-authored borders and flight times in the planner, or the planner's
  distances in the simulator), or the difference is calibrated with a measured factor.
- The report's fidelity line is within a few percent for the three guides, or says why it is not.

## Notes

- Hand-authored zone borders (`Guides/Travel/Borders.lua`) and the borders the recorder learns are the data that would close it.
- Play data says how long a real route takes (`SignpostCharDB.pace`; `python tools/guide_sim.py --pace`).
