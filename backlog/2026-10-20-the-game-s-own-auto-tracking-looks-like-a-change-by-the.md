---
title: The game's own auto-tracking looks like a change by the player to the quest tracking module
kind: finding
status: open
priority: low
area: engine
source: claude
raised: 2026-10-20
raised_in: PR feat/step-ui (quest tracking)
---

## What

`Engine/Tracking.lua` compares, for the quests the log already had, what is tracked with what the module left; a difference means "the
player changed it by hand" and the module then leaves the tracking alone until the next step. A quest the game tracks by itself (the
retail client adds a quest to the tracker when its progress changes, as `Enum.QuestWatchType.Automatic`) looks the same, so after the
player kills something that advances an older quest the module stops re-applying for the rest of the step: a quest accepted later
stays tracked.

## Why

It fails safe (the player is never fought), but it weakens "re-apply when the quest log changes". On Mainline `GetQuestWatchType`
returns Automatic or Manual, which would separate the game's tracking from the player's, if Forever has it.

## Done when

The in-game probe (see the item on quest tracking in the game) shows whether the game auto-tracks quest progress on Forever, and
whether `GetQuestWatchType` tells the two apart. Then the module either ignores Automatic watches in its comparison or the limit is
accepted and documented as it is now.

## Notes

The limit is documented in the header of Engine/Tracking.lua and in docs/ENGINE.md.
