---
title: Skyborne exit in the game: the chain, the dock, the airship and the level
kind: verify
status: open
priority: normal
area: guides, travel
source: claude
raised: 2026-10-21
raised_in: batch 1, the lead's research on the Skyborne island exit, 2026-10-21
---

## What

The Skyborne exit rests on beta-era fan guides and the Warcraft Wiki (`docs/FOREVER-API-NOTES.md`, "Skyborne exit"): the island story chain 93836, 93090, 95349 ("The Earthen Ring"), then an airship from
Valanaar's westernmost dock (a wait of about 7 to 8 minutes) to Skywatcher Plateau in north-west Mulgore. Nothing was seen in the game.

## Why

The Skyborne HARDCORE route's island chapter ends with this chain and the ride. A wrong level, vehicle, dock or order makes the first quarter of an hour of the route misleading, and the travel step
carries no dock position until someone rides.

## Done when

- A Windshaper (the user's, or the friend's recorded data) has left the island, and these are written into `docs/FOREVER-API-NOTES.md` and moved from VERIFY(beta) to verified: the quests of the
  chain and the level the exit is done at, the dock position (the recorder lists the ride: `/signpost learned`), the vehicle's name, the landing spot, and whether the airship can be boarded before
  the chain is done.
- The Skyborne guide and the travel data match what was seen (the dock `.todo` becomes a position; the island chapter's order and level gate are corrected if needed).

## Notes

WP-F, 2026-10-21: the airship is in the travel data as a hand-authored ride (`Guides/Travel/Borders.lua`, `ride` entry: Zephras Isle to
Mulgore, Horde, one way, a wait of 450 s, the dock and landing in words, the unverified parts listed), with the zones only and no dock
position. The travel generator turns it into a real step (`.zone`, a note with the wait, a `.todo` that says what is unverified), so the
Skyborne route no longer shows the generic placeholder at the island exit. When someone rides it (`/signpost ride zeppelin` first), the
recorded ride replaces the entry (it keeps the name, the wait and the direction) and the step becomes a `.zeppelin` with the dock
positions; `docs/PLAY-CHECKLIST.md` has the line for it. If the airship turns out to run the other way too, or to be a boat, the entry's
`oneWay` and `kind` are the two fields to change.
