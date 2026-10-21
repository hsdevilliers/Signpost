---
title: Tracks are checked against guides that do not use them; a track step above a guide's levels is an engine error
kind: finding
status: open
priority: low
area: tools, engine
source: claude
raised: 2026-10-21
raised_in: profession tracks, first cut (feat/profession-tracks)
---

## What

Two small things the profession tracks run into, both worked around and neither wrong enough to fix in that change:

1. `guide_lint` merges every track into every guide and reports `unmatched-anchor` for each step that finds no anchor, whether or not the guide
   suggests the profession (`#professions`). The Troll tracks stay clean for the druid guides only because each step with a position is gated
   `.race Troll`. A guide that never visits a town would otherwise be an error for a track it does not use.
2. A track step anchored above a guide's levels (the Leatherworking specialization at level 40, in guides that stop at 30) is dropped by
   `Professions:Merge` with an entry in `guide.errors` ("No route step matches @level 40"), so the guide always shows one parse error; the lint treats it
   as a note ("not required yet").

## Why

(1) makes a track depend on every guide's route, not on the guides that use it; the PLAN says "every track step must find its anchor in each guide
that uses it". (2) puts an expected condition among the errors, where a real error would hide.

## Done when

- The lint checks a track's anchors against the guides that suggest its profession (or are gated into it), and a test shows a guide without the
  suggestion no longer reports it (the existing `test_track_problems_are_reported_per_guide` assumes the opposite: it changes with it).
- `Professions:Merge` does not record an error for an `@level` anchor above the guide's highest chapter level (tests/professions_spec.lua and
  tests/profession_tracks_spec.lua change with it).

## Notes

- Decide (1) with the Tauren and Skyborne guides' owners: a Tauren character who learns Skinning on its own gets the track's unmatched steps dropped
  silently in game today.
