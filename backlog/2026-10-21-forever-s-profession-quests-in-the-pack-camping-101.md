---
title: Forever's profession quests in the pack (Camping 101, Craftsman's Writ) are not routed
kind: finding
status: open
priority: normal
area: guides, planner, data
source: claude
raised: 2026-10-21
raised_in: profession tracks, first cut (feat/profession-tracks)
---

## What

The private pack's Forever layers hold profession quests that Classic does not have, and neither the planned route nor the tracks use them:

- **"Camping 101: <profession>"**: one quest for each profession (and one per race's start: the Orc and Troll one is given by Brakk at Razor Hill).
  Each is level 6, needs level 4, needs "The Great Outdoors" done (the pack's record), needs the profession itself (every one but Cooking carries a
  skill requirement), and ends at the profession's trainer: for a Troll Hunter Rawrk (First Aid, Razor Hill), Lau'Tiki (Fishing, near Sen'jin Village),
  Thuwd (Skinning, Orgrimmar) and Karolek (Leatherworking, Orgrimmar). The Cooking one (quest 96655, ending at Cook Torka, Razor Hill) is in the
  route already.
- **"Craftsman's Writ: <item>"**: crafting quests that start from an item and ask for the crafted item (many levels and professions).

The planner drops the profession-gated quests (it plans with no professions: "needs a profession skill"). The tracks do not accept them: what they ask
and give is not in the data, and Brakk is in Razor Hill, far from the Orgrimmar learn steps.

## Why

A level 6 quest at level 4 or 5 is a good share of a level; the quests are Forever's own tutorial for professions and may teach or give something the
route needs. Skipping them blindly may cost experience, and routing them blindly may cost trips.

## Done when

- Each "Camping 101" quest for the five professions of the default plan is decided: routed (the planner given a profession plan, or track steps with
  `.accept` and `.turnin` that follow the learn step) or left out with a reason written down.
- What the quests ask, reward and teach is recorded from play (`Core/Learn.lua`; docs/FOREVER-API-NOTES.md "Open probes") before any of it is routed.
- The "Craftsman's Writ" quests are decided the same way (probably left out of Version 1).

## Notes

- Depends on the hub markers in the planned chapters (backlog: profession steps cannot use the trainers the route passes earlier): the accept is at
  Razor Hill, after the learn step there.
- The lint's profession-quest coverage (`profession_chains`) reads `professions[line].quests` of the pack, which is empty: nothing enforces any of this.
