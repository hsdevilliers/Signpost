---
title: A .collect beside a .complete is a place directive: the step keeps all its markers
kind: question
status: open
priority: normal
area: ui, engine
source: claude
raised: 2026-10-20
raised_in: PR feat/step-ui (doing steps)
---

## What

The doing-step rule (GUIDE-FORMAT "Step kinds") calls a directive a place directive when it is a travel directive or its def pins
anything but quest objectives. `.collect` pins vendors and drop sources (kinds `vendor` and `gather`), so a step with a `.complete`
and a `.collect` is **not** a doing step: it keeps every marker, the objective areas of its `.complete` quests included. `.use` has no
pins and leaves a step a doing step.

## Why

The user asked for no markers where the quest log already marks the objectives. A `.collect` that only stands for a quest item (the
quest log has that objective too) would then still draw markers. A `.collect` for a profession material is a gathering pin the guide
should keep drawing. The directive cannot tell the two apart. The request left this to judgement ("keep whatever they do
today unless it would draw an objective marker for a quest"); the registry rule was the literal reading.

## Done when

The user says which it is: leave it (a `.collect` always marks), or make `.collect` quiet beside a `.complete` (then `isPlace` in
Engine/Conditions.lua takes it out, the `PLACES` and `NOT_PLACES` tables in tests/conditions_spec.lua and GUIDE-FORMAT "Step kinds"
follow), or give the guide a way to say it (a DSL change: ask first).

## Notes

No shipped guide uses `.collect` yet (the drafted chapters write item objectives as `.complete <quest>,<objective>`), so nothing
changes today.
