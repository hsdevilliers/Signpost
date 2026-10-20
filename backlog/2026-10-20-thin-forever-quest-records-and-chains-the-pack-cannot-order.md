---
title: Thin Forever quest records and chains the pack cannot order: verify in play and correct
kind: verify
status: open
priority: normal
area: data, guides
source: claude
raised: 2026-10-20
raised_in: independent review of the installed Troll Hunter guide, 2026-10-20
---

## What

The same review found quests the planner routes whose records in the pack are thin, so nothing says they are wrong, and chains the pack cannot
order. To be verified in play or against the Forever client, then corrected in the pack layers or the rules:

- Probably class-locked: 98251 and 98252 (giver Va'xug Firefure, the NPC "Eye of Kilrogg", a warlock thing), 78270 Goblin Lockpicks (no level, no
  zone, no objective), 98823 Earthen Echo (docs/CLASS-QUESTS.md lists a Horde Earthen Echo under the druid weapon quests), the Dragonslayer's
  Helm, Shield and Lance stubs (78132 to 78134, 3,400 experience each).
- Chain order the data cannot express: 79980 Scramble is routed before 79192 Stepping Stones although 79192 ends at the object that starts 79980;
  the four Unending Torment quests (97289 to 97292) have no links and three are accepted at once.
- Named elites routed as ordinary quests: 4021 Counterattack (Warlord Krom'zar guards the banner and the data does not link them), 1487 Deviate
  Eradication (Wailing Caverns).
- 67 of the 194 quests of the route were Forever-new (id 60000 and up), 23 of them with thin records.

## Why

The planner and the lint cannot tell a thin record from a good one, and a wrong class quest or chain order stops a step.

## Done when

Each is checked in the client or the Forever data layers and the pack or the rules are corrected; thin records get a `verify` marker the planner
can use (leave them out, or route them with a `.todo`).
