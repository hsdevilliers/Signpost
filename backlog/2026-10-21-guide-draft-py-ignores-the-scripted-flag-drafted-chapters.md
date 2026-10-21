---
title: guide_draft.py ignores the scripted flag: drafted chapters pass escorts and events as deliveries
kind: finding
status: open
priority: low
area: drafter
source: claude
raised: 2026-10-21
raised_in: WP-E2, escorts and events
---

The Route Planner prices and notes scripted quests (escort_seconds, event_seconds), but tools/guide_draft.py, which writes the hand-drafted chapters the druid guides still include (Guides/Chapters/mulgore-1-12.lua, barrens-10-20.lua, zephras-isle-1-12.lua, ...), reads the same pack and does not know the flag: an escort between two NPCs passes as a delivery there, and a one-NPC event is dropped as free experience. Done when the drafter writes a .complete and a note for them like the planner, or those chapters are replaced by planned ones (docs/PLANNER.md --install).
