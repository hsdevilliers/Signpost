---
title: Find my place could use the player's position as a second signal when there is no quest history
kind: feature
status: open
priority: low
area: engine
source: claude
raised: 2026-10-21
raised_in: batch 1, WP-B (Find my place)
---

## What

`Engine/Placement.lua` places a character by its level and the quests it has done or has in its log. It does not use where the character is standing. For a character with no quest history (or one that did not follow the guide) the position is a second signal: the zone and the part of the zone the player is in say which chapter of the guide they probably belong to, which the level alone only narrows to a few chapters (with no history the pointer is in the right level or the next, about 7 to 10 quest steps off at the median; docs/ENGINE.md has the numbers).

Possible shape: each step's first `.goto` / `.path` gives a map; the placement could add a term for the distance (in steps) between a candidate split and the nearest step whose `.goto` is in the player's map, weighted well below the history's and above the level's for the `level` mode only.

## Why

The user asked for the guide to "pinpoint exactly where they are". With history the placement does; without it (a boosted character, or the list not loaded) position is the only other evidence.

## Done when

Either the position is used and the simulation shows what it buys (the simulation would need positions: the `.goto` of the true step), or this is dropped with the numbers that say it is not worth it.

## Notes

`ns.Context:Map()` and `Position()` exist; a level-only placement waits a few seconds anyway, so the position is known by then. Loading screens and flights make the position noisy (a character on a boat).
