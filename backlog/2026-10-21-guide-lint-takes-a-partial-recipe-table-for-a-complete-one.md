---
title: guide_lint takes a partial recipe table for a complete one once learned recipes exist
kind: finding
status: open
priority: low
area: tools
source: claude
raised: 2026-10-21
raised_in: branch feat/profession-recorder (batch 1, WP-G2)
---

## What

`tools/guide_lint.py` (`known_ids`) starts checking the `recipe` and `spell` ID kinds as soon as the pack's `professions` table holds one
recipe, and then reports every `.craft <spellID>` and `.train <spellID>` that is not in it as an `unknown-id` error. Until now the table
was empty, so those kinds were skipped ("the data pack has no ... records yet"). The profession recorder (Core/LearnProfessions.lua)
fills the table from play, so it will hold only the recipes a player opened, and a correct ID of another recipe will read as unknown.

## Why

False errors would block a track that uses `.craft <spellID>` as soon as the first learned recipe is imported. No guide uses
`.craft <id>` or `.train <id>` today (the tracks avoid them), so nothing fails yet.

## Done when

The lint checks recipe and spell IDs only when the table is complete (written by the exporter's layer, not only the learned one), or
reports the unknown ones as a note when only learned records exist; a test covers both cases.

## Notes

`tools/guide_lint.py` belongs to the lint work (WP-E2). The same applies to `known["spell"]`, which is `classes` spells plus recipes:
with a learned recipe and an empty classes table, a valid class spell ID in `.train` reads as unknown.
