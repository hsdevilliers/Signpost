---
title: No creature new in Forever carries an elite flag, so HARDCORE cannot see Forever's elites
kind: finding
status: open
priority: normal
area: data, engine
source: claude
raised: 2026-10-21
raised_in: review of the Tauren Druid planner route, batch 1 (WP-A2), 2026-10-21
---

## What

The HARDCORE rule "no quest that needs an elite or boss kill" reads the data's creature rank. The data has a rank for Classic's creatures and for none of Forever's new ones (ids of 60000 and up), so a new quest that kills a new named creature passes the rule whatever the creature is. The first review of the Tauren Druid route (2026-10-21) put seven of them on the hand-kept list: 92422 The Wrath of Rath'mael, 92706 WANTED: Bruuz, 97003 Chol'aruk the Ravener, and the four quests of the new Gloomrise nest in northern Mulgore (96241, 96259, 96260, 96261; levels 30 and 31, with a named Broodmother). There will be more as the guides grow.

## Why

HARDCORE is the promise of two of the three Release 1 guides, and the list is a guess from names: it may skip creatures that are not elite (the four nest quests are worth about 30,000 experience at levels 29 and 30, where the Tauren route is short of quests) and it will miss others.

## Done when

The client tells us. `UnitClassification` of a quest target seen in play ("elite", "rareelite", "worldboss") can be recorded by `Core/Learn.lua` (opt in, like the rest, docs/SHARING-DATA.md) and read back into an elite list that the rules use. The hand-kept entries for the seven are then confirmed or dropped.

## Notes

- Area: data, engine (recorder). Whether `UnitClassification` works on a target in the Forever client is an open probe.
- Raised by the review of the Tauren Druid planner route (batch 1, WP-A2).
