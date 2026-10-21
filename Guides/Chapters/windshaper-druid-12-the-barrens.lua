-- PLANNED: the thorough alt 5 route for Skyborne Druid (HARDCORE): tools/route_planner.py windshaper --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"windshaper-druid-12-the-barrens",
	[[
#chapter 22-22 The Barrens
step
  .goto 1413,51.95,31.58
  .turnin 899 -- Consumed by Hatred
  .turnin 4921 -- Lost in Battle
  .turnin 95774 -- Her Name Is Olgra
step
  .goto 1413,62.98,37.22
  .turnin 1094 -- Further Instructions
step
  .todo "travel from The Barrens to Undercity: the travel graph has no route yet"
  .zone 1458 >> Go to Undercity
step
  .goto 1458,73.4,33.0
  .turnin 78143 -- Secrets of the Dreamers
  .turnin 78149 -- Fury of the Land
step
  .goto 1458,46.31,71.91
  .accept 95216 -- The New Plague
  .todo "The New Plague: objective 1 has no position in the pack"
  .complete 95216,1 -- The New Plague
  .turnin 95216 -- The New Plague
step
  .goto 1458,58.08,89.51
  .accept 92421 -- Light's Justice
  .todo "Light's Justice: objective 1 has no position in the pack"
  .complete 92421,1 -- Light's Justice
  .turnin 92421 -- Light's Justice
step
  .todo "travel from Undercity to Silverpine Forest: the travel graph has no route yet"
  .zone 1421 >> Go to Silverpine Forest
step
  .goto 1421,56.18,9.18
  .accept 435 -- Escorting Erland
  .goto 1421,53.46,13.43
  .turnin 435 -- Escorting Erland
  .accept 449 -- The Deathstalkers' Report
step
  .goto 1421,44.2,39.81
  .accept 98298 -- Arugal's Folly
  .accept 98299 -- Stop the Spread
  .goto 1421,43.98,40.93
  .accept 477 -- Border Crossings
  .accept 95981 -- Watching the Roads
  .accept 516 -- Beren's Peril
step
  .goto 1421,43.42,40.86
  .turnin 449 -- The Deathstalkers' Report
  .accept 437 -- The Dead Fields
  .todo "The Dead Fields: objective 1 has no position in the pack"
  .complete 437,1 -- The Dead Fields
  .turnin 437 -- The Dead Fields
  .accept 438 -- The Decrepit Ferry
step
  .goto 1421,43.4,41.2
  .complete 79096 -- Ataeric: On Arcane Curiosities
step
  .goto 1421,44.52,43.02
  .accept 92401 -- A Frightened Request
]]
)
