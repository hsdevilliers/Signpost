---
title: Steps made only of group quests wait for the player: the engine and GUIDE-FORMAT disagree
kind: finding
status: done
priority: normal
area: engine, planner
source: claude
raised: 2026-10-20
raised_in: independent review of the installed Troll Hunter guide, 2026-10-20
closed: 2026-10-21
resolution: batch 1, branch feat/step-card-polish: an optional-only step (completable directives all about .optional quests) never holds the player up: Conditions:IsComplete passes it while none of its quests is in the quest log, and a quest the player took decides it like any step (the quests in the log only). The card shows the group quest of an optional-only step among the next three steps as 'Optional: <quest> (group quest)' (up to two lines, apart from the ten body lines), and the Journal tags such a step and shows one passed without its quest done as skipped. The level rule (5 levels) is a new item: a .group modifier. Specs in tests/conditions_spec.lua, ui_spec.lua, integration_spec.lua, journal_spec.lua, shipped_guides_spec.lua; docs/GUIDE-FORMAT.md 'Optional-only steps'.
---

## What

A step whose only directives are `.optional` quests (group quests in a normal route) waits for the player to do or skip the quest: the engine
counts the optional directives when nothing else decides the step (`Engine/Conditions.lua`, pinned by `tests/conditions_spec.lua`), but
`docs/GUIDE-FORMAT.md` says optional directives "don't count". The planned Troll Hunter guide has nine such steps. A player who skips a group
quest has to skip each of its steps by hand.

## Why

Group quests are meant to be optional; the guide should not stop at them.

## Done when

The engine and the format agree (an optional-only step completes at once or is skipped, or the generator folds such lines into a neighbouring
step), with specs. The extra line beside the current step for group quests (PROGRESS, `.group`) may be the real answer.
