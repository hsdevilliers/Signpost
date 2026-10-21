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

## Root cause (found 2026-10-21, thorough preset on main's tools, windshaper, HARDCORE)

Not the data and not a pick-up distance. The planner groups quest givers and objective areas into hubs of about 150 yards (`hub_radius`), a visit to a hub accepts everything offered there, and the cleanup `Planner.tidy()` ("a guide must not accept a quest it never turns in") deletes every quest still in the log when a search ends.

- Hubs here: 563 = Rorian (map 2521, 42.05 / 23.49: 92460 end, 92461 start and end); 566 = Ailee (42.82 / 23.37: 92460 start) and Elatrell (43.44 / 24.79: 92462 and 92463 start and end); 570 = the kill area east of them (92461's kills in hubs 566 and 570, 92462's kills in 570, 92463's kill in 578). Ailee and Rorian are 43 yards apart yet in different hubs (the greedy cutting depends on the order); Elatrell is 63 yards from Ailee and 91 from Rorian.
- The winner and all five alternatives of the thorough run end with 92462 removed by tidy (22 quests removed in the winner); 92463 never appears (its parent is gone). 92461 is completed at level 2 in all of them.
- Mechanism: the routes clear the kill area (570, for 92461) before they pass Elatrell (566), where 92462 is accepted; its own kills (also 570, unknown experience, so worth almost nothing) are never revisited; at the end the quest is in the log and tidy removes it, silently.
- A fresh `--preset beam` run takes both quests (accept at level 2, complete and turn in at level 3), which is why a quick run looked fine.

Hub radius test (beam, flat 8 s walk between places of one hub, nothing else changed): 300 yards puts the four NPCs and the kill area in one hub, the first visit takes 92462 (accept, complete, turn in), 92463 follows, total 26.71 h against 26.72 h at 150 (thorough); but tidy still removes 22 quests, so the cleanup problem is general. 500 yards: 92462 is taken late (accept level 2, turn in level 6), 92463 absent, total 34.91 h (8 h more): too coarse. The 300 result is optimistic because the walk inside a hub is a flat 8 s; the proper test charges real yards and compares with the full simulation (work package E1 of batch 1).

## The user's suggestions (dictated, 2026-10-21)

"You describe it as a free pickup, while I see it as something that should have been picked up because it reinforces having more quests being done in an area. I mean, it's a couple of feet away from the other quest pickup. And yeah, maybe the area we define for having to check for picking up quests should be enlarged. I think it was 15 yards. [...] But I think we need to enlarge that quest pickup and hand in area scan. What do you think?"

Claude's answer: the areas are already 150 yards (hubs), 250 (step grouping) and 10 (a `.goto` counts as reached), and the giver is 63 and 91 yards away. The cause is the order of the visits and the cleanup, not the distance. A bigger area helps only where giver and kill area land in one hub and it understates the walking; fix the cause first (a repair pass after tidy), decide the radius on numbers. The capital-city idea is its own item.

## Done when (updated 2026-10-21)

- A planner test reproduces the case (a quest offered in a neighbouring hub whose kills are in the area the route works) and the fix (a repair pass after tidy, or better) takes it.
- The Skyborne route holds 92462 and 92463; the Tauren and Troll routes are checked for the same gap; a report says how many quests tidy removed per guide and how many the repair gets back.
- The hub radius changes only with the walk charged by real yards and a comparison with the full simulation.
