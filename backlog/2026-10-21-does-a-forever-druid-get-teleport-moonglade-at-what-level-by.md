---
title: Does a Forever druid get Teleport: Moonglade, at what level, by what quest?
kind: question
status: open
priority: normal
area: guides, planner
source: claude
raised: 2026-10-21
raised_in: review of the Tauren Druid planner route, batch 1 (WP-A2), 2026-10-21
---

## What

A druid's trips to Moonglade (the Bear Form, Lessons Anew, Aquatic Form and Cat Form chains all turn or end there) are a 22 to 25 minute walk each way in the Route Planner's price; the first Tauren route made three round trips by level 20. In Classic a druid learns Teleport: Moonglade from the class trainer at level 10. Whether Forever does (or gives it as a quest reward, or not at all) is not known: the sources disagree (docs/FOREVER-API-NOTES.md, the open probe on Teleport: Moonglade). No guide and no planner run assumes the spell; the chapter notes only mention it, tagged VERIFY(beta).

## Why

If the spell exists, the Tauren and Skyborne routes can do the class chains the moment they open and the notes become instructions. In scratch runs with every trip to or from Moonglade priced at 2 minutes, the planner's play time fell by 1 to 2.5 hours of 29 to 30 (3 to 8%, which is inside the search's own noise) and the class-quest charge by about 8 hours.

## Question for the user (or the friend who plays a druid)

When a druid reaches level 10: does the class trainer offer Teleport: Moonglade? If not, does the reward screen of Body and Heart (the last Bear Form quest) give it, or something else? And in Moonglade: is there a flight master at Nighthaven for the Horde, and does the hearthstone bring you back?

## Done when

The answer is in docs/FOREVER-API-NOTES.md (the open probe moves to Verified with the evidence) and the Moonglade notes of the guides say what is true. If the spell exists, the Route Planner's travel price gets an edge for it (a cast and a loading screen) and the Tauren and Skyborne routes are planned again.

## Notes

- Raised by the review of the Tauren Druid planner route (batch 1, WP-A2), on the lead's instruction of 2026-10-21: no route assumes the spell until this is answered.
- Generation 3 of the Tauren route (807be15) makes three Moonglade round trips (levels 11, 20 to 22 and 30; 20 to 26 minutes each way in the planner's price), six placeholder steps; the last 43 minutes of the route are the third, for two class quests.
- Since batch 1 (WP-F) the guides' Moonglade steps are the generator's, from `Classes/DRUID.lua` (`travelHints`, key 1450): "cast Teleport: Moonglade
  if you have it (VERIFY(beta): where a druid learns it), else the way is not in the data", the way back "use your hearthstone or a flight path if you
  have one (VERIFY(beta): the way back is not in the data)", and a `.note` that the road overland is not to be walked (from Classic memory: through
  Felwood or Winterspring, levels 48 and up). When this question is answered, edit those three words there, regenerate the planned druid guides, and
  drop the VERIFY text. What a druid does who has no way at all is its own question (what-does-a-druid-without-teleport-moonglade-do-about-the).
