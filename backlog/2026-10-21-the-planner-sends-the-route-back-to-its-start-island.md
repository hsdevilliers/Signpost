---
title: The planner sends the route back to its start island although the only ride off it is one-way
kind: finding
status: open
priority: normal
area: planner, guides
source: claude
raised: 2026-10-21
raised_in: WP-A1 regeneration with the island exit required, 2026-10-21
---

## What

With `"require": [95349]` in the Skyborne entry of tools/drafts.json the island part ends with the exit chain and the airship, and the zone lock keeps the route on
the island until the required work there is done. The island-side class quests The Great Ursera Spirit (94006) and Strength and Mercy (94638, kill Ur'endra) are not
required, so the route left the island without them and the written guide (thorough alt 2, commit "Skyborne Druid third generation") ends with a 14th chapter on Zephras
Isle at level 30: `.todo "Get from Ashenvale to Zephras Isle: they are on different continents, so you need a boat, a zeppelin or another ride, and the guide has no dock for it
yet"`. The airship in Guides/Travel/Borders.lua is `oneWay`: nothing in the data brings a player back, and the planner's rule that an island with no gateway cannot be reached
"unless the character begins there" lets the route come back to the island it began on.

## Why

A route that needs a ride the data does not have is not followable, and for a hardcore character going back to the start island at level 30 for a level 10 quest is a detour for nothing.

## Done when

- The planner does not plan a trip to a place with no known way there, even where the character began (an island whose only ride is one-way): the quests that start there are done before leaving or left out with a line.
- The Skyborne manifest requires 94638 as well (done: `"require": [95349, 94638]`, applied by the next regeneration); the beam test with it did both quests on the island at levels 10 and 11 and never returned.

## Notes

- Requiring the whole Bear Form chain (94911 and 94913 too) kept a beam test on the island for 13h20: the Mulgore part of that chain is the user's question "HARDCORE druid routes finish the Bear Form chain late".
