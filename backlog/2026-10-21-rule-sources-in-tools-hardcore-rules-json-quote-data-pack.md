---
title: Rule sources in tools/hardcore_rules.json quote data-pack facts (rule 4021): a precedent
kind: finding
status: open
priority: low
area: docs, guides
source: claude
raised: 2026-10-21
raised_in: review of the Tauren Druid planner route, batch 1 (WP-A2), 2026-10-21
---

## What

The repository's data rules say nothing pack-derived beyond quest ids and coordinates that a guide carries goes into the public repository (the QuestieDB permission covers those and no more). Some older entries of tools/hardcore_rules.json quote a fact from the data pack all the same: the source of rule 4021 (Counterattack!) reads "the data pack (NPC 9456 is rank elite) and the adversarial review", and the reasons of 851, 852 and 891 say that the data carries no elite flag for the targets. Those reasons end up in the `#skipquest` lines of the shipped guides.

The rules written in the review of the Tauren Druid route (2026-10-21) follow the lead's instruction instead: sources in plain words from the quest id, zone and reason, with no pack-only facts beyond ids and names. The older entries were left as they are on the lead's instruction.

## Why

A precedent is not a permission. If the rule is strict, the old entries are in breach; if it is looser than written, the rule should say so.

## Done when

The user (or the lead) decides: reword 4021's source and the three reasons in the same plain way, or write down what a rule source may quote. Then this closes.

## Notes

- Area: docs, guides. Raised by the review of the Tauren Druid planner route (batch 1, WP-A2).
