---
title: Done marks only on .complete lines: pick-up and hand-in steps with several quests show none
kind: question
status: open
priority: normal
area: ui
source: claude
raised: 2026-10-20
raised_in: PR feat/step-ui (doing steps)
---

## What

The step frame starts each `.complete` line with a done mark (`[x]` green, `[ ]` plain; `UI.MARK`, the Journal's own marks), so a doing
step says which of its quests are complete. `.accept` and `.turnin` lines have no mark: a pick-up of five quests or a hand-in of five
reads the same until the step ends, so the player cannot tell which of them is already accepted or handed in.

## Why

The request (2026-10-20) was about the quests of a doing step. The same question applies to the other two kinds of step now that each
can hold several quests. The request described the frame as already having a done mark for satisfied directives; it had none, so the
mark was built for `.complete` lines only, to stay inside what was asked.

## Done when

The user says whether `.accept` and `.turnin` lines get the marks too (one entry each in `MARKED` of UI/StepFrame.lua, specs in
tests/ui_spec.lua and tests/integration_spec.lua, whose expected lines would change), or not.

## Notes

`Conditions:Describe` already reports `done` for every completable directive and the directive's `name` for every line, so nothing in
the engine changes.
