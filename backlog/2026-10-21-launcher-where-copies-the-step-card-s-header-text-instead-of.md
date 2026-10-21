---
title: Launcher:Where() copies the step card's header text instead of sharing one function
kind: finding
status: open
priority: low
area: ui
source: claude
raised: 2026-10-21
raised_in: WP-I (batch 1), branch feat/launcher-interactions
---

## What

`Launcher:Where()` in `UI/Launcher.lua` builds the step card's `<chapter> · step i/N` text a second time (the count is within the chapter
when the step lies inside its first and last bounds, else in the whole guide). The original is the local `headerText(guide, step)` in
`UI/StepFrame.lua`. The tooltip of the minimap button and the compartment would need the step card's text exactly.

## Why

Two copies of one rule drift apart: change how the card counts and the tooltip quietly says something else. The copy was made so that the
launcher work did not touch `UI/StepFrame.lua` beyond `OnRightClick` while other work was changing the same file.

## Done when

`StepFrame` exports the function (`StepFrame.HeaderText = headerText`, or a public function both call) and `Launcher:Where()` calls it;
`tests/launcher_spec.lua` ("follows the player: the step's place counts within its chapter") keeps passing.

## Notes

Raised by the launcher work (WP-I). A one-line export once the step card branches have merged.
