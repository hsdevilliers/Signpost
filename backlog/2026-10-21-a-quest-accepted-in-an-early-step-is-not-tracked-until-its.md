---
title: A quest accepted in an early step is not tracked until its own step comes (Infestation Investigation)
kind: finding
status: open
priority: normal
area: engine, ui
source: user
raised: 2026-10-21
---

## What

The user, in the first fresh-character test (2026-10-21, Skyborne Druid): "it told me to pick up Infestation Investigation, but it was not automatically tracked in the quest log." They accepted it in the first step of the guide; the quest tracker did not show it until much later.

What the save shows (character save of that run): `tracking = { before = {92460}, left = {92461} }`. The tracker follows the quests of the step the route is on (here Harmony in Balance, 92461); Infestation Investigation (92462) has its `.complete` in a later step, so it stays untracked until that step comes, although it is in the quest log and its mobs are on the player's path.

## Why

The tracker is built to follow the current step (WP-D, the user's decision of 2026-10-20: on by default, following the step). With the planner doing a quest's work several steps after its pick-up, the player holds quests the tracker ignores. The planner fix `plan-stops-together-shared-kill-spots-hand-in-before-the` (the Infestation kills done together with Harmony in Balance) removes this case for the island start but not the general one.

## Done when

- After that planner fix, look at it in the game once: does a quest accepted in a step and worked in the next one get tracked? If not, decide with the user whether the tracker should also track every quest in the log that the guide routes (a settings choice, default on or off), or only those whose objectives are near the current step, and build it with specs.

## Notes

- Evidence: `python tools/read_savedvars.py --char <name> tracking progress` on the play machine's save. No Lua error was recorded in that run (the only one in the account save is the deliberate `/signpost debug throw` of 2026-10-17).
- The `progress` record of that run shows Find my place on a fresh character: `placed = { mode = "none", reason = "first", step = "horde-windshaper-druid:1" }`, which is right.
