---
title: The card's Optional: line can name a group quest the character holds until the quest log has arrived
kind: finding
status: open
priority: low
area: engine, ui
source: claude
raised: 2026-10-21
raised_in: batch 1, FIX-engine (review fix 3)
---

## What

The engine no longer passes an optional-only step (a group quest) before the client has sent the quest log (`ns.Context:QuestLogLoaded()`,
batch 1 review fix). `Conditions:OptionalOnly`, which the step card's `Optional: <quest> (group quest)` line reads (`available`) and the
Journal's tag reads, is not gated the same way: until the log is loaded it reports a quest that is in the log the client has not sent as
"available", so the card can name a quest the character already holds for the seconds before `QUEST_LOG_UPDATE`.

## Why

A wrong line on the card, shortly after login, in the one case the fix is about (a character that holds the group quest). Harmless
to the route (the step waits like any other), but it reads as if the add-on did not know.

## Done when

`OptionalOnly` reports no `available` quests while the log is not loaded (or the card waits for `QuestLogLoaded()`), with a spec on the card
before and after `QUEST_LOG_UPDATE`. Or the real client shows that `QUEST_LOG_UPDATE` is there before the card is, and the item is dropped.

## Notes

`Engine/Conditions.lua` (`OptionalOnly`, `logLoaded`), `UI/StepFrame.lua` (`OptionalLines`), `Engine/Context.lua` (`QuestLogLoaded`). The open
probe is in `docs/FOREVER-API-NOTES.md` ("At login on a character with a group quest in the quest log").
