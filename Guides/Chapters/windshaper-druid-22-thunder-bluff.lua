-- PLANNED: the thorough alt 5 route for Skyborne Druid (HARDCORE): tools/route_planner.py windshaper --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"windshaper-druid-22-thunder-bluff",
	[[
#chapter 28-29 Thunder Bluff
step
  .goto 1456,54.14,47.05
  .turnin 97538 -- Pigments for Paints
step
  .todo "travel from Thunder Bluff to The Barrens: the travel graph has no route yet"
  .zone 1413 >> Go to The Barrens
step
  .goto 1413,45.1,57.68
  .accept 1153 -- A New Ore Sample
step
  .todo "border The Barrens/Thousand Needles: no crossing coordinates yet (record them in game or in Borders.lua)"
  .zone 1441 >> Go into Thousand Needles
step
  .goto 1441,12.41,14.01
  .complete 1153 -- A New Ore Sample
step
  .goto 1441,37.95,26.45
  .accept 4904 -- Free at Last
step
  .goto 1441,44.93,48.92
  .accept 4767 -- Wind Rider
  .goto 1441,45.97,51.61
  .turnin 4904 -- Free at Last
step
  .goto 1441,18.02,41.68
  .complete 4767 -- Wind Rider
step
  .goto 1441,17.89,40.57
  .accept 4770 -- Homeward Bound
step
  .goto 1441,21.54,32.35
  .turnin 4770 -- Homeward Bound
step
  .goto 1441,44.93,48.92
  .turnin 4767 -- Wind Rider
step
  .todo "border The Barrens/Thousand Needles: no crossing coordinates yet (record them in game or in Borders.lua)"
  .zone 1413 >> Go into The Barrens
step
  .level 29 -- reach it first: kill or grind on the way
]]
)
