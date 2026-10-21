---
title: Eleven surviving mutants in the tools: tests that cannot fail
kind: task
status: open
priority: normal
area: tools
source: claude
raised: 2026-10-21
raised_in: batch 1, independent review R-tools
---

## What

The independent review R-tools (batch 1) broke the tools 74 times; 63 mutants were caught and 11 survived, each a test that cannot fail:

- `left-out-handin-code`: the `handin` code of a left-out record ignoring `passes`;
- `lint-talk-object`: the object exemption of the missing-complete rule;
- `learned-recipe-newest`: newest-wins in `learned._fold_recipes`;
- `learned-dock-spot`: the DOCK_SPOT radius;
- `learned-reagent-cap`: MAX_REAGENTS;
- `finishable-done-lift`: a quest finished in an earlier tidy round stays lifted (multi-round completeness is untested);
- `split-name-began`: the tie-break of a chapter's name;
- `audit-others`: `all` against `any` over several routes in `tools/audit_quests.py`;
- `beam-grain-best`: the grain's "best" route could be its worst;
- `learned-inn-name`: an empty innkeeper name accepted;
- `learned-side-names`: the whitelist of a ride's `side`.

## Done when

- Each mutant is killed by a test, or written down as equivalent.
