---
title: Four shipped steps have more than ten lines: the card cuts them off
kind: finding
status: open
priority: normal
area: ui, planner
source: claude
raised: 2026-10-21
raised_in: batch 1, WP-C (done marks on accept and turn-in lines)
---

## What

The step card shows ten body lines at most (`MAX_BODY_LINES` in UI/StepFrame.lua; a wrapped line counts for the rendered lines it takes), and what does not fit is cut
off. Four steps of the shipped guides have more lines than that, counting what `Conditions:Describe` returns for them: `mulgore-1-12:13` (14 lines, the Tauren Druid
route), `zephras-isle-1-12:20` (13, the Windshaper Druid route), `barrens-10-20:6` (11) and `troll-hunter-01-durotar:44` (11). Most of the extra lines are `.todo` and
`.note` lines of the hardcore routes. The done marks added in batch 1 (an `.accept` and a `.turnin` line now start with `[ ]`/`[x]`) take room along each line, not a
line of their own, but they make a long quest title wrap sooner, which brings the cut-off nearer.

## Why

A line the player cannot see is a quest or a note the guide asked for and the card does not say. VERIFY(beta) in UI/StepFrame.lua already asks whether ten lines of this
font fit the frame without covering too much.

## Done when

The user (or the next play session) says what to do: raise the limit, let the body scroll, or have the tools split a step before it passes ten lines (the planner's
`steps.group` would stop joining at ten lines, the drafter's notes would move into a step of their own). The four steps above read in full.

## Notes

Measured with the real engine on the shipped steps, an empty player and no data pack (a scratch busted spec, nothing committed).
