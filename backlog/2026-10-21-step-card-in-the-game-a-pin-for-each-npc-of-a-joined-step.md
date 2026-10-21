---
title: Step card in the game: a pin for each NPC of a joined step, marks on pick-up lines, group quest lines
kind: verify
status: open
priority: normal
area: ui
source: claude
raised: 2026-10-21
raised_in: batch 1, WP-C (step card and pins)
---

## What

Look, in the real client, at three things the step card and the pins now do (built and tested on mocks only):

- **A pick-up or hand-in of several NPCs** (the opening step of the Troll Hunter route has two): the map and the minimap show one pin for each NPC, named for its own
  quests; a pin goes when its quests are taken or handed in (not a pin left behind with "Go to"); the pin's tooltip lists only its own quests' lines.
- **The done marks on pick-up and hand-in lines**: each `Accept` and `Turn in` line of the card starts with `[ ]`, and `[x]` in green once the quest is in the log or
  handed in; a step with a long quest title still reads (a mark takes room along the line).
- **A group quest** (the Troll Hunter route has Assault on Fenris Isle in Silverpine Forest and Hypercapacitor Gizmo in Thousand Needles): the card shows
  `Optional: <quest> (group quest)` in small text under the step while the quest is up to three steps ahead and neither in the log nor done; the route does not stop at
  its steps unless the quest is in the log; the Journal's route list tags the steps `(group quest)` and shows the ones passed untaken as `[-]`.

## Why

The colour escapes in a font string, a font string that does not wrap, the height of the card with a third small text block, and what the quest log reports at login
(see the open probe in docs/FOREVER-API-NOTES.md: a group quest in the log at login must keep its step current) can only be seen in the client.

## Done when

The user has looked at one joined step, one group quest and a pick-up with a long title, or the probe in docs/FOREVER-API-NOTES.md "Open probes" (the quest log at
login) is answered, or what is wrong is turned into items.

## Notes

Batch 1 (WP-C): `Engine/Conditions.lua` (`:Targets`, `:OptionalOnly`), `UI/StepFrame.lua` (`MARKED`, `:OptionalLines`), `UI/Pins.lua` (tooltip), `UI/Journal.lua`.
