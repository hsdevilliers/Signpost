---
title: Planned druid guides lose the Moonglade wording the manifest rewrites gave the drafted ones
kind: finding
status: open
priority: normal
area: guides, tools
source: claude
raised: 2026-10-21
raised_in: WP-F travel data, batch 1
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
