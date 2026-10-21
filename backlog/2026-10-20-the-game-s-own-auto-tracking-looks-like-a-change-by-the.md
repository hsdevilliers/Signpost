---
title: The game's own auto-tracking looks like a change by the player to the quest tracking module
kind: finding
status: done
priority: low
area: engine
source: claude
raised: 2026-10-20
raised_in: PR feat/step-ui (quest tracking)
closed: 2026-10-21
resolution: Batch 1 WP-D (branch feat/quest-tracking): the game's own tracking is told from the player's by the watch type (Automatic or Manual) where the client has it, else by the timing of QUEST_ACCEPTED or QUEST_WATCH_UPDATE just before QUEST_WATCH_LIST_CHANGED; a quest the game tracks that is not the step's is untracked. Without watch types and without that event the old limit stays: the module backs off, the player is never fought. What Forever does is collected in SignpostDB.probe.trackingSeen (verify item).
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
