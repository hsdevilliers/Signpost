---
title: HARDCORE druid routes: Bear Form chain early when Teleport: Moonglade exists, else a carry-on step
kind: task
status: open
priority: normal
area: planner, guides
source: user
raised: 2026-10-21
---

## What

The user chose (2026-10-21, answering the question in the session): on a HARDCORE druid route, **do the Bear Form chain early (by about level 13) when the druid has Teleport: Moonglade, otherwise a step says to leave these quests for now and carry on**. Today the planner puts the Moonglade trip wherever it is cheapest (the Skyborne route hands in the Bear Form chain at level 20 to 24), and the wording only says "cast Teleport: Moonglade if you have it, else the way is not in the data".

Applied after batch 1, in the regeneration pass with the other two decisions.

## Why

Bear Form is the early survival tool of a hardcore druid (docs/HARDCORE.md); fourteen levels without it is a risk. But whether a Forever druid gets Teleport: Moonglade, at what level and from what quest, is not known (the open question and probe `does-a-forever-druid-get-teleport-moonglade-at-what-level-by`), and walking there is not an option. So the early trip is conditional.

## Done when

- A class chain can carry a `due` level that the planner honours without the six-level cap on the lateness push (a `classQuests` entry in `Classes/DRUID.lua`), with a test; Bear Form is due at about level 13 on the two druid guides.
- The guides say, at the Moonglade trip, what to do without the teleport (a "leave these quests for now and carry on" step); if the DSL needs a change for the condition, ask the user first (CLAUDE.md).
- Both druid guides are regenerated; the question items `hardcore-druid-routes-finish-the-bear-form-chain-late` and `what-does-a-druid-without-teleport-moonglade-do-about-the` are closed with the user's answer. The Teleport: Moonglade probe stays open until someone sees it in the game.

## Notes

- Related: `hardcore-at-levels-26-to-30-keep-one-level-of-margin-and-what-about-the-gloomrise-nest` is answered without work (the user: keep the one-level margin, keep skipping the Gloomrise nest until it has been seen in the game); close it with that answer when batch 1 is on main.
