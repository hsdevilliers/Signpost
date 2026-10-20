---
title: Showing the step card again does not set the quest tracking for the current step until the next change
kind: finding
status: open
priority: low
area: engine, ui
source: claude
raised: 2026-10-20
raised_in: PR #39 review fixes (quest tracking)
---

## What

Quest tracking does nothing while the step card is hidden (the saved flag: `/signpost hide`, the Journal's "Show the step card" box).
Showing the card again does not set the tracking for the step that is current: it takes effect at the next step or the next change
of the quest log's set of quests.

## Why

The review of PR #39 asked for "nothing at all" while the card is hidden (a friend runs the addon for data collection with the card
hidden). Catching up on show would need the step card to tell the module, a new call between UI and engine that was not asked for.

## Done when

The user says whether showing the card should set the tracking at once (one call from `StepFrame:SetShown(true)` to a `Tracking`
method that begins the current step), or that the next step is soon enough.

## Notes

`Tracking:Active()` in Engine/Tracking.lua reads the flag; `SetEnabled(true)` with the card hidden does not apply either.
