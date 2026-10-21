---
title: Objectives with no position in the data are planned as done at the quest giver, with no walking
kind: finding
status: open
priority: normal
area: planner
source: claude
raised: 2026-10-21
---

## What

Found while checking, at the user's request (2026-10-21), whether the planner treats pick-ups from the ground like kills: it does, with one bias. An objective with no position in the data pack is planned as worked at the quest giver's place: `Planner._index` uses `o.spots or q.start_places`, the objective's hubs fall back to the giver's hubs, and `_quest_rate` adds walking only for objectives that have spots. So the quest costs no walking in the plan and is completed in the same visit as its pick-up. In the game the player has to find the creatures or items, and the step says so (`.todo "<quest>: objective 1 has no position in the pack"`).

Size today: the installed Skyborne guide has 24 such steps, the Troll Hunter guide 21 (older shared chapters: Barrens 5, druid forms 3, Mulgore 2). New Forever ground items and creatures are the likeliest to lack positions.

## Why

These quests look cheaper than they are, which pulls the planner towards them and hides the real time; the guide then sends the player to look for something with no marker.

## Done when

- A policy for objectives without a position: for example a search-time charge per such objective (a setting, with a default chosen from the numbers) and a mark in the planner report listing the quests that carry it.
- A planner test (a quest with an objective without spots next to one with spots) and the numbers on the three guides (quests that change, time change).
- docs/PLANNER.md says how such objectives are planned.

## Notes

- The positions arrive over time from the recorder (learned positions in the pack); the charge should fall away when a position is known.
