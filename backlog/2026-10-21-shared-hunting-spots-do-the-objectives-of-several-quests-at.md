---
title: Shared hunting spots: do the objectives of several quests at the spot that serves most of them
kind: feature
status: done
priority: normal
area: planner
source: user
raised: 2026-10-21
closed: 2026-10-27
resolution: PR #52: built as the shared-spots rule (open objectives with a spot within 100 yards are worked together across a hub line; an objective with spots in several hubs goes where more other quests are, at most 30 s away); mutation-checked tests; numbers and limits in docs/PLANNER.md, Stops together and shared spots. The model still prices each objective alone.
---

## What

The user's words (2026-10-21), after agreeing the fixes for the missing Infestation Investigation: "I assume the later shared hunting spots will be written up as a backlog item."

When an objective has spots in several places, the planner completes it at the first hub it reaches that has one, so a quest whose spots sit in two hunting grounds is done at the nearer one even when another open quest needs the farther one. Traced case (Skyborne start): Harmony in Balance (92461) has kill spots in hubs 566 and 570 and was done at the 566 spot; Infestation Investigation (92462) has spots only in hub 570, 21.9 s of travel east, so it needed a separate trip that the route never made (about 1.96 XP/s against 2.46 for the next area). Done together at the east spot, one trip would have served both: the planner cannot choose that today.

This holds for every kind of objective, not only kills: items dropped by creatures, items in containers or on the ground, objects to use, areas to reach. A ground pick-up beside a kill area is the cheapest quest of all to share.

## Why

Players (and human guide writers) do everything that lives in one hunting ground in one trip: accept the quests first, then clear the area. The planner's per-quest, first-spot choice is what makes it leave nearby quests half done.

## Done when

- The planner chooses, for an objective with spots in several hubs, the spot that also serves another open (or about to be opened) quest, so one trip does both; for every objective kind.
- A planner test with a fixture (one quest with spots in two hubs, a second only in the farther one) fails today and passes; mutation-checked.
- The numbers on Troll, Tauren and Skyborne (quests added, planner and simulated time change); the Skyborne route does 92461 and 92462 together at the east spot if the totals improve.
- It works with the completeness setting of the item about the Skyborne guide leaving out a quest offered in the same area, not instead of it.

## Notes

- Design note requested from the planner worker (E1 of batch 1); the implementation comes after that item.
- Related: capital cities as one area (a different problem: steps and walking inside a city).
