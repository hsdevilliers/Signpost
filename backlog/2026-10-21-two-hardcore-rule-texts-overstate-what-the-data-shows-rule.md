---
title: Two hardcore-rule texts overstate what the data shows (rule 1491's sources, the scripted bit)
kind: finding
status: open
priority: low
area: guides, tools
source: claude
raised: 2026-10-21
raised_in: batch 1, independent review R-tools
---

## What

The independent review R-tools (batch 1) found two statements that go beyond the data:

- Rule 1491 (Smart Drinks) says "four of five known sources are elite"; the pack has six sources of the item, five of them elite.
- `scripted` is QuestieDB's "needs event" bit (specialFlags bit 2). It may also mark exploration or other scripted completions, not only escorts and events; the note "enemies may come at you here"
  on 1086 (The Flying Machine Airport) may therefore be misleading for such a quest.

## Done when

- The rule text states the count the pack shows (the reason text appears in every generated guide's `#skipquest` line, so the guides are regenerated with it), and the `scripted` notes say "the data
  flags this quest as scripted (an escort or an event)" without claiming enemies; or a quest-by-quest check shows the claim holds.
