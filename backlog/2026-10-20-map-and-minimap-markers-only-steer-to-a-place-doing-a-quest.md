---
title: Map and minimap markers only steer to a place; doing a quest is left to the quest log
kind: feature
status: open
priority: normal
area: ui
source: user
raised: 2026-10-20
raised_in: the user, 2026-10-20, dictated while the Route Planner was being merged
---

## What

From the user (2026-10-20): the built-in quest log already marks, on the minimap and the map, how to complete each quest, so the guide must
not put markers on doing steps. The guide's markers exist to steer a person to a hub: "go to the Crossroads and pick up quests there" gets
a marker, because the quest log has nothing that says it. A marker is also right for moving back to hand in. In the user's words: markers
for anything that is not quest doing.

- Markers: going to a place to pick up quests (the hub), going to a place to hand in, and travel (a path, a flight, a boat, a zeppelin, the
  hearthstone) as now.
- No markers: a doing step (kill, collect, use, explore). What to do and where is shown by the quest log's own map and minimap marks.

## Why

Two sets of marks for one objective compete on the same minimap, and the quest log's follow the objective as it progresses. The guide's
job is what the log cannot do: the order, the places and the hubs.

## Done when

- `UI/Pins.lua` pins a step by its kind (see the steps item): pick up, hand in and travel steps get their pin, doing steps none.
- Doing steps keep their coordinates in the data (the simulator, the lint and the travel planning use them); they are only not drawn.
- A spec or an option shows what is drawn for each kind, and `docs/GUIDE-FORMAT.md` says it.

## Notes

- GUIDE-FORMAT says today that `.complete` pins the objective area (and that kill-credit objectives pin the creatures that give the
  credit). This item takes that pin away.
- It needs the step kinds from the steps item, so that a doing step's `.goto` is known not to be drawn.
