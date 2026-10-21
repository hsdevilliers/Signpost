---
title: The recorder drops the experience a turned-in quest paid (QUEST_TURNED_IN has it): record it
kind: feature
status: open
priority: normal
area: core, tools
source: claude
raised: 2026-10-21
---

## What

The game tells the addon how much experience a turned-in quest paid: `QUEST_TURNED_IN` carries (questID, xpReward, moneyReward), and the user's first Skyborne session shows it in the debug event log (Coming of Age, 92460: 40 XP). `Core/Learn.lua` handles QUEST_TURNED_IN with the quest ID only, so the experience is thrown away.

## Why

New Forever quests have no experience in the data pack (`unknown_xp`); the Route Planner values them at a tenth of a level, a guess that decides, for example, whether a quest near break-even is finished or left out. The user's play and the friend's hardcore-druid data collection would turn those guesses into numbers at no cost to the player.

## Done when

- The recorder keeps the experience a quest paid (with the character's level at the time, since the reward can depend on it) in the learned data, without names or chat.
- `tools/signpost_tools/learned.py` and the data pack import carry it into the pack's quest experience, and the planner uses it instead of the guess; a tool test covers the round trip.
- The opt-in rules of the recorder are unchanged.

## Notes

- Related: the item about the Skyborne guide leaving out a quest offered in the same area (the valuation of quests with unknown experience), and the profession recorder, which touches the same recorder.
