---
title: Class trainers' services are recorded but not filed: the pack's classes table needs the class on the record
kind: feature
status: open
priority: normal
area: data, classes
source: claude
raised: 2026-10-21
raised_in: branch feat/profession-recorder (batch 1, WP-G2)
---

## What

The profession recorder records a class trainer's services too (spell ID, name, rank text, price, level), but the importer cannot file
them: a trainer record names no class, so `tools/signpost_tools/learned.py` reports it ("class trainers wait for the classes table")
and the services stay in the archive only. `Classes/<CLASS>.lua` `trainerSpells` is still empty, so `.train class` buys nothing.

## Why

The class trainers' services are exactly the data `trainerSpells` and the class table (`classes[CLASS].spells` by level, `trainers`)
are waiting for, and Forever reworked the classes, so Classic's tables are no source.

## Done when

A trainer record carries the recording character's class token (read from `ns.Player`, so the seam holds), the importer files
learned class trainers' services into `classes[CLASS]` (spells by required level, the trainers), a test covers it, and a procedure
for turning them into `Classes/<CLASS>.lua` `trainerSpells` is written down.

## Notes

The record would then name the class of whoever played; a class token is game data, not a name, but it changes what a contribution
file says about its owner (the docs/SHARING-DATA.md text would have to say so).
