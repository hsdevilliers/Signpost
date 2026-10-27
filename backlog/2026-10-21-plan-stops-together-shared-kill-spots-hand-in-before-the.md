---
title: Plan stops together: shared kill spots, hand in before the extra trip, one stop per cluster (Skyborne start)
kind: task
status: done
priority: high
area: planner, guides
source: user
raised: 2026-10-21
closed: 2026-10-27
resolution: PR #52: the three stop rules (one stop within 150 yards, shared spots within 100 yards across a hub line, the completeness stop after the cluster) are the planner's defaults; the Skyborne opening replays as one stop; the Troll Hunter is planned again (16 chapters, 20h37 simulated, +0.8%, lint 0/0). Only the Troll Hunter: the user decided on 2026-10-27 that the two HARDCORE druid guides wait (HARDCORE arrives later), so their replan is the new task plan-the-two-hardcore-druid-guides-again-with-the-stop-rules. Not walked in the game.
---

## What

The user walked the first minutes of the Skyborne guide in the game (2026-10-21, the first test of the fresh character) and found the generated guide "a big miss". In their words:

- "I'm running past the mobs that I need to kill for Infestation Investigation while I'm doing Harmony in Balance. And the guide is only telling me to do Harmony in Balance." And earlier: "the areas marked, you can immediately pick up these two quests. These are the only quests you can pick up, and they are in the same area ... I don't understand why [Infestation Investigation] is told to be done at step five."
- "I've finished Harmony in Balance ... it gives me step three, says reach level two ... it doesn't tell me go and hand in the quest. I've run back, turned in the quest, picked up four other quests that are not part of the step ... All these quests are right next to each other. The quest log is empty. There's no reason not to pick them up ... we will be spending time in Zephras Isle for at least until level 5, 6. So minimizing trips back seems like a smart thing to do."

## What the replay of the real planner run shows (traced 2026-10-21, thorough Skyborne, completeness 0.6 / 45 s, `diag_infest.py`; hub 546 = the quest givers around Aetheen of the Gales (43.44,24.79), hub 543 = Rorian (42.05,23.49), hub 550 = the kill ground (45,27); 1% of the island map is about 53 yards)

The installed order is visit 2 (hub 546, 481 s: accept Infestation Investigation, kill for Harmony in Balance, accept and do Falling With Style and The Anchors of Zephras), visit 3 (hub 550: the Infestation kills), visit 4 (hub 543: only now the hand-in of Harmony and the new quests). Three causes:

1. **A kill is done at the first hub visited that has any spot of it** (`Planner.visit`, the `objs_by_place` loop). Harmony in Balance has three kill spots: (44.41,27.44) and (45.22,25.13) in hub 550, (45.02,22.27) in hub 546. Infestation Investigation has two, both in hub 550: (45.17,27.55) and (46.33,25.78). The Harmony spots in hub 550 are 42 and 66 yards from the Infestation spots; the planner used the one in hub 546, 196 yards from them, so the Infestation kills became a separate trip of 214 s. The planner never asks which spot serves the most quests (the user's "shared hunting spots", backlog `shared-hunting-spots-do-the-objectives-of-several-quests-at`).
2. **The completeness stop is inserted right after the visit that picked the quest up** (`Planner._finishable`, `stops[picked]`), which is before the hand-in of the quest just finished and before the pick-ups of the next quests at the givers' hub. That is why the hand-in comes late.
3. **The start cluster is two hubs about 100 yards apart** (543 and 546), so the pick-ups and hand-ins around it are split over several visits instead of one stop.

Also: the step card shows "Reach level 2" without a done mark (fixed in the same PR as this item: `.level` is a marked line now), and the "Read this first" note of the Skyborne guide is gone (the user asked).

## The fix (three rules, plain words)

1. When choosing where to work a kill or collect objective, prefer the spot that also serves the other quests the character holds or is about to hold (a shared spot: within about 100 yards of a spot of another open objective), and work them in the same step.
2. Put the completeness stop after the hand-ins and pick-ups of the cluster the route is standing in (cheapest insertion), never in front of a ready hand-in.
3. Treat NPCs within about 150 yards as one stop: hand in everything ready, take everything offered, then go. (The user's early idea of a larger pick-up area, now with the evidence.)

## Done when

- A planner test reproduces the Skyborne start (synthetic world with the same shape: two quests whose kill spots are 40 to 70 yards apart in different hubs; a hand-in 100 yards from a pick-up) and fails before the change.
- In the regenerated Skyborne guide, `.complete 92461` and `.complete 92462` are in the same step (or two steps at the same `.goto`), Harmony in Balance is handed in before any other trip, and the four quests offered at the givers' hub are taken in one visit.
- A "trips back" count (returns to a place within 150 yards of one left earlier in the same chapter while something there was ready or offered) is measured on all three guides before and after and goes down; planned play time does not rise by more than 2% (the user prefers fewer trips even if a little slower).
- All three guides are planned again with the new rules (Troll Hunter, Tauren Druid, Skyborne Druid), `tools/check.ps1`, `guide_lint --strict` and `guide_sim --check` clean, the walk reports' numbers refreshed.

## Notes

- Cost, for the user (they asked): the code change is small (tens of lines plus tests); the work is proving it does not make the other two guides worse. Planning the three guides again is about an hour of computer time and costs no tokens. Estimate: 2 to 4 times today's quick PR (about 1M tokens as the agents report them), less if a fresh session and a fresh worker with a small context do it. The user wants this picked up in about a week (no play before Nov 4).
- Start next time with a fresh worker (not the old planner worker: its context is about 900k tokens); give it this item, `tools/planner.py` (`visit`, `_index`, `_finishable`, `tidy`) and the diagnostic idea of `diag_infest.py` (monkeypatch `Planner.tidy`, print the first visits).
- Related: `shared-hunting-spots-do-the-objectives-of-several-quests-at`, `the-skyborne-guide-leaves-out-a-quest-offered-in-the-same`, `skyborne-guide-two-same-area-quests-are-still-left-out-after`, the task `completeness-default-f-0-6-t-45-s-regenerate-the-three`.
