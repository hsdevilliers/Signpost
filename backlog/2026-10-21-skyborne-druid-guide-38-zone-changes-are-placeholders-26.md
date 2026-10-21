---
title: Skyborne Druid guide: 38 zone changes are placeholders (26 with no route, 12 with no crossing)
kind: task
status: open
priority: normal
area: guides, data
source: claude
raised: 2026-10-21
raised_in: review of the Skyborne Druid planner route (WP-A1), 2026-10-21
---

## What

The first generation of the Skyborne guide (planner route, 2026-10-21) has 38 zone changes written as `.todo` + `.zone`: 26 say "the travel graph has no
route yet" and 12 say "border ... has no crossing coordinates yet". There is no `.path`, `.fly`, `.boat` or `.zeppelin` in the guide. The legs that matter
most to a Skyborne: Mulgore and Thunder Bluff (four times, early), Thunder Bluff to Orgrimmar and the Barrens, the Barrens to Undercity and back (the
zeppelin, twice: levels 19 to 20 and 24 to 26), Silverpine, Hillsbrad and Tirisfal (Eastern Kingdoms), Thunder Bluff to Moonglade and Moonglade to
Ashenvale, the Barrens to Stonetalon, Ashenvale and Thousand Needles (borders). The way off Zephras Isle is a separate question (the item "How does a
Skyborne character leave Zephras Isle").

## Why

The guide tells the player to change zone and not how. The existing item "Zone changes in planned guides are placeholders" describes the same gap for the
Troll Hunter route.

## Done when

The travel data has the crossings and transport links these legs use (Borders.lua, learned crossings, zeppelins, flight paths), the regenerated guide has
travel steps for them, and `python tools/guide_lint.py --strict` reports no placeholder travel `.todo` for the Skyborne guide.
