---
title: Skyborne Druid guide: the Moonglade trips and the Cat Form relics are placeholders
kind: task
status: open
priority: normal
area: guides, planner, data
source: claude
raised: 2026-10-21
raised_in: review of the Skyborne Druid planner route (WP-A1), 2026-10-21
---

## What

- The two Moonglade legs (Thunder Bluff to Moonglade, Moonglade to Ashenvale) are "the travel graph has no route yet". The knowledge of the old drafted
  chapters (Teleport: Moonglade, VERIFY(beta); the hearthstone or a flight node back) is now only the note on 94913 in tools/hardcore_rules.json.
- The three relics of 98404 (Relic of the Fang, near 72.4,66; the Claw, near 75.2,67.2; the Silent Shadow, near 74.4,65.4, all in Moonglade) are three
  `.todo` steps ("objective N is only in places this guide does not go"): the planner treats Moonglade as a zone nobody quests in, although the Cat
  Form chain and its trip are mandatory. The note on 98404 gives the positions and the danger (spirits attack on sight, per fan guides).
- The `rewrites` of the Skyborne entry in tools/drafts.json (the Teleport texts) are dead configuration: the planner's install replaces only the
  `#include` and `#skipquest` lines and applies no rewrites.

## Why

Cat Form is a mandatory class quest and the relic fight is the dangerous part of it.

## Done when

- The travel data has the Moonglade links; the planner routes the relic objectives (an area it visits for the class quests anyway), so the steps carry
  the positions; the old rewrites are removed or applied.
- Verified in play: how a Windshaper gets to Moonglade and back (docs/FOREVER-API-NOTES.md, open probe "Druid forms in Forever").
