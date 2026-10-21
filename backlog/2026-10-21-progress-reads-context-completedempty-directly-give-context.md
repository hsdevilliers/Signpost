---
title: Progress reads Context.completedEmpty directly: give Context a public history-loaded query
kind: finding
status: open
priority: low
area: engine
source: claude
raised: 2026-10-21
raised_in: batch 1, WP-B (Find my place)
---

## What

`Progress:Place`'s wait for the quest history (`historyReady` in `Engine/Progress.lua`) reads `ns.Context.completedEmpty`, a field `Engine/Context.lua` keeps for itself (set when the completed-quest list is loaded, true when it came back empty). It works, but Progress reads another module's internals, and the rule it applies (the list loaded and non-empty, or something in the quest log) belongs to Context.

## Why

If Context changes how it loads the list (a probe on Forever may force that: when is `GetAllCompletedQuestIDs` filled?), Progress would break without a spec failing in Context.

## Done when

`ns.Context` has a public `HistoryLoaded()` (or similar) with the rule and a spec, and `historyReady` calls it. Do it together with the verify item on Find my place, once the real behavior at login is known.

## Notes

Left alone in batch 1 because `Engine/Context.lua` may be touched by the quest-tracking work (WP-D) at the same time.
