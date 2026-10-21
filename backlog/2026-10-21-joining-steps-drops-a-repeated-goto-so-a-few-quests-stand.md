---
title: Joining steps drops a repeated .goto, so a few quests stand behind another NPC's .goto
kind: finding
status: open
priority: low
area: planner
source: claude
raised: 2026-10-21
raised_in: batch 1, WP-C (per-NPC pins)
---

## What

`tools/signpost_tools/steps.py` `group()` joins neighbouring pick-up and hand-in steps and, to avoid a repeated `.goto`, drops a `.goto` line that is already in the
joined step (`seen`). When an NPC comes up again after another NPC's lines, its directives are therefore appended behind the other NPC's `.goto`. A reproduction
(three steps `P1 accept 1`, `P2 accept 2`, `P1 accept 3`, all near each other) gives `.goto P1 / .accept 1 / .goto P2 / .accept 2 / .accept 3`: quest 3 stands behind
P2's `.goto` though its NPC is at P1.

In the shipped guides it is rare: against the data pack's NPC positions, 4 of the 425 `.accept`/`.turnin` lines in the 94 joined steps stand behind a `.goto` more
than 1% of the map from their NPC: `Guides/Chapters/barrens-10-20.lua` (`.turnin 892` and `.accept 888` stand behind the `.goto` of the NPC of 892's pick-up, where the
`.goto 1413,62.68,36.23` of their own NPC was dropped, and `.turnin 95495`) and `troll-hunter-06-undercity.lua` (`.turnin 97290`). (A scratch script read the chapter
text and the pack, nothing was changed.)

## Why

The engine marks each directive on the `.goto` that stands before it (batch 1, `Conditions:Targets`): without the data pack the pin of the wrong NPC then names the
quest, and the pin that should name it does not. With the pack the NPC pins are at the right places whatever the order.

## Done when

`steps.group` keeps the `.goto` of an NPC that comes up again (or writes the directives of a repeated NPC where its first lines are), with a test of the reproduction
above, and the shipped chapters are regenerated.

## Notes

The goto-dedupe exists so that a doing step keeps one position and a pick-up step does not repeat a place twice in a row; the change is to repeat a `.goto` only when
another `.goto` stands between its first and its second appearance.
