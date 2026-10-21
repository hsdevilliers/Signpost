---
title: Find my place in the game: placed at login? do the chat lines and the Journal button read right?
kind: verify
status: open
priority: normal
area: engine, ui
source: claude
raised: 2026-10-21
raised_in: batch 1, WP-B (Find my place)
---

## What

Find my place (`Engine/Placement.lua`, `Progress:Place`, the Journal's "Find my place" button, `/signpost place`, `/signpost reset progress`) is built on the mock and a simulation over the shipped guides; none of it has been seen in the Forever client. What to look at, with a character that has quest history (say level 10 with a dozen quests turned in) and no progress in a guide:

- Is the first placement made at once at login (`SignpostCharDB.progress[guide].placed.reason == "first"`, `mode "history"`), or only after the 5 s wait on the level alone (`mode "level"`, then a `"refine"` when the list arrives)? That is the open probe on `C_QuestLog.GetAllCompletedQuestIDs` at `PLAYER_LOGIN` (FOREVER-API-NOTES, "Open probes").
- Is the pointer on the step the character is really at? Do the chat lines read right?
- `/signpost place` asks again, `<` takes it back, `/signpost reset progress` (typed twice) starts over; the Journal button moves the Route tab to the chapter of the pointer; the button's place and tooltip in the real window.

## Why

The accuracy numbers in docs/ENGINE.md are against simulated characters. What the real quest list looks like at login, and whether Forever's chapter levels match the guides', only the game can say.

## Done when

The user (or the friend's SavedVariables) confirms the above, or the differences are written up and fixed. Clear the open probe in docs/FOREVER-API-NOTES.md with the evidence.

## Notes

The feature itself is closed in the item "Find my place: a guide slots in where the character is when the player starts using it".

Batch 1 review fixes (branch fix/review-engine) add things to look at, still on mocks only:

- The first placement now waits for the completed list when only the quest log is there (a quest in the log no longer counts as the list): with
  a character at level 3 or more, does `placed.mode` say `history` at once (`GetAllCompletedQuestIDs` filled at login) or `level`/`history` after the
  5 s wait and then a `refine`?
- A saved record carries `fingerprint` (the checksum of the guide text). After an addon update the first login of a character with progress
  should say "Your saved place may not match this version of the guide, so it is found again from your quest history." once (`placed.reason ==
  "lost"`), and no later login should (`SignpostCharDB.progress[guide].fingerprint` is the same after every `/reload`).
- `/signpost context` saves `questLogLoaded`: at which login is it true, and does the first evaluation see it (the item on the step card has the group
  quest side of it)?
- A character placed at a step has the same ongoing goals (`Ongoing:` lines on the card) as one that walked to it.
