---
title: The planner does not limit the quest log, which the game does
kind: finding
status: open
priority: low
area: planner
source: claude
raised: 2026-10-20
raised_in: Route Planner runs, PR #35
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
