---
title: Travel recorder, .fp steps and plain placeholders in the game: rides, innkeepers (verify)
kind: verify
status: open
priority: normal
area: engine, data
source: claude
raised: 2026-10-21
raised_in: WP-F travel data, batch 1
---

## What

`Core/Learn.lua` now records boat and zeppelin rides and innkeepers (docs/ENGINE.md, "Travel records"), and `tools/guide_travel.py`
proposes `.fp` steps and writes plain-words placeholders. All of it is built on the mock and on the data pack; none of it has been seen
in the client. The assumptions are listed in docs/FOREVER-API-NOTES.md under "Open probes" (Travel: "Rides recorded", "Innkeepers
recorded", the `.fp` steps) and marked `VERIFY(beta)` in the code.

## Why

If the client reports a player on a deck differently (no `GetUnitSpeed` of 0, a position that does not follow the deck), a ride is
never recorded and the zeppelin gaps stay; if the innkeeper's option is not found the inns stay unlearned. Both fail quietly.

## Done when

- After one Orgrimmar - Undercity zeppelin ride (`/signpost ride zeppelin` before boarding) `/signpost learned` says 1 ride and
  `python tools/read_savedvars.py learned` shows a `rides` entry whose docks lie within about 50 yd of where the player boarded and
  stepped off, with area texts and `secs`; a hearthstone, a flight and a dungeon entry leave no ride behind.
- Talking to an innkeeper and making the inn home records the NPC in `inns` with the bind location's name as `n`.
- A `.fp` step from the generator completes when the flight master's flight map is opened, and the flight master stands where the
  pack's NPC record says. The Open probes lines move to Verified (with the build number), or the recorder is fixed.
- The numbers `LEARN_GAIN` (90 s) and `LEARN_RADIUS` (150 yd) of the `.fp` steps feel right in a played route.

## Notes

Written up by WP-F, 2026-10-21. docs/PLAY-CHECKLIST.md has the short runs that also fill the gaps.
