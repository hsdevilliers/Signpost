---
title: The finale warning sits on the pick-up, fourteen steps before the Lorthuna fight
kind: finding
status: open
priority: normal
area: planner, guides
source: claude
raised: 2026-10-21
raised_in: WP-A1 final walk report, 2026-10-21
---

## What

In the final Skyborne guide the warning note for the scripted boss fight sits on the `.accept 92646` line of Confront Lorthuna (step 64 of chapter 01, with The Inner Sanctum's hand-in at the Shrine of Akir). The fight itself is
step 78, a doing step (`.complete 92646`, explore at 74.9,53.0), fourteen steps later, after the route has gone off to Elegael Thornpaw's chain, the Strange Hermit and Mercy Falls on Deaf Ears. Step 78 has no note. The planner
writes a `note` rule after the `.accept` of its quest only; a player who reads steps one at a time meets the fight without the warning in front of them.

## Why

The warning exists for the moment before the fight: heal, buff, be ready to leave.

## Done when

A `note` rule (or the generator's own HARDCORE note for scripted quests) is written on the doing step of the quest too, or on the step that comes right before it; a test pins that a note rule for a quest with a `.complete` in a later step
appears on both. The guide is made again and the post-check in docs/reviews/horde-windshaper-druid-walk.md ("a scripted boss fight" notes) finds it on the fight step.
