-- PLANNED: the beam route for Skyborne Druid (HARDCORE): tools/route_planner.py windshaper --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"windshaper-druid-17-the-barrens",
	[[
#chapter 25-25 The Barrens
step
  .goto 1413,41.93,78.74
  .complete 893 -- Weapons of Choice
step
  .goto 1413,45.1,57.68
  .turnin 893 -- Weapons of Choice
step
  .goto 1413,48.77,77.21
  .complete 97250 -- Wrongly Blamed, Justly Corrected
step
  .goto 1413,44.62,59.27
  .turnin 97250 -- Wrongly Blamed, Justly Corrected
step
  .goto 1413,42.87,55.25
  .complete 878,1 -- Tribes at War
step
  .todo "travel from The Barrens to Thunder Bluff: the travel graph has no route yet"
  .zone 1456 >> Go to Thunder Bluff
step
  .goto 1456,76.48,27.22
  .turnin 98362 .class DRUID -- To Thunder Bluff
step
  .goto 1456,54.14,47.05
  .accept 97538 -- Pigments for Paints
step
  .todo "travel from Thunder Bluff to Stonetalon Mountains: the travel graph has no route yet"
  .zone 1442 >> Go to Stonetalon Mountains
]]
)
