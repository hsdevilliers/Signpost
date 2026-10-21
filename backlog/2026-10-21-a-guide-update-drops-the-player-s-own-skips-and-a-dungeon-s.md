---
title: A guide update drops the player's own skips and a dungeon's Skip: carry them over by content?
kind: question
status: open
priority: low
area: engine, ui
source: claude
raised: 2026-10-21
raised_in: batch 1, FIX-engine (review fix 1)
---

## What

When a guide's text changes, `Progress:Forget` (batch 1 review fix) drops everything a record holds that is keyed by a step id and places the
character again from its quest history. That includes what the player decided by hand: steps they skipped, a dungeon chapter's "Skip this
dungeon", and a profession they declined by skipping its first step (the decline itself is kept, in `SignpostCharDB.declinedProfessions`, but
the skip marks are not). After an update a player who had skipped the Deadmines sees it offered again, and the steps they skipped by hand and
that have no quest of their own (a trip, a note) come back.

## Why

A skip is a decision of the player, and the update that costs it is silent: the chat line says the place is found again, not what else went.
The ids cannot be trusted across texts, but the steps themselves can often be recognised: a dungeon chapter by its name, a step by the
quests it names.

## Done when

The user says whether it matters. If it does: carry the skips over by content (the chapter's name for a dungeon, the set of quest IDs of a
step, else not at all) when a record is dropped, with a spec, and `docs/ENGINE.md` says what is carried. If not: the item is dropped with
their word.

## Notes

`Engine/Progress.lua` (`Forget`, `IsOutdated`, `SetGuide`). Dungeon skips are stored as `skipped` marks on every step of the chapter
(`SetChapterSkipped`), so they go with the rest.
