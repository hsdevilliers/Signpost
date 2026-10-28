---
title: Plan the two HARDCORE druid guides again with the stop rules before HARDCORE arrives
kind: task
status: open
priority: normal
area: planner, guides
source: claude
raised: 2026-10-27
raised_in: the stop-rules session, 2026-10-27
---

## What

The stop rules (planner defaults `stop_yards` 150, `share_yards` 100, `share_trip` 30) were built and merged with only the Troll Hunter guide planned again, because the user decided on 2026-10-27 that the two HARDCORE guides can wait (HARDCORE arrives later than launch). The installed Tauren Druid and Skyborne Druid routes were planned with the old rules: split stops, a hand-in left for a later trip, kill spots 66 yards apart worked as two trips (the Skyborne opening the user walked on 2026-10-21).

## Why

Both guides must be planned again with the new defaults before they are released, and with whatever the Troll Hunter test teaches. About 10 to 20 minutes of computer time each (`python tools/route_planner.py <tauren|windshaper> --preset all --install --force --quiet`, one at a time), then `guide_lint --strict`, `guide_sim --check`, `tools/check.ps1`, a PR. The regeneration pass should also take the other open tasks that regenerate these two guides (escorts skip, Bear Form early, the 96605 family defect).

## Done when

Both guides are planned again with the stop rules on, the checks pass, and the walk reports' numbers are refreshed.
