---
title: Drafter, planner, simulator and lint follow the activity steps; the guides are rebuilt
kind: task
status: open
priority: normal
area: drafter, planner, simulator, guides
source: user
raised: 2026-10-20
raised_in: the user, 2026-10-20, dictated while the Route Planner was being merged
---

## What

Follows from the steps item (user, 2026-10-20). When the step model becomes pick up / do / hand in:

- `tools/guide_draft.py` and `tools/planner.py` (`Planner.emit`) write one pick-up step per area, doing steps grouped by how near their
  objectives are, and a hand-in step per place, in whatever order the route needs. Today they write one NPC per step with kills and
  collecting as steps of their own (PROGRESS, "one step is one NPC"; PR #34).
- `tools/guide_sim.py` walks the new steps (a doing step is the sum of its quests' objectives, walked from where they are),
  `tools/guide_lint.py` and `tools/guide_travel.py` check them (uncovered transitions, level gates, availability).
- The Route Planner's visits already group what is done at one hub; its emission is the place to start.
- The shipped guides (Troll Hunter, Tauren Druid, Skyborne Druid) are rebuilt with `tools/rebuild_drafts.py` and linted with `--strict`.

## Why

The tools make the guides. If they keep writing one NPC per step, the engine's new steps never appear in a guide.

## Done when

- The three guides are rebuilt in the new step model and pass `guide_lint --strict` and `guide_sim --check` with no availability errors, and
  the simulated times stay of the same order (the step model changes how a route is read, not how long it takes).
- `docs/PLANNER.md` and `docs/GUIDE-FORMAT.md` say how steps are grouped (the distance, the order of pick ups and doing).

## Notes

- Depends on the steps item for the step kinds and the directives. The tools cannot write what the engine and the format do not define.
