---
title: The importer stores an innkeeper's bind-location name with no cap
kind: finding
status: open
priority: low
area: tools
source: claude
raised: 2026-10-21
raised_in: batch 1, independent review R-tools
---

## What

`tools/signpost_tools/learned.py` (`_inns`) stores the bind name `n` as it came, with no length cap or cleaning: a 5,023-character name reached `travel.inns` in the review's test. The 100-byte `_text`
cap is applied only to trainer services and recipes. A file the addon itself wrote cannot carry such a name (the recorder caps it), so this matters only for a hand-edited or damaged
SavedVariables file. Found by the independent review R-tools (batch 1).

## Done when

- `_inns` applies the same text cap and cleaning as the other names, with a test on a long name.
