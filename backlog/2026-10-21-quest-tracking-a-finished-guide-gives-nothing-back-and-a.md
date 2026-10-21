---
title: Quest tracking: a finished guide gives nothing back, and a restored tracker may differ in order
kind: finding
status: open
priority: low
area: engine
source: claude
raised: 2026-10-21
raised_in: batch 1 WP-D (branch feat/quest-tracking)
---

## What

Two limits of the quest tracking module (Engine/Tracking.lua) that batch 1 left as they are:

1. A guide that reaches its last step has no end state: the last step stays current, the module keeps following it, and the
   player's earlier tracking is not given back. It is given back only when the setting is turned off or a guide choice leaves
   no guide active.
2. The restore cannot reorder: the client only appends a quest to the tracker, so the quests given back come after the ones that
   stayed tracked, and the tracker's order can differ from the order the player had.

## Why

Both are cosmetic or rare: the last step of a version 1 guide is the level 30 end, and the order of the tracker matters little.
They were found while writing the state machine and are not worth more code before the client's real behaviour is known.

## Done when

Either the user says the limits are fine, or the module gives the earlier tracking back when the last step is done (it needs an
end-of-guide signal from the step engine, which does not exist yet) and the order is documented as a known limit.

## Notes

The restore is `Tracking:Release`; the reading of "the guide ends" as "no guide is active" is written in docs/ENGINE.md
(Engine/Tracking.lua, "Giving back").
