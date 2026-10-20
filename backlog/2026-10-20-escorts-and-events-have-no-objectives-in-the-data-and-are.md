---
title: Escorts and events have no objectives in the data and are priced at zero in planned routes
kind: finding
status: open
priority: normal
area: planner, data
source: claude
raised: 2026-10-20
raised_in: independent review of the installed Troll Hunter guide, 2026-10-20
---

## What

An independent review of the installed Troll Hunter guide (2026-10-20) found quests the pack gives no objective that are accepted and handed in in
one step and priced at about zero seconds: the escorts and events (863 The Escape, 435 Escorting Erland, 6641 Vorsha the Lasher, 452 Pyrewood
Ambush). The planner leaves out a quest with no objective that is accepted and handed in at one NPC (free experience), but an escort starts at
one NPC and ends at another close by, so it passes as a delivery. A class quest with no objective (the Hunter's taming chain, 6062, 6083, 6082)
is now given 5 minutes and a `.todo`.

## Why

A route credits experience for work it does not price, and the player meets an escort (or a taming) where the guide says "accept and hand in".

## Done when

- The data can say a quest is an escort or an event (a list in the repository or a field in the pack), and the planner prices it (a time, a risk
  note for HARDCORE) and writes a `.todo` or a doing step for it.
- The Hunter pet chain is written with what it asks (tame three beasts), verified in play.

## Notes

- `tools/hardcore_rules.json` already lists 863 as an escort for HARDCORE; a normal route has no list.
