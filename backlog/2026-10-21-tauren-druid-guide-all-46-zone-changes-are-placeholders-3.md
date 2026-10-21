---
title: Tauren Druid guide: 26 zone changes are placeholders (3 Moonglade and 2 Eastern Kingdoms round trips)
kind: finding
status: open
priority: normal
area: guides, data
source: claude
raised: 2026-10-21
raised_in: review of the Tauren Druid planner route, batch 1 (WP-A2), 2026-10-21
---

## What

The installed Tauren Druid route (generation 3, 807be15, docs/reviews/horde-tauren-druid-walk.md) has 26 zone changes that are a `.todo` + `.zone` placeholder (44 travel steps in all: the other 18 are real flight paths and flights). Travel is 11h15 of its 27h43. Six placeholders are three Moonglade round trips (levels 11, 20 to 22 and 30; 20 to 26 minutes each way in the planner's price; worded "cast Teleport: Moonglade if you have it ... Do not walk it" since WP-F), eight are two trips to the Eastern Kingdoms (Undercity at 19 to 20, Silverpine, Undercity and Hillsbrad at 22 to 25; four of them say "they are on different continents"), and twelve are walks inside Kalimdor. Nothing in the guide says how to get there: Teleport: Moonglade is unconfirmed, and nothing says how to reach the Undercity (the Orgrimmar zeppelin, as I remember Classic).

## Why

The guide tells the player to change zone but not how, and the planner's travel times rest on distances the guide does not give. Same cause as "Zone changes in planned guides are placeholders: no crossings, flight paths or zeppelins in the data" (the Troll Hunter's 25) and the Skyborne guide's own item.

## Done when

The travel data (WP-F: crossings, flight paths, zeppelins, the way to Moonglade) is in, the Tauren route is planned again, and `python tools/guide_lint.py --strict` reports no travel placeholder in it.

## Notes

- Raised by the review of the Tauren Druid planner route (batch 1, WP-A2). Generation 2 (61901c9) had 46 placeholders (three Moonglade and two Eastern Kingdoms round trips as now); the numbers above are generation 3's, counted in the chapters.
