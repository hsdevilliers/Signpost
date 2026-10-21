---
title: Completeness default F 0.6, T 45 s: regenerate the three guides once, after batch 1 (the user's choice)
kind: task
status: open
priority: normal
area: planner, guides
source: user
raised: 2026-10-21
---

## What

The user chose (2026-10-21, answering the question in the session): **T = 45 s, F = 0.6**. After batch 1 lands, the Route Planner's completeness setting (`--completeness F --completeness-trip T`, off by default in batch 1) becomes the default with F = 0.6 and T = 45 s, and the three guides are regenerated once with it, in the same pass as the two HARDCORE items filed with it.

The user's standing rule (2026-10-21): "please only add more items to this batch if really needed. Otherwise, just place the resolved items on the backlog." So this is applied after batch 1, not inside it.

## Why

The Skyborne guide left out Infestation Investigation (92462) although it was accepted beside the step in hand (the finding `the-skyborne-guide-leaves-out-a-quest-offered-in-the-same`). The measurements in docs/PLANNER.md ("Measurements") show T = 45 s with F = 0.6 is the smallest setting that brings 92462 and its follow-up 92463 (The Cirrusfly Queen) into the Skyborne route: three quests finished (with Flutterfly Dust) and two more opened, play time 0.2% shorter (planner and full simulation); the Troll Hunter gains one small quest, the Tauren Druid none.

## Done when

- The defaults are F = 0.6 and T = 45 s in the planner's settings and in the `--completeness` help text.
- The three guides are regenerated in one pass (with the HARDCORE escort item) and the Skyborne chapters hold both quests: `Select-String -Path Guides\Chapters\windshaper-druid-*.lua -Pattern '^\s*\.accept (92462|92463)\b'` gives two lines.
- The "left out" lists are recounted for the final generations; lint --strict, `guide_sim --check` and `tools\check.ps1` are green.
- docs/PLANNER.md says what was chosen and why; the question item `completeness-which-values-of-f-and-t-should-be-the-defaults` is closed with the user's answer.

## Notes

- Compare play time only (the planner's headline total includes the class-quest charge).
- Needs batch 1 on main first (the setting exists only there).

Progress (the quick PR after batch 1, 2026-10-21): the default is F 0.6 / T 45 s in the planner and the Skyborne guide is planned again with it (92462 and 92463 are in; six quests added, none removed). Still to do, in the regeneration pass: the Troll Hunter (one small quest) and the Tauren Druid (none) planned again with it, and the left-out lists recounted. Close this item then.
