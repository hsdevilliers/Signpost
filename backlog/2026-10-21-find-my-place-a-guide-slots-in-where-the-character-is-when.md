---
title: Find my place: a guide slots in where the character is when the player starts using it
kind: feature
status: done
priority: normal
area: engine, ui
source: user
raised: 2026-10-21
raised_in: the user, 2026-10-21 (batch 1, WP-B)
closed: 2026-10-21
resolution: batch 1 (WP-B, branch feat/find-my-place): Engine/Placement.lua with constants chosen by a simulation over the shipped guides (numbers and the re-run command in docs/ENGINE.md), Progress:Place at first use (waiting for the quest history, a timer fallback, one second look), for a lost saved step and on demand, the Journal's Find my place button, /signpost place with < to take it back, /signpost reset progress. Not seen in the game yet: the verify item; the marking question and the re-run are items of their own.
---

## What

From the user (2026-10-21): "We need a smart way to have the guide slot in at the appropriate level and place where a character is when a user decides to use it. So a use case is: there can be some level 32 character, and then at that point the user decides to start using the add-on. Then we should have one layer of automatically picking up where the person should start. If you feel confident about that, if we can check which quests they've done and pinpoint exactly where they are, then that would be awesome. I know there is a mechanism in the game for querying if quests have been done."

## Why

A player who installs Signpost on a character that is already level 17, or 32, would otherwise start at step 1 and be stopped by the first step that history does not satisfy (a quest they skipped, a trip, a note), or sit at step 1 of a guide that ends at level 30.

## Done when

- The first time a guide runs for a character that has no progress in it, the pointer is put on the step the character is probably at, from the quests of the guide that are done or in the quest log and from the level; a line in chat says where and why.
- The player can run it again on demand (the Journal's Route tab, `/signpost place`) and undo it.
- The constants are chosen by a re-runnable simulation over the shipped guides, and the numbers are in `docs/ENGINE.md`.
- Seen once in the real client with a character that has history (the Forever client's completed-quest list at login is an open probe): tracked in the item "Find my place in the game: placed at login? ..." (kind verify).

## Notes

- Claude: built on `C_QuestLog.IsQuestFlaggedCompleted` through `ns.Context:QuestCompleted` (the per-quest query), the quest log and the level; it does not use the player's position (a possible improvement for a level-only guess: the item "Find my place could use the player's position ...").
- Built in batch 1 (WP-B): `Engine/Placement.lua`, `Progress:Place` and the hooks in `Engine/Progress.lua`, the Journal's "Find my place" button, `/signpost place`, `/signpost reset progress`, `tests/placement_spec.lua`, `tests/progress_placement_spec.lua`, `tests/helpers/placement_sim.lua`, `tools/placement_report.py`; the algorithm and the numbers are in docs/ENGINE.md. Open: how the steps behind the pointer are marked when it cannot tell (a question for the user), re-running the simulation when the druid guides are regenerated, and the real client.
