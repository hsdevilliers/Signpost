---
title: The druid guides from planner routes, levels 21 to 30, and the empty Cat Form chapter
kind: task
status: open
priority: normal
area: guides, planner
source: claude
raised: 2026-10-20
raised_in: independent review of the installed Troll Hunter guide, 2026-10-20
---

## What

The Tauren and Skyborne Druid guides stay drafted chapters to level 20 (levels 21 to 30 and the Skyborne's 12 to 20 are not written), and
`druid-cat-form-20.lua` has no step. Version 1 of every guide stops at 30. The planner can make the routes (`python tools/route_planner.py
tauren --preset all`, `skyborne`). With the beam that compares routes by how far they have got (PR #38) the Cat Form chains come at or soon after
the level they open at: the default beam makes the Skyborne route 28h52 (22h59 of play and 4h20 of charges for class quests done late; a start on
an island has no way to the other continents' class quests before it leaves) and the Tauren route 44h40 (24h57 of play and 17h40 of charges for 22
class quests: the planner's charge is 20 minutes a level a quest, and the druids' chains are long). Before it the beam did them at 27 to 30 and
the Skyborne's beam found no route of its own.

## Why

The druid guides are two of the three Release 1 guides, and they stop at 20.

## Done when

The druid routes from the planner are reviewed the way the Troll Hunter's was (an independent walk of the guide as a player), fixed, and installed
with `--install`; the Cat Form chain's timing is understood (its items, the Moonglade trips).
