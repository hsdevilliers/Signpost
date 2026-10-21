---
title: The importer drops the objective icon type: a talk-to objective looks like a kill and is priced as 8 kills
kind: finding
status: open
priority: low
area: data, planner, simulator
source: claude
raised: 2026-10-21
raised_in: WP-E2, the lint rule for objectives
---

QuestieDB marks a speak-with objective with an icon type (ICON_TYPE_TALK); tools/questie_import.py keeps only the kind and ID, so a quest whose objective is to talk to its own giver or ender (the Camping 101 family, and the Zephras Isle quests) reaches the pack as a kill of that NPC. guide_sim.Model.objective prices it as default_kills kills (about 3 minutes and kill experience), the planner routes it so, and the new lint rule has to guess with a proxy (a kill or object objective on the quest's own NPC or object is talk-to, so no .complete is required). Done when the importer carries the icon type (a small field on the objective), the model prices a talk-to as an interaction, and the lint uses the field. Check first how many of the 65 quests with an objective on their own NPC are duels or fights rather than talks (e.g. Blood Tithe, Standing Our Ground).
