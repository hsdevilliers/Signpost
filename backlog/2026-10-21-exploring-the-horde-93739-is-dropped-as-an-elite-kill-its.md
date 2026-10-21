---
title: Exploring the Horde (93739) is dropped as an elite kill: its objectives are talk credits for rank-3 NPCs
kind: finding
status: open
priority: normal
area: planner, drafter
source: claude
raised: 2026-10-21
raised_in: batch 1, independent review R-guides-B (the Skyborne guide)
---

## What

Found by the independent review R-guides-B (batch 1), CONFIRMED by reading the code. Exploring the Horde (93739) is the Windshaper-only `next` of 95350 (Thrall hands it over at the Orgrimmar hand-in), and its stops (Orgrimmar,
Thunder Bluff, Undercity) are all on the route. It is in neither the guide nor the left-out list: its "kill" objectives are talk credits for Vol'jin, Cairne and Sylvanas, who have rank 3 in the pack, and
`guide_draft._elite_objective`, called from `planner.py` (about lines 434 to 450), drops it as "needs an elite or boss kill". A false positive of the HARDCORE rule, and silent.

## Done when

- A quest whose objectives are talk credits (the objective is an NPC the quest's own text only visits) is not judged by the kill rule, or a drop is always listed with its reason; Exploring the Horde is routed
  (or skipped by a rule with a reason that is true).
