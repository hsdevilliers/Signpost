---
title: Nothing writes .hs, so the hearthstone is never part of a planned route
kind: feature
status: open
priority: normal
area: tools, planner
source: claude
raised: 2026-10-21
raised_in: WP-F travel data, batch 1
---

## What

The travel generator can price a hearthstone (`.home`, once an hour) but only after an `.hs` step in the guide has set the bind
location, and nothing writes `.hs`: no chapter, the planner and the drafter never add one. `.home` is therefore never proposed, and the
hearth costs in `tools/guide_travel.py` (`HEARTH_SECONDS`, `HEARTH_COOLDOWN`) and the pack's 28 innkeepers (from the NPC records) go unused.

## Why

Trips between the big towns (Thunder Bluff, Orgrimmar, Undercity) are where a hearth saves minutes, and a RestedXP-style guide tells the
player which inn to make home. Without `.hs` steps a route walks or flies where it could hearth.

## Done when

- The generator proposes an `.hs` step (go to the innkeeper, `.hs <inn>`) at an inn the route passes when a later zone change would hearth
  there: the same idea as the `.fp` lessons (`learnable_flight_paths`, `flights_to_learn` in `tools/guide_travel.py`), with the
  cooldown kept by the simulation, and a written route with `.home` passes the lint and `guide_sim --check`.
- It is proposed only where the data holds the innkeeper (`travel.inns` or the NPC records) and the bind location's name.

## Notes

Written up by WP-F, 2026-10-21. `Travel:InnTarget` already pins the innkeeper of an `.hs <name>` step from `travel.inns[npc].n`, which
`Core/Learn.lua` now fills once the player has made an inn they talked to their home. Learned inns carry no side (the importer writes
none), so an inn learned by one faction counts for both; the NPC record's side could be inherited.
