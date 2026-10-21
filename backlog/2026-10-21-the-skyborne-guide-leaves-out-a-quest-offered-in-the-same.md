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

## State after batch 1 (the coordinator, 2026-10-21)

- The cause was the planner's `tidy`: a route that accepts a quest next to the work of another one, but never makes the short trip to its own work, had the unfinished quest deleted silently. Batch 1 (WP-E1) removed the silence: every quest `tidy` takes out has a record, is printed in the report and written as a `#skipquest <id> >> not finished by this route: <reason>` line in the guide, and `--completeness F` / `--completeness-trip T` (default off) finish what the route accepts when the trip is short and pays at least F of the route's pace.
- The installed guides were made with completeness OFF, so 92462 and 92463 are still left out of the Skyborne guide, now with the reason in plain sight (92462: its work is 20 s away and pays 2.07 XP/s against the route's 2.93, 71%; completeness 0.71 or less would finish it). The tables that show what each setting does on the three guides are in docs/PLANNER.md, Measurements. The choice of the default is the user's (backlog item "Completeness: which values of F and T should be the defaults?"); when it is made, the guides are regenerated and this item can be closed.
- `python tools/audit_quests.py --guide horde-windshaper-druid` lists the same-area omissions of a guide with the rule that explains each.
- The independent review of the final Skyborne guide (R-guides-B) lists more island quests left out although the player stands at the giver: 92598 (The Gift of Skysight, the Windshaper's own fork quest), 92515, 92553, 93951, 92516 and 92679 besides 92462; 92463 is not in the left-out list because it is not offered until 92462 is done.
