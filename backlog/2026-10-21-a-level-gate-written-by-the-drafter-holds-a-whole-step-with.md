---
title: A .level gate written by the drafter holds a whole step with no grind note
kind: finding
status: open
priority: low
area: guides, planner
source: claude
raised: 2026-10-21
raised_in: batch 1, independent review R-guides-B (the Skyborne guide)
---

## What

Found by the independent review R-guides-B (batch 1). In the Skyborne guide the `.level 8` and `.level 10` gate (about lines 213 to 221 of the first chapter) holds the whole step, including the hand-in of 92871, and
has no grind note (the planner's grind steps say how much experience to grind; this gate does not). If Forever's experience is slower than the model, the player stalls with no advice.

## Done when

- Every `.level` gate in a shipped guide either carries the grind note or is a gate the route reaches by itself; a lint note lists the others.
