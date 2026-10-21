---
title: Quest tracking in the game: do the watch functions exist, do the tracker and minimap follow the step?
kind: verify
status: open
priority: normal
area: engine, ui
source: claude
raised: 2026-10-20
raised_in: PR feat/step-ui (quest tracking)
---

## What

With the setting on (Journal > Settings > Quest tracker), in the real client:

- `/signpost probe` and `python tools/read_savedvars.py` say which of `C_QuestLog.AddQuestWatch`, `RemoveQuestWatch`,
  `GetQuestWatchType`, `GetNumQuestWatches`, `GetQuestIDForQuestWatchIndex`, `C_SuperTrack.SetSuperTrackedQuestID` and
  `Enum.QuestWatchType` exist (the Classic functions `AddQuestWatch`, `RemoveQuestWatch`, `IsQuestWatched`, `GetNumQuestWatches`,
  `GetQuestIndexForWatch` are listed as expected absent: finding them means the fallback runs);
- when a step becomes current, the quest tracker and the minimap show only that step's quests, with their progress, and the first quest
  that is not complete is the one the tracker points at;
- a quest accepted during the step is untracked at the next change of the quest log's set of quests; tracking or untracking something by
  hand during a step stops the module until the step changes;
- the check box under "Quest tracker" in the second column of Journal > Settings fits the pane (the first column is nearly full).

## Why

All of it is the Mainline watch API written from memory and exercised on a mock (`Engine/Tracking.lua`, `VERIFY(beta)` comments, the
"Quest tracking follows the step" bullet of docs/FOREVER-API-NOTES.md "Open probes"). Whether the watch list reads back an add or a
remove at once (the module compares right after), how many quests the client lets the player track, and whether the minimap shows only
tracked quests are not known.

## Done when

The probe output is read, the open probe in the API notes is answered, and a step change in the client leaves the tracker with that
step's quests, or what differs is turned into items.

## Notes

The feature itself is the item `the-guide-sets-the-quest-tracker`. The default (on or off for a player who has not chosen) is
`Tracking.DEFAULT_ENABLED`, a user decision.

How to answer it with almost no effort (batch 1 WP-D, branch feat/quest-tracking): the user, in game, out of combat, with one quest
in the log, runs `/signpost tracking test`, waits two seconds, runs `/reload`; then `python tools/read_savedvars.py probe` shows
`probe.tracking` (which watch functions exist, each call's answer and what the list said right after, the watch events seen, the
limits the client names), `probe.trackingSeen` (what the game did to the tracker as quests were accepted or advanced during normal
play, up to twelve observations) and, after `/signpost probe`, `probe.questLogMax`. `/signpost tracking` prints the module's state.
Still open after that read: whether the player's own tracking comes back as it was (turn the setting off), whether the card shown
again sets the tracking, and the minimap and the check box layout (play).
