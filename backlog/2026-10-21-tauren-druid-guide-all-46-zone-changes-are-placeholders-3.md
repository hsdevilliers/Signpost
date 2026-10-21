---
title: Tauren Druid guide: all 46 zone changes are placeholders (3 Moonglade and 2 Eastern Kingdoms round trips)
kind: finding
status: open
priority: normal
area: guides, data
source: claude
raised: 2026-10-21
raised_in: review of the Tauren Druid planner route, batch 1 (WP-A2), 2026-10-21
---

## What

The installed Tauren Druid route (generation 2, docs/reviews/horde-tauren-druid-walk.md) has 46 zone changes, each a `.todo` + `.zone` placeholder: 30 say "the travel graph has no route yet", 16 "border ... has no crossing coordinates yet". Three pairs of them are Moonglade round trips (at levels 11, 18 to 19 and 20; 22 to 25 minutes each way in the planner's price) and two pairs cross the sea to the Eastern Kingdoms (Undercity and Silverpine at 20 to 22, Undercity and Hillsbrad at 28 to 29). Nothing in the guide says how to get there: on foot from Thunder Bluff to Moonglade (Teleport: Moonglade is unconfirmed), and by the Orgrimmar zeppelin to the Undercity.

## Why

The guide tells the player to change zone but not how, and the planner's travel times rest on distances the guide does not give. Same cause as "Zone changes in planned guides are placeholders: no crossings, flight paths or zeppelins in the data" (the Troll Hunter's 25) and the Skyborne guide's own item.

## Done when

The travel data (WP-F: crossings, flight paths, zeppelins, the way to Moonglade) is in, the Tauren route is planned again, and `python tools/guide_lint.py --strict` reports no travel placeholder in it.

## Notes

- Raised by the review of the Tauren Druid planner route (batch 1, WP-A2). The numbers are from generation 2 (61901c9).
