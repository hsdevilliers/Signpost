---
title: The pack has no rank for any Forever creature: named bosses pass the HARDCORE elite rule
kind: finding
status: open
priority: normal
area: data, planner
source: claude
raised: 2026-10-21
raised_in: review of the Skyborne Druid planner route (WP-A1), 2026-10-21
---

## What

The NPC `rank` is the HARDCORE criterion for an elite or boss objective (docs/HARDCORE.md). In the pack of 2026-10-20 none of the 419 NPCs with an id of
60000 or more (the Forever-new ones) has a rank, against 927 of the 3,790 older ones; 102 kill objectives of the 637 Forever-new quests aim at such
creatures. To the planner a Forever boss is an ordinary kill. The reviews skipped some by hand (Rath'mael 92422, Bruuz 92706, Chol'aruk 97003, in the
Tauren worker's rules) and left others routed with a note or nothing: Ur'endra (94638, the Skyborne Bear Form trial), Urs'anah (92470 Foul Matriarch, a
level 5 island boss), Commander Haalien (94488), Ferauu the Bludgeon (92693).

## Why

The guides are HARDCORE routes. A named Forever boss that the data cannot flag is only found by a person reading the quest names.

## Done when

- A source of ranks for Forever creatures is merged into the pack (the client's creature classification recorded in play by Core/Learn.lua, or whatever
  QuestieDB's Forever layers carry), and the HARDCORE rule uses it.
- Until then the HARDCORE rule treats a named kill target with no rank as suspect (a generated note or a reviewed skip list), and the hand-written
  rules say so in their `source`.

## Notes

- "Named" is a guess from the name (no creature-type noun); the scratch script that listed 43 such quests for the Skyborne route is not in the repository.
