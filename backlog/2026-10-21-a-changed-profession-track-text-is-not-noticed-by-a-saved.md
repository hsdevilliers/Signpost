---
title: A changed profession track text is not noticed by a saved place's fingerprint
kind: finding
status: open
priority: normal
area: engine, guides
source: claude
raised: 2026-10-21
raised_in: batch 1, FIX-engine (review fix 1)
---

## What

Since the batch 1 review fix a saved record carries the fingerprint of the guide text it was made for (`guide.fingerprint`, `Engine/Parser.lua`:
`Util.Checksum` over the guide's own text and every chapter it included). A record for another text, or without one, is dropped and the
character is placed again from its quest history. The profession tracks (`Guides/Professions/*.lua`) are separate texts: their steps are merged
into the route with ids `track:<key>:<n>`, positions in the track's text, and the fingerprint leaves them out on purpose (it must not depend
on the profession plan, and a profession re-parse of the same guide is not a new guide). So an edited or regenerated track keeps its ids while its
steps change, and the marks a record holds on track steps (done, skipped, the active `.sticky .skill` goals, `.craft` counts) point at other
steps: the failure the fingerprint fixes for the chapters, left for the tracks.

## Why

The five shipped tracks are written by hand and still carry Classic's numbers marked VERIFY(launch): they will be edited (an anchor moved, a step
added in the middle shifts every number after it) once the game shows the real ranks. Each edit puts the characters in progress at risk of a
wrong mark or a goal that disappears, without a word.

## Done when

Either the record keeps a fingerprint for each track it has merged (`fingerprints[key]`, compared when the track is merged) and a changed track
drops only the marks of its own steps (placing those from the skill the character has), or the track steps get ids that do not move when the
text around them does (a key per step, as `track:skinning:rank-2`). A spec with a track edited under a record, and `docs/ENGINE.md` ("The
record belongs to one text of the guide") says which.

## Notes

Left out of batch 1 as the brief asked (the guide text and its chapters). Files: `Engine/Parser.lua` (`ParseTrack`, `ParseGuide`),
`Engine/Professions.lua` (`Merge`), `Engine/Progress.lua` (`IsOutdated`, `Forget`).
