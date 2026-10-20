-- PLANNED: the thorough alt 1 route for Troll Hunter: tools/route_planner.py troll --preset all --install --force --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"troll-hunter-18-the-barrens",
	[[
#chapter 27-28 The Barrens
step
  .goto 1413,47.51,85.38
  .complete 843 -- Gann's Reclamation
step
  .goto 1413,48.97,86.31
  .accept 857 -- The Tear of the Moons
step
  .goto 1413,49.13,84.25
  .complete 857 -- The Tear of the Moons
step
  .goto 1413,45.89,77.0
  .turnin 843 -- Gann's Reclamation
  .accept 846 -- Revenge of Gann
step
  .goto 1413,48.97,86.31
  .turnin 857 -- The Tear of the Moons
step
  .todo "border The Barrens/Thousand Needles: no crossing coordinates yet (record them in game or in Borders.lua)"
  .zone 1441 >> Go into Thousand Needles
step
  .goto 1441,37.95,26.45
  .level 25
  .accept 4904 -- Free at Last
step
  .goto 1441,44.93,48.92
  .accept 4767 -- Wind Rider
  .goto 1441,44.64,50.29
  .accept 4821 -- Alien Egg
  .goto 1441,46.0,50.86
  .accept 5147 -- Wanted - Arnak Grimtotem
  .goto 1441,46.21,51.51
  .level 27
  .accept 98069 -- Stolen Freewind Supplies
  .accept 98070 -- Stop the Screeching
  .goto 1441,45.97,51.61
  .turnin 4904 -- Free at Last
step
  .goto 1441,46.21,51.51
  .todo "Stolen Freewind Supplies: objective 1 has no position in the pack"
  .complete 98069,1 -- Stolen Freewind Supplies
  .turnin 98069 -- Stolen Freewind Supplies
]]
)
