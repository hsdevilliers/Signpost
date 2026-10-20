---
title: Zone changes in planned guides are placeholders: no crossings, flight paths or zeppelins in the data
kind: task
status: open
priority: normal
area: guides, data
source: claude
raised: 2026-10-20
raised_in: independent review of the installed Troll Hunter guide, 2026-10-20
---

## What

The planned Troll Hunter route has all 25 zone changes as placeholders: each is `.todo` plus `.zone`, 14 "the travel graph has no route yet" and 11
"border ... has no crossing coordinates". There is no `.path`, `.fp`, `.fly`, `.zeppelin` or `.hs` anywhere. Two cross continents (the Barrens to
Undercity, Silverpine to Ashenvale). The planner prices Ashenvale and Stonetalon through the Barrens because `Guides/Travel/Borders.lua` has no
direct crossing, so a few steps ask for a `.zone` the player taking the direct road never enters.

## Why

The guide tells the player to change zone but not how, and the planner's travel times rest on distances the guide does not give.

## Done when

- `Guides/Travel/Borders.lua` has the crossings the Troll Hunter route needs (Durotar and Orgrimmar, the Barrens, Silverpine, Ashenvale,
  Stonetalon, Thousand Needles), by hand or learned in play (`/signpost learned`), and the transport links (zeppelins, flight paths) are in the
  travel data.
- The planner's route has `.path`, `.fly` or `.zeppelin` steps for them and `guide_lint --strict` reports no placeholder `.todo` for travel.
