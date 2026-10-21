---
title: A mixed step still lists and pins a group quest's turn-in the player never took
kind: question
status: open
priority: low
area: engine, ui
source: claude
raised: 2026-10-21
raised_in: batch 1, WP-C (group quests)
---

## What

A step that mixes a group quest with ordinary quests (not an optional-only step) lists and pins the group quest's directives like any other: in the Stonetalon chapter
`troll-hunter-16-stonetalon-mountains`, the hand-in step with `.turnin 6283` (`.optional 6283`) and `.turnin 6381` shows `[ ] Turn in "Bloodfury Bloodline"` and a pin at its
NPC to a player who never took 6283, though the step is complete when 6381 is handed in (the optional quest does not count). The same holds for the `.accept` of a group
quest beside ordinary pick-ups (an offer, which may be wanted) and for its `.complete` lines.

## Why

The card and the pins should not send the player to hand in a quest they do not have. The batch 1 rule for optional-only steps (a quest the player did not take never
holds the step) leaves this case as it was.

## Done when

The user decides what a mixed step does with its group quest: keep its `.accept` line as an offer and hide the `.complete` and `.turnin` lines and pins of the quest
until it is in the quest log; or show all of it as the `Optional:` line of the card (see the `.group` item); or leave it. Then specs for the decision.

## Notes

`Conditions:Describe` and `:Targets` already know the optional quests of a step (`step.optional`); `info.quest` on each line (batch 1) is what a filter would read.
