---
title: Forever's new quests have no class in the data, so other classes' quests are routed
kind: finding
status: open
priority: normal
area: data, planner
source: claude
raised: 2026-10-21
raised_in: review of the Tauren Druid planner route, batch 1 (WP-A2), 2026-10-21
---

## What

The data gives Forever's new quests (ids 60000 and up) no class, so the rules that keep another class's quests out of a route (`availability.mask_block`, the planner's "other class" drop) cannot see them. The planner guesses a class from the giver's other quests when at least three of them belong to one class (`Planner._inferred_class`); that caught Chakuyak (a Hunter's), but not quests whose giver has fewer than three.

The first review of the Tauren Druid route (2026-10-21) found four such quests in a druid's route: 98251 Never Coming Back and 98252 A Void Path (Va'xug Firefure, Ashenvale; the second ends at the Eye of Kilrogg) and 65601 Love Hurts (Cazul, Orgrimmar), all probably Warlock quests, and 99108 Sparring Match (Krang Stonehoof, the Tauren warrior trainer, Mulgore), probably a Warrior's. The Troll Hunter guide installed today carries 98251, 98252 and 65601; so does the Skyborne guide. Three more, the chain "Stalk With The Earthmother" (Thunder Bluff, 76156, 76160, 76240), may belong to a class too; the evidence is too thin to skip them, so they stay routed.

A stopgap exists since this change: a rule in tools/hardcore_rules.json may say `class_quest_of` (a class token), and then it skips the quest for the guides of every other class and leaves it to that class's own (docs/HARDCORE.md). It is a guess from names, written by hand per quest.

## Why

A step the game does not offer to the character stalls the player (they must skip it by hand), and a route is valid only if the game offers every quest where the guide accepts it (docs/AVAILABILITY.md). More classes' guides (Orc Warlock, Tauren Shaman) will meet the same quests from the other side.

## Done when

Forever's quests carry a class in the data: the pack builder or the learned layer gives a quest the class of the characters that were offered it in recorded visits (`Core/Debug.lua` records what a giver offered, `tools/validate_availability.py` replays it), or the planner infers it from the giver's own data (a class trainer's quests). The hand-written `class_quest_of` rules then drop out.

## Notes

- Area: data, planner. Related: "Thin Forever quest records and chains the pack cannot order: verify in play and correct".
- Raised by the review of the Tauren Druid planner route (batch 1, WP-A2).
