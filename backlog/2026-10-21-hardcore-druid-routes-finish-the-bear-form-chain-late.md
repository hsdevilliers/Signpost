---
title: HARDCORE druid routes finish the Bear Form chain late (Moonglade at level 20 to 24)
kind: question
status: open
priority: normal
area: planner, guides
source: claude
raised: 2026-10-21
raised_in: review of the Skyborne Druid planner route (WP-A1), 2026-10-21
---

## What

The Skyborne route's Bear Form chain is finished late: 94913 "Moonglade" (opens at 10, turned in at Dendrite Starblaze in Moonglade) is handed in at level 20
in the first generation (PR #42) and at level 24 in the generation made on 2026-10-21; the Cat Form chain (opens at 20) comes with it, at 24 and 25. The
planner's push for a class quest is 20 minutes for each level it is undone past the level it opens at, and the push stops growing after six levels
(`class_levels`), so a quest that is more than six levels late costs the same at level 16 as at level 24 and goes where the route finds it cheapest.
docs/HARDCORE.md calls Bear Form (level 10) "the early survival tool" of a hardcore druid, and the drafted guides it replaced did the Moonglade trip at about
levels 10 to 13. Where the Windshaper's Bear Form comes from (the reward of 94638 on the island at level 10, or of 94913 in Moonglade) is not in the data.

## Why

For a hardcore druid the question is not minutes but survival: a route that holds the Bear Form trip until level 24 may leave the character without its best
defensive tool for fourteen levels. The closed item "When is a class quest due?" (the user: no deadline, a soft push) was decided for the Troll and Tauren
routes without this view.

## Done when

- The user says when the Bear Form chain should be done on a HARDCORE druid route (as soon as it opens, by level 13, ...).
- The planner can say so per chain (a `due` level on a `classQuests` entry that the push honours without the six-level cap, or a larger push for that chain),
  with a test, and the regenerated Skyborne and Tauren guides do the Moonglade trip for Bear Form at that level.
- Where the Windshaper learns Bear Form is verified in play (docs/FOREVER-API-NOTES.md, open probe "Druid forms in Forever").
