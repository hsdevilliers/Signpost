---
title: Re-run the placement simulation when the druid guides are regenerated and update docs/ENGINE.md
kind: task
status: open
priority: normal
area: engine, guides
source: claude
raised: 2026-10-21
raised_in: batch 1, WP-B (Find my place)
---

## What

The placement numbers in docs/ENGINE.md ("Engine/Placement.lua", "How the constants were chosen, and how well it works") were measured against the guides as they were when Find my place was built: the Troll Hunter planned route, the old drafted Tauren Druid guide and the newly generated Skyborne Druid guide. The druid guides are being regenerated. After that: run `python tools/placement_report.py` (one command; with the data pack it adds the run against the simulator's levels), paste its tables into docs/ENGINE.md, and look at two things in them: whether `tests/placement_spec.lua` still holds (it fails if a regenerated guide breaks a bound), and whether the Tauren guide's chapter levels still run well below the simulator's (they did: on average 1.6 levels, up to 4.6, which makes its exact followers 8 quest steps off at the 90th percentile against the simulator's levels).

## Why

The constants were chosen on the three guides. A guide whose chapter levels are wrong pulls the pointer by its level term.

## Done when

The tables in docs/ENGINE.md are the ones of the guides that ship, and the constants are re-tuned (`python tools/placement_report.py -- --tune`) if the new numbers say so.

## Notes

If the planner or the drafter writes `#chapter lo-hi` from a route, a check that the levels it writes match the simulator's would catch a wrong chapter level before a player sees it.
