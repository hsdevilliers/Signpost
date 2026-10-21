---
title: Planned druid guides lose the Moonglade wording the manifest rewrites gave the drafted ones
kind: finding
status: done
priority: normal
area: guides, tools
source: claude
raised: 2026-10-21
raised_in: WP-F travel data, batch 1
closed: 2026-10-21
resolution: branch feat/travel-data (batch 1, WP-F, upgraded to MUST-FIX by the independent guide review): the generator now owns the Moonglade wording for every druid guide, drafted or planned. Classes/DRUID.lua travelHints (uiMapID 1450) holds the words; tools/guide_travel.py writes, for a trip to or from Moonglade that would be a walk over a border (or has no route), the old wording (cast Teleport: Moonglade if you have it, VERIFY(beta) where it is learned, else the way is not in the data; the way back: hearthstone or flight path) plus a .note that the road is not safe at the character's level and must not be walked overland (from Classic memory: Felwood or Winterspring, levels 48 and up), with the same .zone so the step is still done on arrival; a real flight or hearth stands. The manifest's dead Moonglade rewrites are removed. The game verification (the spell, the way back) stays in the question does-a-forever-druid-get-teleport-moonglade-at-what-level-by; what a druid without the spell does is the new question what-does-a-druid-without-teleport-moonglade-do.
---

## What

Only `tools/rebuild_drafts.py` applies the manifest's `rewrites` (`tools/drafts.json`), and only to guides not marked `planned`. The
Route Planner's install never does. So a planned Tauren or Skyborne guide shows the generator's generic placeholder at its Moonglade
trips ("Walk from Thunder Bluff to Moonglade: the guide has no waypoints for this yet, so find your own way. ...") where the drafted
chapters said "Go to Moonglade: cast Teleport: Moonglade (VERIFY(beta): where a druid learns it; docs/CLASS-QUESTS.md), else the way is
not in the data" and "Return from Moonglade to X (VERIFY(beta): hearthstone or flight path; ...)".

## Why

The druid hint is the only thing the player gets about how to reach Moonglade, and it carries the open question (is Teleport: Moonglade a
trainer spell or a quest reward on Forever?). The planned guides lose it without anyone deciding to.

## Done when

- The planned druid guides' Moonglade steps carry a class hint: the install applies the manifest rewrites, or the generator takes per-zone
  hints from a data file in `Guides/` (the seam keeps class names out of the tools).
- What Forever really offers (the spell, a flight path, walking) is verified in the game (docs/CLASS-QUESTS.md, docs/FOREVER-API-NOTES.md).

## Notes

Written up by WP-F, 2026-10-21. The four rewrite regexes in `tools/drafts.json` now accept the old and the new placeholder wording (a spec
applies them to the generator's own text), so a drafted rebuild is not affected by the wording change.
