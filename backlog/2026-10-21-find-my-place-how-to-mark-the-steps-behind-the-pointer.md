---
title: Find my place: how to mark the steps behind the pointer without history, and the profession steps?
kind: question
status: open
priority: normal
area: engine, ui
source: claude
raised: 2026-10-21
raised_in: batch 1, WP-B (Find my place)
---

## What

When Find my place puts the pointer at step N, every step before it is marked, and two cases are a judgment call:

1. **No quest history** (a placement by the level alone, `mode "level"`): every quest step before the pointer is "open", so they are all marked skipped (`[-]` in the Journal), although nobody knows whether the character did them.
2. **Steps without a quest** (a trip, a training, a profession step) before the pointer are marked done, also ones the character has not done: a `.trainprof skinning` step behind the pointer for a profession the character never learned shows `[x]`, and the character never sees the step again unless they click back to it.

## Why

The marks decide what the Journal's route list shows and what the character is offered. Marking an unlearned profession's first step done hides it; marking hundreds of steps skipped for a character with no history reads as if they declined them.

## Done when

The user says which they want, in plain words. Options: (1) keep as built (the brief's rule: done when satisfied now or neutral, skipped when open); (2) mark steps skipped only when the character has history, and done when it has none; (3) leave a `.trainprof` whose profession the character has not learned (and is in the plan) as skipped, or make it the pointer; or something else.

## Notes

Built per the brief (WP-B, batch 1): `Progress:ApplyPlacement` in `Engine/Progress.lua`. The profession tracks are G1's work in the same batch; this interacts with them.
