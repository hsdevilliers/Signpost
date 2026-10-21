---
title: Escorts and events have no objectives in the data and are priced at zero in planned routes
kind: finding
status: done
priority: normal
area: planner, data
source: claude
raised: 2026-10-20
raised_in: independent review of the installed Troll Hunter guide, 2026-10-20
closed: 2026-10-21
resolution: The data can say it: tools/questie_import.py now keeps QuestieDB's specialFlags bit 2 (needs event) as a quest record field scripted = true (documented in Data/Schema.lua; 133 quests, 112 with no objective, proved on a copy of the pack: the only difference to the shared pack is that field and the dates). With the field, guide_sim.Model prices a scripted quest with no objective (escort_seconds 420 when it starts and ends at different NPCs, event_seconds 180 at one NPC, in tools/sim_params.json), the planner no longer passes it off as free experience (planner._consider: one scripted objective where the quest starts, written as .accept/.complete/.turnin plus a .note, a HARDCORE route says it as a risk; the profitability filter judges it by its time), and the simulator marks it a HARDCORE risk (weight 2). The shared pack has to be rebuilt once for it to take effect (python -I tools/questie_import.py --out ../Signpost_Data, then commit the generated Lua with the date). The Hunter pet chain moved to its own verify item. Tests: test_questie_import ScriptedTest, test_guide_sim ScriptedModelTest and RunTest, test_planner ScriptedQuestTest. Branch feat/tools-lint-pricing.
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
