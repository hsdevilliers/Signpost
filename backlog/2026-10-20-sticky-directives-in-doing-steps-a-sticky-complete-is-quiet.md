---
title: Sticky directives in doing steps: a sticky .complete is quiet, a sticky place directive keeps its pin
kind: finding
status: open
priority: low
area: engine
source: claude
raised: 2026-10-20
raised_in: PR feat/step-ui (doing steps)
---

## What

How `.sticky` directives meet the new rules, decided without the user because no shipped guide uses `.sticky` yet:

- sticky directives do not decide a step's kind (they are ongoing beside later steps, not what the step is for): a step is a doing step
  by its own `.complete` and place directives only;
- in a doing step a sticky `.goto` or `.complete` draws nothing, like the step's own;
- a sticky place directive (say `.sticky .buy`) keeps its sticky pin beside a doing step;
- a `.sticky .complete` in a step that is not a doing step still pins the objective area, as before.

## Why

The rule in the request was written about a step's own directives. A sticky quest directive is the one case where the quest log's marks
and the guide's would show the same objective for as long as the sticky is active.

## Done when

The user confirms the four points, or the first guide that uses `.sticky` with a quest directive shows what it should do instead.

## Notes

`Conditions:Targets` and `Conditions:IsDoingStep` in Engine/Conditions.lua; the sticky cases are in tests/conditions_spec.lua ("step
kinds").
