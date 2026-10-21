---
title: Markers stay behind after a quest is picked up or handed in
kind: finding
status: done
priority: normal
area: ui
source: user
raised: 2026-10-21
closed: 2026-10-21
resolution: PR #43: a .goto's marker goes once every quest asked at that place is accepted or handed in (Conditions:Targets, finishedGotos); specs, docs/ENGINE.md, docs/GUIDE-FORMAT.md
---

## What

The user's words (dictated, 2026-10-21): "after picking up Coming of Age, it creates a small square marker from the point where I picked up the quest. Same thing after handing it in. Why is that? I don't think that should be a thing. Those markers in my head should only indicate where you should be going next if needed, you know, only in the non-do quest part. Or am I wrong?"

The cause: `Conditions:Targets` always kept a step's `.goto` pins. When the quest was accepted or handed in, the quest giver's own pin went, but the generic "Go here" pin of the `.goto` stayed until the whole step was done.

## Why

A marker shows where to go next, never where the player has been. The user is right.

## Done when

A `.goto` whose place has nothing left to ask loses its pin as soon as every quest there is accepted or handed in; specs and docs (docs/ENGINE.md, docs/GUIDE-FORMAT.md "Step kinds") say so.
