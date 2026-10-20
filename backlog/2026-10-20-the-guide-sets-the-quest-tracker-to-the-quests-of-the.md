---
title: The guide sets the quest tracker to the quests of the current step and untracks the rest
kind: feature
status: open
priority: normal
area: ui, engine
source: user
raised: 2026-10-20
raised_in: the user, 2026-10-20, answering what a doing step shows on the map
---

## What

From the user (2026-10-20), answering what a doing step should show on the map: neither a guide marker nor words in the step, "you just use
the quest log the traditional way. You open the map and look for where the quest log marks". Then their idea: "Is it possible via the API,
the game API, to set the tracked state of quests? So the idea is that every time you go between a step, that it tracks the quests in
question. So for argument's sake, you're on a step that says you need to do three quests ... the moment you step into that step, it untracks
all of the quests, the other quests, and only tracks those three. I think that would be pretty cool. So you're still using the traditional
way of using quests, except we toggle the tracked state."

When a step becomes current the addon sets the quest log's tracked state: every other tracked quest is untracked and the quests the step
is about are tracked. The minimap, the map and the objective tracker then show only that step's quests, with the progress the step frame no
longer shows.

## Why

It is what makes a doing step work without guide markers or words: the quest log's own marks and the tracker's progress lines are the
guidance, and they show only for tracked quests.

## Done when

- The quests named by the current step's `.complete` and `.turnin` that are in the log are tracked and every other quest is untracked. A step
  that names none (pick up, travel) leaves tracking alone.
- A setting turns it off, and nothing happens while the guide is hidden. Its default is decided (see Notes).
- The API calls are probed on the Forever client (`-- VERIFY(beta)`, FOREVER-API-NOTES "Open probes") and the result is written down.

## Notes

- The retail-style API has what is needed (unverified on Forever): `C_QuestLog.AddQuestWatch`, `RemoveQuestWatch`, `GetQuestWatchType`,
  `GetNumQuestWatches`, `GetQuestIDForQuestWatchIndex`, `C_SuperTrack.SetSuperTrackedQuestID` (the quest with the arrow), the event
  `QUEST_WATCH_LIST_CHANGED`; Classic had `AddQuestWatch(logIndex)`.
- Decided (user, 2026-10-20): on by default, with a setting to turn it off. CLAUDE.md defaults automation to off; the user chose otherwise
  because a doing step relies on it.
- The player's own tracking is overwritten while it is on, and the first version does not restore it.
