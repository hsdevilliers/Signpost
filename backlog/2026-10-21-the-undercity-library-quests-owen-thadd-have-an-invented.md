---
title: The Undercity library quests (Owen Thadd) have an invented level and a guessed reward: what do they give?
kind: verify
status: open
priority: normal
area: data, guides
source: claude
raised: 2026-10-21
raised_in: review of the Tauren Druid planner route, batch 1 (WP-A2), 2026-10-21
---

## What

Six Forever quests of Owen Thadd in the Undercity (78127 The Dalaran Digest, 78143 Secrets of the Dreamers, 78149 Fury of the Land, 79096 Ataeric: On Arcane Curiosities, 79097 Baxtan: On Destructive Magics, 78150 Friend of the Library) are collect-a-book quests. The data gives them level 20 for a required level 1 and no reward, so the Route Planner gives each 10% of level 20 (2,320 experience, six together 13,900), and the Tauren route (and the Skyborne's) crosses the sea to the Undercity at level 20 for them among other quests.

## Why

If the real reward is small, or the real level is 1, the trip costs 25 minutes of travel and a continent change for little, and the HARDCORE route walks into Eastern Kingdoms zones for it. If it is large, the route is right to go.

## Done when

Someone with a character in the game says what one of these quests shows in the quest log (its level) and gives on turn-in (its experience at a known level): the user, or the friend, or the recorder (`Core/Learn.lua` records quests accepted and turned in; `QUEST_COMPLETE` knows the experience reward). The data or the learned layer is corrected and the Tauren and Skyborne routes are planned again.

## Notes

- Related: "Thin Forever quest records and chains the pack cannot order: verify in play and correct".
- Raised by the review of the Tauren Druid planner route (batch 1, WP-A2); the Skyborne worker saw the same invented levels.
