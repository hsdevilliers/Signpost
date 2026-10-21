---
title: The Skyborne island is left at level 14 to 16 when its exit chain is required, where players leave at 12 to 14
kind: finding
status: open
priority: normal
area: planner
source: claude
raised: 2026-10-21
raised_in: the required-quests work of the planner worker (E1, batch 1), 2026-10-21
---

## What

With the island's exit chain required (`--require 95349`, which makes the whole 30-quest story chain required), the planner's Skyborne route finishes the island and leaves at level 14 to 16 after 5h35 to 6h31 of play, where the guides say players leave at 12 to 14. The island part does end with the exit chain (the finale, *What Comes Next*, the pick-up of *The Earthen Ring*, the ride, its hand-in in Mulgore), but the character stays for every side quest first.

Why the model does it (measured 2026-10-21, beam, data pack ca4420f, docs/PLANNER.md "Measurements"):

- The chain is open early: its quests are level 6 to 13, so a HARDCORE character (one level above) can take the finale from level 11 and the last two quests, *What Comes Next* and *The Earthen Ring* (level 13), from level 12. Nothing in the planner asks for an early exit.
- The island pays well in the model: 5.8 to 6.9 experience a second at levels 11 to 14, against 3 to 4 on the mainland at the same levels in the route without the requirement. The island's quests are dense (short walks) and their experience is a guess (the pack has none for them: 10% of the quest level's bar, so about 1,000 experience for a level 12 quest).
- The guess decides the exit level: with half the guess (`--param quest_xp_fraction_of_level=0.05`) the character leaves at 14, with 0.075 at 15, with the default 0.1 at 16. The user's own save gave 40 experience for the first quest (equal to the guess at level 1); nothing is known for higher levels.
- The requirement costs play time: the beam's play time goes from 25h45 to 27h11 (+5.6%), the full simulation from 25h30 to 26h51 (+5.3%).

## Why

A route that sends a HARDCORE player through every island side quest to level 16 is slower and riskier than the guides' 12 to 14. Whether it is also slower than the best possible route depends on numbers the data does not have yet.

## Done when

- Quest rewards of the island are known from play (the recorder's QUEST_TURNED_IN experience, backlog `the-recorder-drops-the-experience-a-turned-in-quest-paid`) and the exit level is re-measured; or
- a setting asks for the exit as soon as the chain is open ("leave a story zone when its required chain can be done"), with the cost in play time measured on the Skyborne and a decision by the user on whether the guide should do the island's side quests first.

## Notes

- Related: the planner lets a route go back to a start island at a flat 15 minutes (the unknown-gateway price), although the airship out of it is probably one way (VERIFY(beta)). With only the end quest mandatory the beam left at level 13 and came back at level 29 for the chain; the zone lock of the required quests rules that out for them, but not for the island's other quests.
- Measured with the options of docs/PLANNER.md, Required quests. The exit level and the XP rate per level are in plan.json ("levels") of each run.
