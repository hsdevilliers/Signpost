---
title: Quest tracking stops for the session when the client tracks none of a step's quests (a full tracker too)
kind: finding
status: open
priority: low
area: engine
source: claude
raised: 2026-10-20
raised_in: PR #39 review fixes (quest tracking)
---

## What

`Engine/Tracking.lua` tracks the quests of a step first and untracks the others only once the client shows at least one of them as
tracked. When none is (`AddQuestWatch` raised or refused, which is also what a full tracker looks like) it leaves the player's tracker
as it was, records one entry in the error log and stops until the setting is toggled. So a player whose tracker is full (the client's
limit is not known: five on Classic, more on Mainline) gets no tracking help for the whole session, and has to toggle the setting
after freeing a slot.

## Why

The review of PR #39 asked for it: never end with an empty tracker because an add failed. The alternative, freeing a slot first (remove
one other quest, add, put it back if the add failed), can lose a quest of the player's when the put-back is refused as well, so it was
not done.

## Done when

The in-game probe (see the item on quest tracking in the game) says how many quests the client lets the player track, and how
`AddQuestWatch` answers when the tracker is full. Then the module either keeps the stop (documented as it is) or retries at the next
step, or frees a slot in a way that cannot lose a quest.

## Notes

The stop is `Tracking.failed`; the entry in the error log reads "quest tracking stopped".
