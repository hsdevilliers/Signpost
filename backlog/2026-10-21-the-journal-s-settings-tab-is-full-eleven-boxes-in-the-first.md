---
title: The Journal's Settings tab is full: eleven boxes in the first column at a reduced size, no room for more
kind: finding
status: open
priority: normal
area: ui
source: claude
raised: 2026-10-21
raised_in: WP-I (batch 1), branch feat/launcher-interactions
---

## What

The Journal's Settings tab is full. The first column holds eleven check boxes (the minimap button's two arrived with the launcher work, the
step card's grow-up box before them), then the card size and opacity steppers, the profession line, up to four "Restore" buttons and the
data sharing button; the second column holds the nine automation boxes and the quest tracker's. To make the minimap boxes fit, the boxes
are now drawn at 26 instead of 32 (`CHECK_SIZE` in `UI/Journal.lua`), a layout worked out from the code, not seen in the game.

Every new setting from now on makes this worse. The pane is a fixed 800 x 560 window with no scrolling.

## Why

A setting that does not fit is a setting nobody can reach, and a layout that overlaps is a visible defect in the add-on's most-used screen.

## Done when

The Settings tab is a scroll frame (one list of sections: Step card, Pins, Minimap button, Automation, Quest tracker, Data sharing,
Professions) or has a second page, so that adding a setting never needs a pixel count; the specs read the settings from `settingsList()`
as they do now. Until then, `docs/FOREVER-API-NOTES.md` ("Launcher", the last probe) says what to look at in the game.

## Notes

Raised by the launcher work (WP-I). Other work in the same batch adds to the same list (the quest tracker's section, a Route tab button).
