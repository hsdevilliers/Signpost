---
title: What does a druid without Teleport: Moonglade do about the Moonglade trips, if walking is out?
kind: question
status: open
priority: normal
area: guides, planner
source: claude
raised: 2026-10-21
raised_in: WP-F travel data, batch 1: the Moonglade words (MUST-FIX of the independent guide review)
---

## What

Every trip to or from Moonglade in a druid's guide now says: cast Teleport: Moonglade if you have it (VERIFY(beta): where a druid learns it), else
the way is not in the data; do not walk it (from Classic memory the road overland runs through Felwood or Winterspring, zones for levels 48 and
up); the way back is the hearthstone or a flight path if you have one (`travelHints` in `Classes/DRUID.lua`, written by the travel generator). A
druid who has none of these is left with nothing to do: no step says what to do instead.

## Why

The Moonglade class chains (Bear Form at 10, Lessons Anew at 14, Aquatic Form at 16, Cat Form at 20) are mandatory class quests, and the Tauren
HARDCORE route makes three trips by level 30. A character that cannot make a trip cannot do the chain, and the guide neither says "leave these
for now" nor re-orders the route. The Route Planner still prices a trip as the walk the travel graph gives (22 to 25 minutes each way), a price
no player should pay at that level, and its ranking of routes (an early trip for a far class quest) rests on it.

## Done when

- The question on Teleport: Moonglade (does-a-forever-druid-get-teleport-moonglade-at-what-level-by) is answered, and the wording in
  `Classes/DRUID.lua` says what is true: if the spell exists at level 10 the steps say to cast it (no VERIFY) and the planner has a cheap edge for
  it; if it comes later or not at all, the next point applies.
- The user decides what a HARDCORE druid does without a safe way: leave the Moonglade chains (a `#skipquest` with a reason, offered again later),
  level first, or another way; the guide and the Route Planner follow that decision.

## Notes

Raised while making the generator write the class's own words for the Moonglade trips (batch 1, WP-F, a MUST-FIX of the independent guide review
of the planned druid guides). The words are data (`Classes/DRUID.lua`, `travelHints`); docs/GUIDE-FORMAT.md ("Travel") and docs/HARDCORE.md
("Moonglade and Bear Form timing") describe them. Until the question is answered the friend with the druid is the best source (docs/SHARING-DATA.md).
