-- PLANNED: the thorough alt 4 route for Tauren Druid (HARDCORE): tools/route_planner.py tauren --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"tauren-druid-26-the-barrens",
	[[
#chapter 29-30 The Barrens
step
  .goto 1413,46.37,73.79
  .accept 79192 -- Stepping Stones
step
  .goto 1413,44.86,59.14
  .accept 1130 -- Melor Sends Word
  .goto 1413,45.1,57.68
  .turnin 1153 -- A New Ore Sample
step
  .todo "travel from The Barrens to Thunder Bluff: the travel graph has no route yet"
  .zone 1456 >> Go to Thunder Bluff
step
  .goto 1456,61.54,80.92
  .turnin 1130 -- Melor Sends Word
step
  .todo "travel from Thunder Bluff to Stonetalon Mountains: the travel graph has no route yet"
  .zone 1442 >> Go to Stonetalon Mountains
step
  .goto 1442,40.76,52.57
  .turnin 79192 -- Stepping Stones
step
  .goto 1442,58.99,62.6
  .turnin 1095 -- Further Instructions
  .accept 1096 -- Gerenzo Wrenchwhistle
step
  .goto 1442,64.49,40.25
  .complete 1096 -- Gerenzo Wrenchwhistle
step
  .goto 1442,58.99,62.6
  .turnin 1096 -- Gerenzo Wrenchwhistle
step
  .level 30 -- reach it first: kill or grind on the way
]]
)
