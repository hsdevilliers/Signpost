---
title: Orc Warlock and Tauren Shaman guides (normal, level 1-30), deferred for token cost
kind: task
status: open
priority: low
area: guides, classes
source: user
raised: 2026-10-27
raised_in: the stop-rules session, 2026-10-27
---

## What

The user's words (2026-10-27): "please do the normal non-hardcore versions of a orc warlock and a tauren shaman." Later the same day, after the cost was named: "since all of it's going to take so many tokens, just skip that ... we pick up again on the 4th or 5th after the game has released, and then we give it a test run."

So: a normal (not HARDCORE) Horde Orc Warlock guide and a normal Horde Tauren Shaman guide, version 1 stopping at level 30 like every guide, **deferred for token cost**, not dropped. Nothing was started.

## What it needs (docs/PLAN.md section 3.7)

- `Classes/WARLOCK.lua` and `Classes/SHAMAN.lua`: `classQuests` from the data pack (the Classic-baseline chains and Forever's additions: see docs/CLASS-QUESTS.md and the backlog finding about Forever's new quests having no class in the data), trainer spells if known.
- `Guides/HordeOrcWarlock.lua` and `Guides/HordeTaurenShaman.lua`: metadata, then the Route Planner (`tools/route_planner.py <guide> --preset all --install`) writes the chapters; the stop rules are the planner's defaults now.
- The usual checks for each: `guide_lint --strict`, `guide_sim --check`, availability, the class-quest coverage lint.
- Profession steps: the tracks exist for the Troll route only (steps gated `.race Troll`). Whether these two guides carry profession steps was asked and not answered (see the open item about the HARDCORE druid guides, the same question).

## Cost, as named to the user

A rough estimate of 3 to 5 million tokens for both, 2 to 4 times the stop-rules change (an estimate; it cannot be measured beforehand). Cheaper ways, if picked up: one guide at a time, no profession steps, a fresh small-context worker for each.

## Done when

Both guides are installed, pass the checks, and have been walked in the game at least for their first levels (the Warlock and Shaman class quests, being partly Forever's own, need that).

## Notes

- Release 1's minimum scope does not include them (docs/PLAN.md, Release 1); this is after launch work.
- Pick up after the in-game check of 2026-11-04 or 05, when the user has seen how the stop blocks read on the step card.
