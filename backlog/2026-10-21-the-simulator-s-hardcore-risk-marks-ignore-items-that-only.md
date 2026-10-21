---
title: The simulator's HARDCORE risk marks ignore items that only elites drop (the planner's rule counts them)
kind: finding
status: open
priority: low
area: tools
source: claude
raised: 2026-10-21
---

## What

Found while checking how pick-ups from the ground compare with kills (2026-10-21). The Route Planner drops a quest in HARDCORE mode when `guide_draft._elite_objective` says it needs an elite: a kill of an elite, or an item that only elites drop (and no container or object also drops it). The simulator's HARDCORE risk marks (`guide_sim.Model.note_risk`) only look at kill objectives, so an item that only elites drop is not marked. A hand-drafted or imported guide with such a quest passes the simulator's risk list unflagged; a planner-written guide never contains one.

## Why

The two tools should apply the same HARDCORE rule; the simulator is what `guide_sim.py --check` and the lint rely on to catch a guide that asks for something deadly.

## Done when

- `note_risk` uses the same test as the planner (share `_elite_objective` or an equivalent), including items only elites drop.
- A tool test: a quest whose item objective drops only from an elite is marked as elite risk, one that also drops from an ordinary creature or a container is not.
