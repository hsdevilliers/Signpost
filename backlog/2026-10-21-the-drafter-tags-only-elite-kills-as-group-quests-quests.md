---
title: The drafter tags only elite kills as group quests: quests that follow one and dungeon quests stay plain
kind: finding
status: open
priority: low
area: planner, drafter
source: claude
raised: 2026-10-21
raised_in: the group-quest fix of the planner worker (E1, batch 1), 2026-10-21
---

## What

The Route Planner now tags as `.optional` the quests a solo player cannot do: an elite kill, a dungeon quest (a quest the pack sorts under an instance), and every quest that needs one of those first (docs/PLANNER.md, "Group quests, dungeon quests and the quests that follow them"). The drafter, `tools/guide_draft.py`, tags only elite kills (`optional=elite`, about line 254), so a chapter it drafts still writes the quests that follow a group quest, and the dungeon quests, as plain steps that never complete for a solo player. The same two flaws the independent review found in the regenerated Troll Hunter route (a chain blocked behind a group quest; Blackfathom Deeps quests as mandatory steps).

## Why

All three shipped guides are planned today, so the drafter's chapters are not shipped, but `rebuild_drafts.py` still drafts any guide that is not marked planned, and a new guide drafted before it is planned would carry the flaw.

## Done when

- The drafter shares the planner's two rules (a quest sorted under an instance; a quest that needs a group quest through the pack's prerequisite and chain data), best by moving them into one function both tools call, with a test with the planner's fixture chain.

## Notes

- The planner's rules are `Planner._in_instance` and `Planner._mark_group_chains` in tools/planner.py.
