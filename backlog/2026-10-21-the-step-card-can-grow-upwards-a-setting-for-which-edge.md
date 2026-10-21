---
title: The step card can grow upwards (a setting for which edge stays put)
kind: feature
status: done
priority: normal
area: ui
source: user
raised: 2026-10-21
raised_in: the user, 2026-10-21, while playing
closed: 2026-10-21
resolution: Built (Journal Settings checkbox, /signpost grow up|down, StepFrame:SetGrowUp; the saved position is anchored at the edge the card grows from). Specs only: the real client has not shown it yet; the user is the first to see it in play.
---

## What

From the user (2026-10-21), asking for a setting for the step card: "please have the steps panel, or have a setting where you can either have the steps panel grow from
bottom up, or from top down. Currently, I have it positioned in the bottom left, so if it grows downward, then it moves out of the screen. I'd like it to grow upwards for my
setup."

The step card's height follows the step; it was anchored at its top, so a taller step moved its bottom edge down, off the screen for a card placed near the bottom.

## Why

A card placed at the bottom of the screen must be able to grow upward.

## Done when

- A setting chooses which edge of the card stays put (top: it grows down, the default; bottom: it grows up), in the Journal's Settings tab and as `/signpost grow up|down`.
- Switching it does not move the card; a drag keeps the choice; a reload keeps it; the secure item button beside the card follows the card's top edge.
- Specs, mutation-checked; docs/ENGINE.md says how.

## Notes

- Specs only: the real client has not shown it (the geometry is the client's; the mock models only anchors and offsets). The user is the first to see it in play.
