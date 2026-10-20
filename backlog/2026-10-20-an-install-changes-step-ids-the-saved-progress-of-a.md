---
title: An install changes step ids: the saved progress of a character playing the old guide points at nothing
kind: finding
status: open
priority: normal
area: engine, release
source: claude
raised: 2026-10-20
raised_in: independent review of the installed Troll Hunter guide, 2026-10-20
---

## What

The Troll Hunter guide's chapters and steps have new ids (`troll-hunter-NN-zone:K` instead of `durotar-1-12:K`), so the saved progress of an
existing character points at a step that no longer exists (the user's Volduun-Raptortusk has `current = durotar-1-12:3`). What the engine does
then (`Engine/Progress.lua`) was not checked: it may start at the first step, or complain.

## Why

Every install of a planned route changes the ids, so every installed guide will reset the progress of whoever is playing it.

## Done when

- What happens with an unknown saved step is checked in a spec and in play, and is gentle (start at the first step that is not yet satisfied,
  one chat line).
- Or the install keeps ids stable where it can (the same zone and step number), or migrates the saved id.
