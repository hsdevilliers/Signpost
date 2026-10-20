---
title: A reload forgets that the player took the quest tracker in hand: quest tracking sets it again once
kind: finding
status: open
priority: low
area: engine
source: claude
raised: 2026-10-20
raised_in: PR #39 review fixes (quest tracking)
---

## What

Quest tracking (`Engine/Tracking.lua`) remembers during a session that the player took the tracker into their own hands for the
current step, and stays hands off (`Tracking.state.manual`). The flag is not saved: after `/reload` or a login the same step is a new
start, so the module sets the tracking for it once, which can untrack what the player tracked by hand before the reload.

## Why

Version 1 keeps no per-step state in the saved variables. The development loop of this project asks the user for `/reload` often, so
it will show.

## Done when

The flag is kept per character with the step id (SignpostCharDB, next to the progress record) and honoured at login, or the user says
a reload may set the tracking again.

## Notes

Within a session the same step announced again (a re-parse) already keeps the flag.
