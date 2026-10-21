---
title: Trainer services never expire: a service the game removes stays in the record and in the pack
kind: finding
status: open
priority: low
area: engine, data
source: claude
raised: 2026-10-21
raised_in: branch feat/profession-recorder (batch 1, WP-G2)
---

## What

A trainer's services are kept as a union: the latest reading of a service replaces the older one, but a service the window does not
list stays, because the trainer window's own filters (available, unavailable, used) hide some services. So a service the game removes
in a patch stays in the record until the trainer's record is evicted, and it also stays in the pack (the importer unions readings too).

## Why

The brief asked for "a changed list replaces the old"; replacing blindly would lose data every time a filtered window is read, so
the recorder merges. The cost is stale services after a patch.

## Done when

A reading made with all three filters on (`GetTrainerServiceTypeFilter("available" | "unavailable" | "used")` all true) is marked
complete and replaces the stored list (in the recorder and in the importer), a partial one still merges; or another way to retire a
removed service is chosen; tests cover both.

## Notes

`GetTrainerServiceTypeFilter` exists on 1.60.1.70450 (probe) but what it answers is unverified. The recorder never changes the filters.
