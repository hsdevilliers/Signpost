---
title: An install changes step ids: the saved progress of a character playing the old guide points at nothing
kind: finding
status: done
priority: normal
area: engine, release
source: claude
raised: 2026-10-20
raised_in: independent review of the installed Troll Hunter guide, 2026-10-20
closed: 2026-10-21
resolution: batch 1 (WP-B, branch feat/find-my-place): a saved place that is not in the guide (and no mark that matches) is now placed by the character's quests and level instead of starting over at step 1, after a chat line that the guide was updated; pinned by tests/progress_placement_spec.lua (a saved place that is not in the guide). The old rule (after the furthest done step) stays where some marks still match.
---

## What

The Troll Hunter guide's chapters and steps have new ids (`troll-hunter-NN-zone:K` instead of `durotar-1-12:K`), so the saved progress of an
existing character points at a step that no longer exists (the user's Volduun-Raptortusk has `current = durotar-1-12:3`). What the engine does
then: read in the code (`Progress:Resume`, 2026-10-20), not yet in a spec or in play: an unknown saved step falls back to the step after the
furthest done or skipped one, which for the old ids is the first step of the new guide, and the steps that are already satisfied are skipped
on load. So no error, only a restart from the top that skips what is done.

## Why

Every install of a planned route changes the ids, so every installed guide will reset the progress of whoever is playing it.

## Done when

- The fallback is pinned by a spec and seen in play (start at the first step that is not yet satisfied), perhaps with one chat line.
- Or the install keeps ids stable where it can (the same zone and step number), or migrates the saved id.
