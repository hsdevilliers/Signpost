---
title: Profession track data is pinned by almost nothing: trainer positions and skill goals can drift unnoticed
kind: finding
status: open
priority: normal
area: guides, tools
source: claude
raised: 2026-10-21
raised_in: batch 1, independent review R-engine-2
---

## What

The profession tracks (`Guides/Professions/*.lua`) carry trainer positions and skill goals, and almost nothing pins them: moving the Cooking trainer's `.goto` from y 53.96 to 13.96, or the
Fishing goal from 75 to 150, leaves every spec green (independent review R-engine-2 of batch 1, mutants T5 and T6). CI runs the guide lint without the data pack, so a trainer position is
never compared with the pack; only Skinning steps 1 and 2 have pinned values (`tests/profession_tracks_spec.lua`, about lines 448 and 492). The reviewer compared all eight trainer records
with the pack by hand and they match today.

## Why

The tracks are hand-written from pack data; a slip in a coordinate or a number would ship unnoticed.

## Done when

- A lint rule (it runs with the pack) says that a `.trainprof` step's `.goto` lies within a few yards of a trainer NPC of that profession in the pack (the NPC title pattern WP-G1 used), with
  a fixture test in `tools/tests`; and the skill goals are pinned (or derived from the profession modules' rank caps and checked against them).
