---
title: A joined pick-up step names only its first pin: without the data pack the other NPCs' pins are bare
kind: finding
status: done
priority: normal
area: engine, ui
source: claude
raised: 2026-10-21
raised_in: final independent review of the beam rewrite (PR #38), 2026-10-21
closed: 2026-10-21
resolution: batch 1, branch feat/step-card-polish: a directive with a pin kind and no position marks the .goto before it (the first when none does), so each NPC of a joined step has its own pin and label; a satisfied directive stops being named and, in a step with two or more .goto lines, a .goto whose directives are all satisfied no longer draws (Engine/Conditions.lua :Targets; specs in tests/conditions_spec.lua, ui_spec.lua, integration_spec.lua and the real Troll Hunter steps in tests/shipped_guides_spec.lua; docs/GUIDE-FORMAT.md 'Joined steps', docs/ENGINE.md). A pin's tooltip lists the lines of its own quests (UI/Pins.lua).
---

## What

A pick-up or hand-in step that joins several NPCs now keeps one `.goto` for each (PR #38), so the player without the data pack sees every NPC's
position. The engine does not label them one by one: `Engine/Conditions.lua` (around lines 491 to 505) folds every position-less claim into the
step's first `.goto` pin. With `.goto A  .accept 787  .goto B  .accept 788  .goto C  .accept 789` and no pack, pin 1 reads "Accept 787 | 788 |
789" and pins 2 and 3 read "Go to map 1411 45.0, 70.0"; after 787 is accepted, pin 1 still lists 788 and 789. With the pack, a finished NPC's pin
stays a generic "Go to" until the whole step completes ("a .goto always keeps its pin"). Completion is not affected (the gotos count only when
nothing else in the step can complete it). A reviewer measured it with a scratch busted spec. The shipped guides have 22, 47 and 19 steps with two
or more gotos (at most 7, 4 and 6, at most 215 yards apart).

## Why

The tooltip of each pin should say what is there, and a pin should go when its NPC is done: the step's purpose is to steer the player to each place.

## Done when

- A directive with a pin kind and no position of its own marks the `.goto` that stands before it in the step (the first when none does), so
  each NPC's pin carries its own quests, and a quest that is in the log or handed in stops naming itself on its pin. A busted spec covers a
  step with three gotos, with and without the pack.
- docs/GUIDE-FORMAT.md and docs/ENGINE.md (`:Targets`) say so.

## Notes

- The planner and the drafter already write each NPC's goto directly before its directives, which is the order this needs.
