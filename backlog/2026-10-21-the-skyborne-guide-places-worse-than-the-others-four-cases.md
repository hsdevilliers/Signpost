---
title: The Skyborne guide places worse than the others: four cases of the placement spec are red
kind: finding
status: open
priority: normal
area: engine, guides
source: claude
raised: 2026-10-21
raised_in: WP-A1 regeneration with the island exit required, 2026-10-21
---

## What

After the Skyborne guide was made again with the island exit required (thorough alt 2: 14 chapters, 272 steps, 188 quests, 7h18 of grinding at level gates), `tests/placement_spec.lua` fails
for horde-windshaper-druid in four of its six cases; the Tauren and Troll guides pass. From `python tools/placement_report.py` (bounds of the spec in brackets): a character who followed the guide
to the step is 10 quest steps off at the 90th percentile [2] and 15 steps at most [6] (78% within five; nobody three levels off); skipping a fifth of the quests: median 1, p90 10 [8]; quests done early:
p90 11 [10]; all the noise together: 2.2% three levels off [0] (median 4, p90 14). The Tauren guide is at 0 / 1 and the Troll at 0 / 0 for the first case. (The spec came with the merge of feat/batch-1; it was
never run on the earlier Skyborne installs of this branch.)

## Why

Placement ("Find my place") has to find a player who is not exactly where the guide thinks. Candidate causes, not checked: long stretches where the quest history does not change (7h18 of grinding at
level gates, the island's 86 steps), and the hand-in-only steps of the exit chain.

## Done when

The cause is found in the guide or in the placement constants; the spec is green for the regenerated Skyborne guide, or its bounds are changed on purpose with the reason written here. The figures are re-read
after the next regeneration (they move with the guide).
