---
title: /signpost reset only resets the step frame, not the guide's progress
kind: finding
status: open
priority: low
area: ui
source: claude
raised: 2026-10-20
raised_in: the first look at the Troll Hunter guide, 2026-10-20
---

## What

`/signpost reset` (`UI/StepFrame.lua`) resets only the step frame's position, scale and alpha. It does not restart a guide's progress, and
nothing else is called "reset", so a player expects it to (Claude told the user so on 2026-10-20 and was wrong). Progress is moved with
`/signpost step <n>`, `next`, `back` and `skip` (`Engine/Progress.lua`).

## Why

A player who wants to start the guide again looks for "reset" and gets a frame that moves instead.

## Done when

One of: `/signpost help` says what each of the two does; `reset` is renamed to say it is about the frame and something plain restarts the
guide; or the user decides it is fine as it is (then this is dropped).

## Notes

A restart throws away the player's place in the guide, so it should say what it will do (or ask); the user decides the wording.
