---
title: Fill the missing objective positions: a gap list for the exporter and the game's own quest areas
kind: feature
status: open
priority: normal
area: tools, data
source: user
raised: 2026-10-21
---

## What

The user's words (dictated, 2026-10-21): "items that are picked up might not be flagged as NPCs, but I'm almost 100% sure they are still some form of an entity that are logged in the database, like something that you need, that needs picking up, can be queried and searched for on WowEd as an example. So I'm sure we can, you know, effectively get their area where we need to get them if that is a position issue for item pickup quests. Does that make sense?" ("WowEd" is read as Wowhead; to be confirmed with the user.)

What the data says (traced 2026-10-21 in the pack and in its raw questie layer): pick-up items are entities in the pack (objects, containers, creatures that drop them) and the planner already follows item -> object or creature -> spawn positions. The positions themselves are missing. The questie layer holds 120 of 670 objects and 808 of 4209 creatures as a name only (examples: objects 20920 Blueleaf Tuber, 36738 The Book of Ur, 177964 Fathom Stone, 164690 Krom'zar's Banner; creatures 3475 Echeyakee, 3257 Ishamuhale, 4490 Grenka Bloodscreech). The import did not lose them: its problem list names six unmapped areas only, and the layer itself has no coordinates for these records. Forever-range entities are better covered (creatures with id 200000 and up: 366 of 416 have positions; objects 400000 and up: 109 of 111).

The objectives without a position in the installed guides, by cause:
- Skyborne guide, 24: 13 items with no known source at all (neither creature nor object), 5 items dropped by creatures that have no positions, 4 items from objects that have no positions (ground items, containers), 1 kill of a creature without positions, 1 spell objective (no position by nature).
- Troll Hunter guide, 21: 3 items with no known source, 9 items dropped by creatures without positions, 4 items from objects without positions (one object not in the pack at all), 5 kills of creatures without positions.

So ground and container pick-ups are about one in six of the cases; the biggest groups are items whose source we do not know and creatures (often rare or named ones) without spawn data.

## Why

The planner plans such an objective as done at the quest giver with no walking (the item about objectives with no position), and the guide step can only say "no position in the pack". Real positions fix both.

## Done when

- A gap list (ids only, no text from any database) of the creatures, objects and items whose position or source is missing for the quests the three guides use, ranked by how many guide steps they affect, is written by a tool into the private pack's data-gaps.md, ready for the user's exporter run.
- The positions the user's exporter finds enter the pack as a layer, and the counts above fall.
- Items with no known source: what they are (given by another quest, created by a spell, bought) is looked up the same way, so the planner knows which item no objective trip can find.
- The recorder logs where the game itself marks a quest's objective areas (the quest log map) for the quests in the log, if the Forever client offers it (probe `C_QuestLog.GetQuestsOnMap` and the map's quest POI API; VERIFY(beta)), so the user's and the friend's play fills the gaps for Forever's new quests.

## Notes

- Wowhead is off-limits to Claude Code: the user runs the exporter, and Claude works from ids and structure-only diagnostics.
- Related: the item about objectives with no position being planned as done at the giver (the interim charge), and the item about the recorder dropping the experience a turned-in quest paid (same recorder).

Open reading (2026-10-21): the user wrote "WowEd" for the database where entities can be searched; this item reads it as Wowhead, which was not confirmed. Wowhead stays off-limits to Claude Code either way: the gap list is for the user's own exporter run.
