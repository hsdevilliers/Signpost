---
title: Dungeon and raid quests are not recognized: the pack stores an instance's map id as the quest zone
kind: finding
status: done
priority: normal
area: planner, drafter, data
source: claude
raised: 2026-10-21
raised_in: review of the Skyborne Druid planner route (WP-A1), 2026-10-21
closed: 2026-10-21
resolution: Done in batch 1 (WP-E1): Planner._in_instance treats a quest whose pack zone is no map of the pack (all 19 such zone ids are dungeons or raids) as a dungeon quest: optional with a note in a normal route, dropped in a HARDCORE route (after the skip rules, so a rule keeps its own reason). Tests in tools/tests/test_planner.py. The drafter has the same gap: its own item.
---

## What

19 zone values in the pack's quests are not maps of the pack (166, 213, 221, 232, 233, 234, 242, 247, 248, 253, 279, 280, 287, 300, 302, 306, 310, 317,
320). By the names of the quests that carry them they are instance maps: 213 Ragefire Chasm (Testing an Enemy's Strength, Hidden Enemies), 221 Blackfathom
Deeps, 234 Dire Maul, 242 Blackrock Depths, 279 Wailing Caverns, 280 Maraudon, 302 the Scarlet Monastery, 306 Scholomance, 310 Shadowfang Keep, 317
Stratholme, 320 end-game raid sets (the others not checked one by one). The HARDCORE criteria know battlegrounds (`skip_zones` of tools/hardcore_rules.json)
and elite objectives, not instances: the first Skyborne route accepted three dungeon quests (1491 Smart Drinks, 1013 The Book of Ur, 6921 Amongst the
Ruins; skipped by hand on 2026-10-21), and a check for quests offered at the route's steps found 5726 Hidden Enemies (Ragefire Chasm) and 6562 Trouble in
the Deeps (Blackfathom Deeps) as well.

## Why

docs/HARDCORE.md: dungeons are skipped by default. A dungeon quest in the open route is the worst thing a hardcore guide can send a player to.

## Done when

- The drafter and the planner treat a quest whose zone is an instance map as a dungeon quest in a HARDCORE route (skipped, with a reason that starts with
  HARDCORE), after deciding the lead-ins: 1489 Hamuul Runetotem and 1490 Nara Wildmane carry the Wailing Caverns zone but are talk quests in the Barrens and
  Thunder Bluff, so a quest whose objectives and ender all lie outside the instance stays. A test pins both cases.
- A normal route keeps them as group or dungeon quests tagged `.optional`, as today.
