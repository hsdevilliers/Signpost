---
title: The lint's missing-complete rule is skipped for any quest whose name appears in a .todo
kind: finding
status: open
priority: low
area: tools
source: claude
raised: 2026-10-21
raised_in: batch 1, independent review R-tools
---

## What

`tools/guide_lint.py` (`objective_checks`) exempts a quest from the "accepted and turned in with no .complete" rule when its lower-case name is a substring of any `.todo` of the guide. A quest
named like a place ("Moonglade") is then exempt through any travel placeholder that mentions the place. PLAUSIBLE, not seen on a shipped guide (no false negatives found at the reviewed commit).
Found by the independent review R-tools (batch 1).

## Done when

- The exemption looks at the `.todo` of the quest's own step (or names the quest id), with a fixture test of a place-named quest and a travel placeholder.
