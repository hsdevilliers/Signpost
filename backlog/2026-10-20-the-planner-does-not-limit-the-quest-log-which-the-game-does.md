---
title: The planner does not limit the quest log, which the game does
kind: finding
status: done
priority: low
area: planner
source: claude
raised: 2026-10-20
raised_in: Route Planner runs, PR #35
closed: 2026-10-21
resolution: WP-E1 (feat/planner-features): Settings.quest_log_limit = 40 (--quest-log N), confirmed by the user in the game 2026-10-21; every search respects it (Planner.offered, Planner.grind); the report shows the most quests held (planner and written route); measurements in docs/PLANNER.md. The reading of the client's own number (probe questLogMax, WP-D) is recorded in docs/FOREVER-API-NOTES.md by whoever merges it.
---

## What

The Route Planner does not limit the quest log. A planned route may hold more quests at one moment than the game allows (25 in Classic; the
limit in Forever is not known), and the report does not show the highest count a route reaches.

## Why

A guide that has the player accept a 26th quest sends them back to abandon or hand in something it never mentions.

## Done when

- The limit is known from the client: a probe (retail has `C_QuestLog.GetMaxNumQuestsCanAccept`; VERIFY(beta) that Forever does) recorded in
  `docs/FOREVER-API-NOTES.md`.
- The planner has a setting for it (default the verified limit) that keeps routes within it, and the report shows the highest count.

## Notes

- Quests a route accepts and never finishes are already taken out (`Planner.tidy`). This is about the quests it holds at one time.
- An independent review of the planned Troll Hunter guide (2026-10-20) found quests held for hours between accepting and handing in, because an
  accept costs the planner nothing: 6365 Meats to Orgrimmar accepted in chapter 5 and handed in 612 minutes later (giver and ender 118 yards
  apart), 851 for 359 minutes, 8370 and 8426 for 207, 1095 for 189. At most 15 quests were in the log at once there, so the limit is not what
  hurts yet; the long holds are.

- The limit (user, 2026-10-21): "I believe the quest log limit has been bumped up from 25 to 40 for WoW Forever"; then "accept a 40 quest cap for wow forever";
  then confirmed by him in the game. Settings.quest_log_limit is 40 (--quest-log N). The probe SignpostDB.probe.questLogMax (WP-D) reads it from the client; its
  output belongs in docs/FOREVER-API-NOTES.md.
- Measured (docs/PLANNER.md, Measurements): the written routes hold at most 16 / 15 / 11 quests (Troll, Skyborne, Tauren), far below 40; the limit still slows the
  search (Troll beam +16 min at 40) because it counts quests the search takes out again: the item the-quest-log-limit-counts-quests-the-search-takes-out-again.
