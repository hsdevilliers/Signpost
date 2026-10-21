---
title: Skyborne route takes the Tauren camp's 96605 and 96661 and skips its own set 96101, 96646
kind: finding
status: open
priority: high
area: guides, planner, data
source: claude
raised: 2026-10-21
raised_in: batch 1, independent review R-guides-B (the Skyborne guide)
---

## What

Found by the independent review R-guides-B of batch 1 (rated MUST-FIX by the reviewer; CONFIRMED in the pack, that the game refuses it is PLAUSIBLE, not proven). The Skyborne Druid guide
(`windshaper-druid-17-mulgore.lua`) routes `.accept 96605` The Great Outdoors from Kaga Wildhoof at Camp Narache and then `.accept 96661` Camping 101: Cooking, while `Guides/HordeWindshaperDruid.lua` skips
96101 and 96646 as "alternative to 96605 / 96661, which is routed". In the pack these quests are one exclusive family with one set for each start zone: 96659 The Adventurer (Chief Hawkwind, needs the Tauren start
quest 757) leads to 96605; the Skyborne set is 96638, 96101, 96646 (Raan Wildwind and Zerril Softbreeze on the island), and 96638 needs the island quest 92470. The guide takes 96638 on the island and
turns it in at Raan Wildwind; 96101 is its `next`, so the game hands it over right there. If the player accepts it, 96605 and 96661 are locked and the Mulgore steps cannot be done; if the player declines
it, the guide sends a level 29 character to Camp Narache for a quest the game very likely does not offer a Skyborne. The pack's race mask on 96605 is ALL_HORDE, which is why the rules call it available.
The rest of that chapter is also Camp Narache starter content (99079, 99411, 749, quest levels 6 to 9) for a level 29 character: a likely cause is the planner's guessed experience, 10% of the level's bar for a
quest the Classic seed does not know, which makes trivial Forever quests look lucrative.

## Why

A route is valid only if the game would offer every quest where the guide accepts it (CLAUDE.md). The simulator and the lint are blind to a family that the data does not mark as exclusive by race.

## Done when

- The route takes the Skyborne set (96638, 96101, 96646) or none of the family, with the guide regenerated; the exclusive-family rule knows one set per start zone (or the pack says which races each quest is for);
  the guessed experience of a quest far below the character's level is not 10% of the level's bar (a gray quest gives nothing), measured on the three guides.
- Or a Skyborne in the game shows what the game really offers at Camp Narache, and the finding is closed with that.
