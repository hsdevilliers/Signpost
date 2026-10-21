---
title: Find my place: a guide slots in where the character is when the player starts using it
kind: feature
status: doing
priority: normal
area: engine, ui
source: user
raised: 2026-10-21
raised_in: the user, 2026-10-21 (batch 1, WP-B)
---

## What

From the user (2026-10-21): "We need a smart way to have the guide slot in at the appropriate level and place where a character is when a user decides to use it. So a use case is: there can be some level 32 character, and then at that point the user decides to start using the add-on. Then we should have one layer of automatically picking up where the person should start. If you feel confident about that, if we can check which quests they've done and pinpoint exactly where they are, then that would be awesome. I know there is a mechanism in the game for querying if quests have been done."

## Why

A player who installs Signpost on a character that is already level 17, or 32, would otherwise start at step 1 and be stopped by the first step that history does not satisfy (a quest they skipped, a trip, a note), or sit at step 1 of a guide that ends at level 30.

## Done when

- The first time a guide runs for a character that has no progress in it, the pointer is put on the step the character is probably at, from the quests of the guide that are done or in the quest log and from the level; a line in chat says where and why.
- The player can run it again on demand (the Journal's Route tab, `/signpost place`) and undo it.
- The constants are chosen by a re-runnable simulation over the shipped guides, and the numbers are in `docs/ENGINE.md`.
- Seen once in the real client with a character that has history (the Forever client's completed-quest list at login is an open probe).

## Notes

- Claude: built on `C_QuestLog.IsQuestFlaggedCompleted` through `ns.Context:QuestCompleted` (the per-quest query), the quest log and the level; it does not use the player's position (a possible improvement for a level-only guess).
