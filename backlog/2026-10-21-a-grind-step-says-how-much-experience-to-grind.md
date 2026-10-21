---
title: A grind step says how much experience to grind
kind: feature
status: done
priority: low
area: planner, guides
source: claude
raised: 2026-10-21
raised_in: the user's answer about grinding at level gates, 2026-10-21
closed: 2026-10-21
resolution: WP-E1 (feat/planner-features): a grind is written as .level N plus a .note with the experience and the kills (an estimate) on the step before it; the report lists every grind; tests GrindStepTest; docs/PLANNER.md and docs/GUIDE-FORMAT.md. The drafter's own .level gates stay without the note on purpose (reason in the item).
---

## What

The user (2026-10-21), asked whether grinding at level gates is acceptable: "I'm fine if you want to have certain points in the guide where you simply
tell the player to grind a certain amount of experience."

A planned route already has such points: a step `.level N -- reach it first: kill or grind on the way`, which the engine shows as a level goal and
completes when the character reaches level N. It says nothing about how much there is to grind. The planner knows (it computes the experience between
the character's place on the level table and the level asked for, and the simulator's grinding rate): the step can say it, so the player knows the size
of the job and does not wonder whether the guide is stuck.

## Why

A bare "reach level N" at a gate reads like a missing step. "Grind about 2,400 experience (about 55 kills of creatures near your level)" says what is
wanted and how long it will take, and the player's own experience bar shows progress.

## Done when

- A grind step the planner writes carries a `.note` with the experience still to grind (from the model's level table; rounded) and what that is in
  kills of creatures of the character's level (the model's kill experience), worded as an estimate. No new directive: `.level` stays the gate.
- The amount is the model's, not a measurement: the note says "about", and the planner's report lists the grind steps with their amounts and the share
  of the route they make.
- The drafted guides (the drafter writes `.level` gates too) either carry the same note or are left as they are on purpose, with the reason here.
- A test pins the note's text and numbers on a fixture with a level gate; GUIDE-FORMAT documents what a grind step looks like.

## Notes

- Decided with the user (2026-10-21): grinding at a gate is fine; the guide may tell the player to grind an amount of experience. So the planner
  does not charge grinding, and the question item about it is closed.
- The experience a player needs depends on rested experience, the quest rewards already in the log and the creatures at hand: the note must not
  promise a number of kills.

- Done (WP-E1, feat/planner-features): Planner.emit writes the note on the step before a grind (the step the character stands in), never as a step of its own;
  report section `grinding`; tests GrindStepTest. The wording says 'before you go on', not 'here': the step before may be in a town. The drafter's own .level gates
  are left as they are on purpose: the three shipped guides are written by the planner (the drafter's chapters are replaced when a guide is planned), and the drafter
  does not price a grind.
