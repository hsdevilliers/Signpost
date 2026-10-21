---
title: Capital cities as one area: the planner and the guide do everything in the city in one block
kind: feature
status: open
priority: normal
area: planner, guides
source: user
raised: 2026-10-21
---

## What

The user's words (dictated, 2026-10-21): "Now I'm thinking of capital cities. I mean, if you get into a capital city, then you're going to need a lot more than 30 yards to do everything you need to do, since because you're essentially in the capital city. Does that make sense? Now, I think capital cities can be treated as a special case. Then it's not just what is around you, but everything in the capital city."

Today a capital is cut into several hubs of about 150 yards (the planner) and its steps are joined only within 250 yards (the step writer), so the trainers, profession teachers, vendors, quest NPCs and the boat or zeppelin of one city come out as several visits and several steps, and the planner charges a flat 8 seconds for walking between places of one hub.

## Why

In a capital everything the character needs at that level (class and profession trainers, quest hand-ins and pick-ups, vendors) is within one walk. The player expects one block in the guide ("in the city: ...") in a sensible order, and the planner should plan one trip with a realistic walk, not a string of small trips.

## Done when

- A capital (a map flagged as a city) is one area in the planner: one visit does every quest turn-in, pick-up and trainer step due at that level, and the walk inside is a tour through the real places (yards at running speed), not a flat 8 seconds.
- The step writer groups a city's steps into one block, in the order of the tour, with a pin for each place.
- Specs and a planner test; the Troll Hunter and Tauren routes show it; the full simulation agrees within the usual margin.

## Notes

- Related: the item about the Skyborne guide leaving out a quest offered in the same area (hub radius), and the profession tracks (trainer steps are inserted at `.hub` anchors).
- Not part of batch 1; to do after it.
