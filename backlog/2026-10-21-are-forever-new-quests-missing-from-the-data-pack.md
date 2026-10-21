---
title: Are Forever-new quests missing from the data pack? Compare what the game offered with the pack and the guides
kind: question
status: done
priority: normal
area: tools, data
source: user
raised: 2026-10-21
raised_in: the user's early test of the Skyborne HARDCORE guide, 2026-10-21
closed: 2026-10-21
resolution: tools/audit_quests.py (batch 1, WP-E2) reads the quests the game offered in recorded play (events, learned records) through tools/read_savedvars.py, looks each up in the pack and in each guide, and lists data gaps and route gaps with the rule that explains them (docs/AVAILABILITY.md). First run, on the dev client's recorded session (6 distinct quests, 189 events): 0 data gaps; the three Troll quests are routed; the Skyborne quest 92462 is left out on purpose with its numbers (its work pays 71% of the route's pace; completeness 0.71 or less would finish it). Re-run it on the friend's SavedVariables (`--from incoming/play-machine`) when they arrive; a data gap found then gets its own item.
---

## What

The user's words (dictated, 2026-10-21): "It can be because it's a Skyborne new quest that we missed it somehow due to incomplete data, or it's plainly a great shortcoming in our guide planner." For Infestation Investigation (92462) the pack has the quest, so that one is the planner (see the item about the Skyborne guide leaving out a quest offered in the same area). Whether the pack misses other Forever-new quests has never been checked against what the game actually offers.

## Why

The Forever layer of the pack comes from the client's dumps and positions learned in game; the QuestieDB layer is a Classic baseline. A new Skyborne, class or zone quest absent from both would be absent from every route, and nothing in the planner would say so.

## Done when

- A tool (or a section of an existing one) reads the quests the game offered during recorded play (QUEST_DETAIL and QUEST_ACCEPTED events and the learned NPC records in a SavedVariables file, via `tools/read_savedvars.py`) and looks each one up in the pack and in the guides.
- It lists the quests missing from the pack (a data gap) and those in the pack but not in the guide (a planner or rule gap, with the reason), and the result is written in the item's resolution.

## Notes

- The friend's hardcore-druid SavedVariables (import path) are the natural second source.
- First data point (2026-10-21, from the lead): the five distinct quests the user's characters accepted in their first Skyborne/Troll session
  (92460, 92461, 92462, 92463 and 97279) are ALL in the pack's Quests.lua. So the Infestation Investigation omission (92462) is the planner, not the
  data. The full audit (every accepted quest of a recorded session against the pack and the guides) is still open.
