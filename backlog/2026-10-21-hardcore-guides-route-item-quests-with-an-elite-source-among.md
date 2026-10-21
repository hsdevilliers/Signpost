---
title: HARDCORE guides route item quests with an elite source among ordinary ones, with no warning
kind: finding
status: open
priority: normal
area: planner, drafter, guides
source: claude
raised: 2026-10-21
raised_in: review of the Skyborne Druid planner route (WP-A1), 2026-10-21
---

## What

The drafter and the Route Planner drop an item objective in a HARDCORE route only when every known source of the item is an elite
(`_elite_objective` in tools/guide_draft.py). An item that also drops from ordinary creatures stays, and nothing tells the player that an elite or
rare elite drops it too. The first Skyborne Druid route had six such quests: 869 Raptor Thieves and 865 Raptor Horns (Takk the Leaper, rare elite, near
59.6,8.3), 845 The Zhevra (Swiftmane, rare elite, near 61.2,34.5), 855 Centaur Bracers (Rocklance, rare elite, near 56.5,41.7, and Warlord Krom'zar,
elite), 1104 Salt Flat Venom (Vile Sting, rare elite, near 70.6,72.9) and 86576 Bloodfury Trinkets (Sister Riven, rare elite, and Bloodfury Ripper,
elite). The review wrote a note for each by hand, as a `note` rule in tools/hardcore_rules.json.

## Why

A hand list is incomplete by construction: every guide meets the same kind (the Tauren route shares the Barrens quests), and a missed one is a rare elite
at the player's feet in hardcore.

## Done when

- The planner (or the drafter) writes a `.note` after the `.accept` of a quest whose item objectives have an elite, rare-elite or boss source, naming the
  creature and its position from the pack ("Takk the Leaper, rare elite, near 59.6,8.3: take it from the ordinary raptors"), with no hand-written rule;
  the hand-written notes can then go. A test pins the note on a fixture with a mixed-source item.
- Or the guide lint warns when a HARDCORE guide has such a quest and no note.

## Notes

- The pack's NPC `rank`: 1 elite, 2 rare elite, 3 boss. Forever creatures carry none (the item "The pack has no rank for any Forever creature").
