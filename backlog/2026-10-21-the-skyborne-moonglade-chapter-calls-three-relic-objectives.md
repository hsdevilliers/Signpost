---
title: The Skyborne Moonglade chapter calls three relic objectives positionless although the pack has their positions
kind: finding
status: open
priority: normal
area: guides, planner
source: claude
raised: 2026-10-21
raised_in: batch 1, independent review R-guides-B (the Skyborne guide)
---

## What

Found by the independent review R-guides-B (batch 1). `windshaper-druid-11-moonglade.lua` (lines about 20, 22, 24) says the relic objectives are "only in places this guide does not go". The pack has all three relics
in Moonglade (map 1450: 72.4,66 / 75.2,67.2 / 74.4,65.4), and the note on the line above quotes those very positions. The whole Avatar, Dens, Avatar trip sits inside one step pinned at the Avatar.

## Done when

- The relics get their own `.goto` lines (or the step is split), and the `.todo` text no longer claims the data is missing.
