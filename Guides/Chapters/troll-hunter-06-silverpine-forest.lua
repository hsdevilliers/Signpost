-- PLANNED: the beam route for Troll Hunter: tools/route_planner.py troll --preset all --install --force --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"troll-hunter-06-silverpine-forest",
	[[
#chapter 17-18 Silverpine Forest
step
  .goto 1421,44.2,39.81
  .accept 98298 -- Arugal's Folly
  .accept 98299 -- Stop the Spread
  .accept 421 -- Prove Your Worth
  .goto 1421,43.98,40.93
  .accept 477 -- Border Crossings
  .accept 95981 -- Watching the Roads
  .accept 516 -- Beren's Peril
step
  .goto 1421,45.62,42.6 >> Go to the flight master
  .fp 1421,The Sepulcher
step
  .goto 1421,43.42,40.86
  .accept 428 -- Lost Deathstalkers
  .accept 437 -- The Dead Fields
  .todo "The Dead Fields: objective 1 has no position in the pack"
  .complete 437,1 -- The Dead Fields
step
  .goto 1421,43.4,41.2
  .complete 79096 -- Ataeric: On Arcane Curiosities
step
  .goto 1421,43.42,40.86
  .turnin 437 -- The Dead Fields
  .accept 438 -- The Decrepit Ferry
  .goto 1421,42.8,40.86
  .accept 91921 -- Return to Quinn (Again)
  .goto 1421,44.52,43.02
  .accept 92401 -- A Frightened Request
step
  .goto 1421,53.46,13.43
  .turnin 428 -- Lost Deathstalkers
  .accept 429 -- Wild Hearts
  .goto 1421,53.43,12.59
  .turnin 91921 -- Return to Quinn (Again)
  .accept 91920 -- Wild Eyes
step
  .goto 1421,59.58,40.99
  .complete 98298 -- Arugal's Folly
step
  .goto 1421,65.8,50.67
  .complete 95981 -- Watching the Roads
step
  .goto 1421,63.5,63.2
  .complete 78127 -- The Dalaran Digest
step
  .goto 1421,43.98,40.93
  .turnin 95981 -- Watching the Roads
  .goto 1421,44.2,39.81
  .turnin 98298 -- Arugal's Folly
step
  .goto 1421,49.89,60.33
  .turnin 477 -- Border Crossings
  .accept 478 -- Maps and Runes
step
  .goto 1421,58.44,34.9
  .turnin 438 -- The Decrepit Ferry
  .accept 439 -- Rot Hide Clues
step
  .goto 1421,43.98,40.93
  .turnin 478 -- Maps and Runes
  .accept 481 -- Dalar's Analysis
  .goto 1421,43.42,40.86
  .turnin 439 -- Rot Hide Clues
  .accept 440 -- The Engraved Ring
  .accept 443 -- Rot Hide Ichor
  .goto 1421,44.2,39.81
  .turnin 481 -- Dalar's Analysis
  .accept 482 -- Dalaran's Intentions
  .turnin 482 -- Dalaran's Intentions
  .accept 479 -- Ambermill Investigations
step
  .goto 1421,45.62,42.6 >> Go to the flight master
  .fly Undercity
]]
)
