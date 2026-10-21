---
title: Regenerate the Skyborne guide after both druid guides' HARDCORE rules are merged
kind: task
status: done
priority: normal
area: guides, planner
source: claude
raised: 2026-10-21
raised_in: review of the Skyborne Druid planner route (WP-A1), 2026-10-21
closed: 2026-10-21
resolution: Done in batch 1: the Skyborne guide was regenerated (feat/skyborne-guide 9ca64ab) after both druid rule sets, the planner fixes and the generator fixes were merged; tools/tests/test_shipped_guides.py now fails whenever a planned guide accepts a quest the rules skip for it, and is green.
---

## What

tools/tests/test_shipped_guides.py (2026-10-21) fails when a guide marked `planned` in tools/drafts.json accepts a quest that tools/hardcore_rules.json
skips for it. The Skyborne review's rules (18 in all) are applied by a regeneration. The Tauren worker's rules (about 40: escorts, probable Warlock, Rogue
and Warrior class quests, dungeon lead-ins, named Forever targets, the Battle of Hillsbrad) apply to the Skyborne route as well, and the first generation
accepts at least 98251, 98252, 65601, 76156, 76160, 76240, 6523, 6544, 6641, 6482, 4770, 4904, 527 (with 528, 529 and 532), 857, 92422, 92706 and 97003.

## Why

A rule that no regeneration has applied protects nobody: the guide the player installs is the chapters, not the rules.

## Done when

After the merge of both branches, `python tools/route_planner.py windshaper --preset all --install --quiet` has been run (and the Tauren and Troll guides
regenerated), `python -m unittest discover -s tools/tests -t tools` is green, and the post-checks at the end of
docs/reviews/horde-windshaper-druid-walk.md pass.
