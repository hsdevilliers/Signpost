---
title: Doing steps in the game: no guide pins, the done marks, up to ten lines in the step frame
kind: verify
status: open
priority: normal
area: ui
source: claude
raised: 2026-10-20
raised_in: PR feat/step-ui (doing steps)
---

## What

Look, in the real client, at a doing step (a `.goto` and one or more `.complete` lines):

- the map, the minimap and the minimap edge arrow show no guide marker for it (the quest log's own marks show the objectives), and the
  previous step's markers are gone;
- the step frame lists one line per quest, `[x]` in green when the quest is complete and `[ ]` when not, with no objective counters, and
  no line for the `.goto`;
- the frame holds up to ten lines of the body font (`MAX_BODY_LINES`, five before) without clipping a line or covering too much.

## Why

Everything here is built and tested on mocks. The colour escapes in a font string, `GetStringHeight` right after `SetText` and the size
of a ten-line frame can only be seen in the client. Ten lines is Claude's choice (the plan said about five): a step now lists all of its
quests, five or more, and a long title wraps.

## Done when

The user has looked at a doing step with one quest and one with five or more, and the "Doing steps" bullet in docs/FOREVER-API-NOTES.md
"Open probes" is answered, or what is wrong is turned into items.

## Notes

The line cap is the step frame's `MAX_BODY_LINES` in UI/StepFrame.lua (`VERIFY(beta)` there).
