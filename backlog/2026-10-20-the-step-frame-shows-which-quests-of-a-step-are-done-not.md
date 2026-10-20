---
title: The step frame shows which quests of a step are done, not each quest's progress
kind: feature
status: open
priority: normal
area: ui, engine
source: user
raised: 2026-10-20
raised_in: the user, 2026-10-20, dictated while the Route Planner was being merged
---

## What

From the user (2026-10-20), as part of the activity-step change (see the steps item): the guide does not track the progress of a quest
inside a step. The step frame lists the quests of the current step and which of them are complete, and when all of them are complete the
guide moves on to the next step (typically handing them in). Objective counts and partial progress are left to the quest log.

## Why

"The quest log is awesome as it is": the game already shows the progress of every objective in the log, the tracker and on the map.
Repeating it in the step frame adds clutter and one more place to be wrong.

## Done when

- The step frame lists the quests of a doing step with a done mark each and no objective counters.
- The step completes when every quest in it is complete in the quest log (`Context.questLog[id].complete`), and the frame moves on.
- A step with one quest reads the same as a step with five.

## Notes

- Check what `UI/StepFrame.lua` shows for `.complete` today before changing it.
- `.complete <quest>,<objective>` exists now. Whether the per-objective form stays (for a step that needs one objective of a quest and not
  the rest) is decided in the steps item.
