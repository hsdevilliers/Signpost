---
title: The Tauren Druid route leaves out two quests offered where it stands (1104 Salt Flat Venom, 6442)
kind: finding
status: open
priority: normal
area: planner, guides
source: claude
raised: 2026-10-21
raised_in: review of the Tauren Druid planner route, batch 1 (WP-A2), 2026-10-21
---

## What

The user's rule (2026-10-21, found in the Skyborne guide: "The Skyborne guide leaves out a quest offered in the same area as its step"): a quest offered where the player already stands, with objectives in the area of the step in hand, is taken. Checked on the Tauren Druid route (docs/reviews/horde-tauren-druid-walk.md, "The user's rule"): generation 1 left out 745 Sharing the Land; generation 2 leaves out two, 1104 Salt Flat Venom (level 30, offered by the NPC who gives Hardened Shells, 1105, which the route takes; about 4,900 experience at level 29) and 6442 Naga at the Zoram Strand (level 19, at level 26, about 1,600). Generation 1 took both, so it is the thorough route's choice, not the data.

## Why

Leaving a quest out sends the player back later or loses its experience. No rule or manifest hint can fix it: the manifest can leave a quest out or order quests already routed, none can make the planner take one.

## Done when

WP-E1's planner change takes such quests; the Tauren route is planned again and the check in the walk report's recipe (the `Select-String` for 745, 1104 and 6442, and the gap script) finds none.

## Notes

- Raised by the review of the Tauren Druid planner route (batch 1, WP-A2). The method is the Skyborne worker's: a giver within 150 yards, an objective within 250 yards of a doing step in the next six, offered by the planner's own availability and profit test.
