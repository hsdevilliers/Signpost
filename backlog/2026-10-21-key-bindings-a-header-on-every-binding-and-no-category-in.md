---
title: Key Bindings: a header on every binding and no category in Bindings.xml
kind: verify
status: open
priority: low
area: ui
source: claude
raised: 2026-10-21
raised_in: batch 1, independent review R-engine-2
---

## What

`Bindings.xml` puts `header="SIGNPOST"` on all six bindings and gives no `category`. From memory of Blizzard's own file and common add-ons, the header belongs on the first binding of a
group and add-ons use `category="ADDONS"`; the likely effect on Forever is six repeated "Signpost" header rows with the bindings filed under "Other". The shape is locked in by
`tests/launcher_spec.lua` (about line 897) and the Bindings guard of `tools/check_repo.py`. Found by the independent review R-engine-2 of batch 1 (PLAUSIBLE, from memory, not seen):
nobody has looked at Forever's Key Bindings screen.

## Why

Cosmetic, but it is the first thing a player sees when looking for the keys.

## Done when

- The Key Bindings screen on Forever was looked at once (Esc, Options, Key Bindings, the AddOns section, Signpost), what it shows is written into `docs/FOREVER-API-NOTES.md`, and
  `Bindings.xml`, the spec and the check_repo guard match it (the header on the first binding only, and a category if the screen has one).
