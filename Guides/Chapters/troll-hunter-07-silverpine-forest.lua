-- PLANNED: the thorough alt 1 route for Troll Hunter: tools/route_planner.py troll --preset all --install --force --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"troll-hunter-07-silverpine-forest",
	[[
#chapter 16-17 Silverpine Forest
step
  .goto 1421,49.89,60.33
  .turnin 477 -- Border Crossings
  .accept 478 -- Maps and Runes
step
  .goto 1421,59.58,40.99
  .complete 98298 -- Arugal's Folly
step
  .goto 1421,58.44,34.9
  .turnin 438 -- The Decrepit Ferry
  .accept 439 -- Rot Hide Clues
step
  .goto 1421,53.46,13.43
  .turnin 428 -- Lost Deathstalkers
  .goto 1421,53.43,12.59
  .turnin 91921 -- Return to Quinn (Again)
step
  .goto 1421,44.2,39.81
  .turnin 98298 -- Arugal's Folly
  .goto 1421,43.98,40.93
  .turnin 478 -- Maps and Runes
  .accept 481 -- Dalar's Analysis
  .goto 1421,43.42,40.86
  .turnin 439 -- Rot Hide Clues
  .accept 443 -- Rot Hide Ichor
step
  .goto 1421,43.4,41.2
  .complete 79096 -- Ataeric: On Arcane Curiosities
step
  .goto 1421,44.52,43.02
  .accept 92401 -- A Frightened Request
  .goto 1421,44.2,39.81
  .turnin 481 -- Dalar's Analysis
  .accept 482 -- Dalaran's Intentions
  .goto 1421,43.98,40.93
  .turnin 482 -- Dalaran's Intentions
  .accept 479 -- Ambermill Investigations
step
  .goto 1421,58.65,63.2
  .complete 479 -- Ambermill Investigations
  .complete 78127 -- The Dalaran Digest
step
  .todo "travel from Silverpine Forest to Undercity: the travel graph has no route yet"
  .zone 1458 >> Go to Undercity
]]
)
