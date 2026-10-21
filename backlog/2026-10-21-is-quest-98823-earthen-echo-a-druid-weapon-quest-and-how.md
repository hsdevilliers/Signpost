---
title: Is quest 98823 (Earthen Echo) a druid weapon quest, and how would we know?
kind: question
status: open
priority: normal
area: guides, data
source: claude
raised: 2026-10-21
raised_in: review of the Tauren Druid planner route, batch 1 (WP-A2), 2026-10-21
---

## What

Fan sites name a Horde druid weapon quest called "Earthen Echo" at about level 24 (docs/CLASS-QUESTS.md, "Other classes and weapon quests"). The data has one quest by that name, 98823: it starts with Bashana Runetotem in Thunder Bluff and ends with Muln Earthfury in Mulgore, and it is a level 31 quest that opens at level 24. Nothing in the data says it is a druid's.

The first review of the Tauren Druid route (2026-10-21) guessed that it is, and wrote it into `Classes/DRUID.lua` as a mandatory class chain and into the HARDCORE rules as a skip. The lead took both out the same day: a guess must not become a mandatory class quest, because the lint would then force the route to include a quest druids may not get, and a route is valid only if the game offers every quest where the guide accepts it.

## Why

CLAUDE.md makes every class quest mandatory content. If 98823 is the druid's weapon quest, the Tauren guide has to route it or skip it with a written reason; if it is not, it must never become a class chain. Today nobody knows. The Tauren route (levels 1 to 30) does not touch it either way: it is a level 31 quest, beyond what a HARDCORE route takes at the cap.

## Done when

A druid (the user's, or the friend's who plays one on hardcore) has been offered it, or demonstrably has not, at level 24 or later. The offer shows in the recorder's data: `Core/Learn.lua` records the quests a character accepts and turns in, `Core/Debug.lua` what a giver offered (docs/AVAILABILITY.md), and `python tools/read_savedvars.py` reads both. Then:

- if it is the druid's: add a class chain to `Classes/DRUID.lua` with the real quest ids and levels (and the rest of the weapon chain), and route or skip it in the Tauren guide;
- if it is anyone's: nothing changes.

## Notes

- Related: "Thin Forever quest records and chains the pack cannot order: verify in play and correct" lists 98823 among the probably class-locked ones.
- Raised by the review of the Tauren Druid planner route (batch 1, WP-A2).
