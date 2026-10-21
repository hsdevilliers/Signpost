---
title: A LibDataBroker data source with the current step as its text (Titan Panel, ChocolateBar and the like)
kind: feature
status: open
priority: low
area: ui
source: claude
raised: 2026-10-21
raised_in: WP-I (batch 1), branch feat/launcher-interactions
---

## What

A second LibDataBroker object of `type = "data source"` whose `text` is the current step (`<chapter> · step i/N`, as `Launcher:Where()` builds
it), updated on `STEP_CHANGED`/`GUIDE_LOADED`, with the same `OnClick` and `OnTooltipShow` as the launcher. Players who run Titan Panel,
ChocolateBar, Bazooka or a similar bar could then show where they are in the guide in their own bar.

## Why

The launcher object already appears in those bars (icon, tooltip, the click map). A text-bearing source is the next thing such a player
asks for. It was an optional item of the launcher work ("only if trivial and clean"); it was left out because it is a second object,
nothing in this checkout runs such a bar to see it, and it is not needed for Release 1.

## Done when

The data source exists with a spec on the LibDataBroker fake (`tests/mocks/launcher.lua`: `NewDataObject`, text updates on a step change),
and someone with one of those bars has seen the step text appear and the click map work from it.

## Notes

Roughly 30 lines in `UI/Launcher.lua`. LibDataBroker fires its attribute-changed callbacks when `object.text` is set, which is how the
bars update. Do not give it the same name as the launcher: LibDataBroker keeps one object per name.
