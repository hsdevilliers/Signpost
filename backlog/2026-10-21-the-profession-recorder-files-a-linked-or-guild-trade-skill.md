---
title: The profession recorder files a linked or guild trade skill window if no foreign-window function exists
kind: finding
status: open
priority: normal
area: recorder
source: claude
raised: 2026-10-21
raised_in: batch 1, independent review R-engine-2
---

## What

`Core/LearnProfessions.lua` (`foreignWindow`, about lines 415 to 422) decides that a trade skill window is someone else's (a linked recipe list, a guild member's) by asking four client
functions. If none of the four exists on Forever it answers "not foreign", so a linked or guild window would be recorded as the character's own, with the owner's skill stored as the
character's. That is data corruption in the learned layer, not a privacy leak (no name is read). Found by the independent review R-engine-2 of batch 1 and confirmed with a mutant.

## Why

The recorder is meant to be handed to a friend and left running; opening a linked window is rare but possible, and a wrong skill value skews the colour thresholds the importer infers.

## Done when

- `/signpost probe` (the recorder section) has shown which of the four functions exist on Forever. If none does, the recorder uses another signal (the window's own "is linked" state) or
  fails closed (records nothing it cannot show is the player's own), and a spec covers the case "no foreign-window function exists".
