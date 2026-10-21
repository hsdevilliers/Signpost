---
title: The planner and the simulator price travel differently: a route simulates 13-17% under the estimate
kind: finding
status: done
priority: low
area: planner, simulator
source: claude
raised: 2026-10-20
raised_in: Route Planner runs, PR #35
closed: 2026-10-21
resolution: One price for travel: tools/signpost_tools/pricing.py is read by the planner (planner.py), the travel graph (guide_travel.plan_travel) and the simulation of a written route (guide_travel.simulate, guide_sim.run); tools/sim_params.json takes a travel object to override any number, a typo is an error. Cause found: the simulation priced a .zone hop and a change of continent with no boat in the data at 0 (the .zone step leaves the player nowhere, so the next walk was never measured); the planner priced both by distance. simulate() now walks from the last known point and charges the planner's 15 minutes for an unrouted change of continent. Beam, shared pack, planner against full simulation, before then after: Troll Hunter 20h37 vs 17h44 (-14.0%) then 20h15 (-1.7%); Tauren Druid 24h57 vs 18h58 (-24.0%) then 24h12 (-3.0%); Skyborne Druid 22h59 vs 18h24 (-19.9%) then 22h31 (-2.0%). The planner's own totals (22h33, 44h40, 28h52) did not move, so no route changes. What is left is about 20 minutes of local walking the planner adds per route and the walk inside doing steps, which the simulation does not price. Detour (1.0) and the boat times stay assumptions until play data calibrates them (guide_sim --pace). Docs: docs/PLANNER.md. Tests: tools/tests/test_pricing.py, SimulateTest, OnePriceTest. Branch feat/tools-lint-pricing.
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
