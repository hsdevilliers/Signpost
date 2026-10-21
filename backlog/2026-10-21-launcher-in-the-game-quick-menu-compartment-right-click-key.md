---
title: Launcher in the game: quick menu, compartment right-click, key bindings, Settings column (short play check)
kind: verify
status: open
priority: normal
area: ui
source: claude
raised: 2026-10-21
raised_in: WP-I (batch 1), branch feat/launcher-interactions
---

## What

Everything in `UI/Launcher.lua`, `Bindings.xml` and the compartment's functions was built and tested on the mock (`tests/launcher_spec.lua`);
none of it has been seen in the game. The probes are written out in `docs/FOREVER-API-NOTES.md` ("Launcher: the minimap button, the quick
menu, the AddOn Compartment and the key bindings"); this item is the short play checklist, for one short session:

1. Right-click the minimap button and the step card: the small menu appears at the cursor (title, "Open the Journal", three check boxes,
   "Previous step", "Skip this step", "Settings...", "Hide the minimap button"). A check box keeps the menu open and ticks or unticks; a
   plain entry closes it.
2. Left-click the minimap button (Journal opens and closes), Shift + left-click it (the step card hides and shows), drag it, lock it from
   the Settings tab and try to drag it again, hide it with `/signpost minimap hide` and bring it back with `/signpost minimap show`;
   `/reload` and check that all three choices stayed.
3. Open the AddOn Compartment (the small button near the minimap): hover Signpost (a tooltip), left-click it, right-click it (the same
   menu appears and stays).
4. Esc > Options > Key Bindings > AddOns: a "Signpost" group with six actions; bind one, press it, also in combat.
5. Journal > Settings: the first column's eleven boxes do not run into the step card size line, the professions line or the button at the
   bottom.

## Why

The menu, the compartment's right-click, the key bindings and the layout are the parts the mock cannot judge. The plan has no deadline
tied to the beta; this can wait for the next time the user is in the game.

## Done when

Each of the five checks is answered (seen to work, or what went wrong written down), the matching lines of the "Launcher" group in
`docs/FOREVER-API-NOTES.md` move to Verified with the build number, and anything that did not work has an item of its own.

## Notes

Work package WP-I of batch 1. If the compartment's right-click shows the menu and then closes it at once, the one-frame delay in
`Launcher:OnCompartmentClick` is not enough; if it works with the delay removed, the delay can go.
