---
title: The travel graph's walk price ignores the shared detour factor
kind: finding
status: open
priority: low
area: tools
source: claude
raised: 2026-10-21
raised_in: batch 1, independent review R-tools
---

## What

`tools/guide_travel.py` (`_walk_seconds`, about line 787) does not use `detour`, while `tools/signpost_tools/pricing.py` does: with detour 1.35 and a walk speed of 6 the graph prices 700 yards at
116.7 s and `pricing.PRICES.walk(700)` gives 157.5 s. It is dormant at the default detour of 1.0, but `detour` is the knob `tools/sim_params.json` advertises as shared by the planner and the
simulation. Found by the independent review R-tools (batch 1), confirmed by running it.

## Done when

- `_walk_seconds` calls the shared `pricing` function (one price for a walk), and a test sets a detour other than 1.0 and compares the graph with the shared price.
