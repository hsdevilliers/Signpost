---
title: Common add-on interactions: minimap button clicks, a quick menu, key bindings (the usual conventions)
kind: feature
status: done
priority: normal
area: ui
source: user
raised: 2026-10-21
raised_in: the user, 2026-10-21 (batch 1, WP-I)
closed: 2026-10-21
resolution: Batch 1, branch feat/launcher-interactions (WP-I; the PR number follows): the conventions researched and written down with their sources (docs/INTERACTIONS.md); the minimap button (left = Journal, Shift-left = step card, right = quick menu, tooltip with where you are), the AddOn Compartment click and hover, the quick menu shared with the step card's right-click, six key bindings (Bindings.xml), Show and Lock the minimap button in the Settings tab, /signpost card and /signpost minimap. Specs and mutation checks pass. Not seen in the game: the play check is the item launcher-in-the-game-quick-menu-compartment-right-click-key, the probes are in FOREVER-API-NOTES (Launcher).
---

## What

From the user (2026-10-21), dictated, in their words:

> I would also like to add the common, what do you call it, app interactions that apps have. And I'm going to need your help here. You'll need to go and read up on what this is, but it would be something like Shift-clicking the add-on button on the border of the minimap to hide or show the steps panel. That's like one shortcut. Left-click opens the big window, or the complete window, and then a right-click gives you, you know, a couple of quick options in a context list, or a small little context window. Something like that. Please don't take that as instruction. Please go and look extensively, or as much as you need to, online to what the, what can we say, the industry standard, not that add-on development is an industry, is for things as such.

In plain terms: give Signpost the interactions that WoW add-ons have by convention (the minimap button, the AddOn Compartment entry, a context menu, key bindings), after finding out what the convention is. The user's own examples are a starting point, not an instruction: the standard decides.

## Why

Players expect an add-on's button to behave like the others: a click opens the main window, a right-click gives a few quick options, a modifier click does a secondary toggle, hovering shows what each click does, and the actions are on the Key Bindings screen.

## Done when

- The conventions are researched and written down with their sources (docs/INTERACTIONS.md).
- The minimap button, the AddOn Compartment entry and the step card follow the map written there; the quick menu is shared by all three.
- Key bindings exist for the actions a player reaches for in play; the minimap button can be hidden and locked from the Settings tab and the menu.
- Specs cover the click mapping, the menu, the compartment, the settings and the bindings.
- What only the real client can confirm (the menu's look, the compartment's right-click, the Key Bindings screen) is listed as open probes.

## Notes

Written down by Claude (not the user's words): the lead proposed the map; the user then said "build it as proposed". Work package WP-I of batch 1, branch `feat/launcher-interactions`.
