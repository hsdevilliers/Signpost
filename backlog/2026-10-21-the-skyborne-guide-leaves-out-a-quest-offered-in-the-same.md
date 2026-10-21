---
title: The Skyborne guide leaves out a quest offered in the same area as its step (Infestation Investigation)
kind: finding
status: open
priority: normal
area: tools, guides
source: user
raised: 2026-10-21
raised_in: the user's early test of the Skyborne HARDCORE guide (PR #42), 2026-10-21
---

## What

The user's words (dictated, 2026-10-21): "for step two, it tells me to complete the Harmony and Balance. And there is another quest available to pick up called Infestation Investigation, and it's not telling me to pick it up. And the reason I bring this up is because these two quests literally are completed in the same zone on the map. You know, the same area, I mean, marked by the quest log." They added that it might only concern this guide.

What was found the same day: quest 92462 "Infestation Investigation" (level 2, offered right after Coming of Age, which is 92460) is in the data pack and the Route Planner keeps it (it is not dropped; its XP is unknown, so the plan values it at a guess). A fresh `python tools/route_planner.py windshaper --preset beam` run accepts, completes and hands it in, and does the same for its follow-up 92463 "The Cirrusfly Queen". The route that is installed (the `thorough` preset, alternative 4, chosen by the Monte Carlo median among the finalists) contains neither. So this is a property of the chosen route, not a data gap. The user picked 92462 up by hand in the game (QUEST_ACCEPTED 92462 is in their event log).

## Why

A quest offered where the player already stands, with objectives in the area of the step in hand, costs a few minutes at most. Leaving it out sends the player back later or loses the XP. The user's rule is sound: a quest offered here whose objectives lie in the same area as the current doing step should be taken.

## Done when

- The planner takes such a quest (offered at a place the route is at, objectives in an area the route visits at that level anyway), through the route choice or through a rule, and a spec or a planner test pins it.
- Or the guide lint warns when a quest like that is left out, and the reason is understood (candidate cause, not confirmed: a thorough finalist that leaves unknown-XP quests out wins on the median).
- The three installed guides are regenerated and the Skyborne guide contains 92462 and 92463 (and the Tauren and Troll guides are checked for the same gap).

## Notes

- Raised with the coordinator of batch 1 (WP-A1 and WP-E1) to address when work resumes.
- Diagnostic used: wrap Planner.build and Planner.plan, run the beam preset with `--no-write`, and print each quest's actions by level.

## The user's follow-up (dictated, 2026-10-21)

"Obviously the Infestation Investigation question is a larger question. It can be because it's a Skyborne new quest that we missed it somehow due to incomplete data, or it's plainly a great shortcoming in our guide planner."

## Which of the two it is (Claude, same day)

- For this quest it is not missing data: the pack has quest 92462 (giver and ender NPC 251368, one kill objective, the follow-up 92463), the game's own offer of it was recorded in the user's save, and the planner keeps it. A fresh beam run takes it; the installed route does not. So here it is the planner's route choice (the winning finalist leaves out a free pick-up), not the data.
- The user's other cause can still be true for other Forever-new quests: see the item "Are Forever-new quests missing from the data pack" (the audit that tells the two causes apart).

## Root cause (corrected 2026-10-21 after tracing the raw route; the first version of this note had the order wrong)

Traced with the thorough preset on main's tools (windshaper, HARDCORE, hub radius 150), on the plan BEFORE `Planner.tidy()` ran. Not the data, not a pick-up distance.

- The quest is picked up at the first chance. The raw winner's visit 2 (hub 566, where Ailee and Elatrell stand, level 2 after) accepts 92462 and in the same visit completes Harmony in Balance (92461) at its kill spot in that hub, then 92474 and 94414.
- 92461 has kill spots in hubs 566 and 570; 92462's two kill spots are only in hub 570, 21.9 s of travel from 566. A visit completes an objective at the first hub that has a spot, so the shared hunting ground is never used for both.
- The raw winner never visits hub 570. After the turn-ins at Rorian (hub 563) the search chose Yala Windwatcher (hub 575) over the east trip: +440 XP in 224 s = 1.96 XP/s against +1240 XP in 505 s = 2.46 XP/s (scores 94003 against 93891). Earlier, from hub 563 after handing in 92460, going east first (94043) or to hub 566 first (94054) was a near tie. Later the character outlevels the quest and the trip is never the best again.
- The quest stays in the log with its objective open, the search ends, and `tidy()` ("a guide must not accept a quest it never turns in") deletes it silently (22 quests were in the log at the end of the winner), and 92463 never appears.
- A fresh `--preset beam` run happens to take both quests.
- Distances for reference: Ailee and Rorian are 43 yards apart (yet different hubs), Elatrell is 63 yards from Ailee and 91 from Rorian.

The model behind the numbers: a quest with unknown experience (new to Forever) is worth 0.1 x the experience of its level (92462: 90 XP) and its kills default to 8 (440 XP, 192 s). The user's save shows the game paid 40 XP for Coming of Age (92460), equal to the model's guess for it, so the guesses are not unreasonable, but 1.96 against 2.46 XP/s on guessed numbers is a coin flip, and the user's expectation is that a quest picked up in the area, with its kills a short trip away, is done.

Hub radius test (beam, flat 8 s walk between places of one hub, nothing else changed): 300 yards merges the NPCs and the kill area into one hub, so the first visit takes 92462 (accept, complete, turn in) and 92463 follows, total 26.71 h against 26.72 h at 150 (thorough); `tidy()` still removes 22 quests. 500 yards: 92462 taken late, 92463 absent, total 34.91 h (8 h more). It works at 300 only because the two spots happen to merge; the radius is not the cause.

## The user's suggestions (dictated, 2026-10-21)

"You describe it as a free pickup, while I see it as something that should have been picked up because it reinforces having more quests being done in an area. [...] And yeah, maybe the area we define for having to check for picking up quests should be enlarged. I think it was 15 yards. [...] But I think we need to enlarge that quest pickup and hand in area scan. What do you think?"

And after Claude's first answer: "Before we formally decide to go with the enlarging of an area, remember I didn't have full context of the problem, and that was just me taking a shot in the dark of what would improve the guide planner to include, you know, all quests at the correct time in a hub. It feels like I'm still not understanding the problem correctly. So please just double check and note that you don't have to go with a solution of increasing the area. You can push back and propose something else if you wish."

Claude's answer: the areas are 150 yards (hubs), 250 (step grouping) and 10 (a `.goto` counts as reached), and none of that decided this; see the root cause above. A bigger area is not recommended.

## Done when (updated 2026-10-21)

- A planner test reproduces it (a quest accepted at a hub whose only kill spots are in another hub about 20 s away, rate slightly under the best alternative) and fails today.
- No silent deletion: every quest `tidy()` removes is recorded with the reason and the numbers, printed by the route planner report and visible in the lint or the walk report.
- Finish what you accept: before tidy deletes an unfinished quest, the planner tries to insert the objective trip and keeps it within a tolerance.
- A completeness setting (the lowest rate, relative to the route's pace, at which a quest picked up on the route is still finished, and the longest objective trip) measured on Troll, Tauren and Skyborne for several values (quests added, planner and simulated time change); the user chooses the default.
- The Skyborne route holds 92462 and 92463 once the chosen setting is on; the Tauren and Troll routes are checked for the same gap.
- Design note: choosing, for an objective with spots in two hubs, the spot that also serves another open quest.
