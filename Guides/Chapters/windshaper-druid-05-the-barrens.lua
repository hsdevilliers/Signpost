-- PLANNED: the thorough alt 4 route for Skyborne Druid (HARDCORE): tools/route_planner.py windshaper --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"windshaper-druid-05-the-barrens",
	[[
#chapter 13-14 The Barrens
step
  .goto 1413,52.76,28.2
  .complete 844 -- Plainstrider Menace
step
  .goto 1413,52.23,31.01
  .turnin 844 -- Plainstrider Menace
  .accept 845 -- The Zhevra
step
  .goto 1413,54.6,23.16
  .complete 869 -- Raptor Thieves
step
  .todo "travel from The Barrens to Orgrimmar: the travel graph has no route yet"
  .zone 1454 >> Go to Orgrimmar
step
  .goto 1454,31.73,37.82
  .turnin 95350 -- Welcome to Azeroth
  .accept 98024 -- Journey to the Crossroads
  .goto 1454,36.82,29.06
  .accept 97326 -- Rocks to Rests
step
  .goto 1454,39.2,28.3
  .complete 97326 -- Rocks to Rests
step
  .goto 1454,36.82,29.06
  .turnin 97326 -- Rocks to Rests
step
  .goto 1454,55.68,72.17
  .accept 97246 -- Meal Appeal
  .goto 1454,57.2,53.32
  .turnin 97246 -- Meal Appeal
  .accept 97249 -- Favorite Food
step
  .goto 1454,56.05,34.12
  .accept 97242 -- Yelmak's Medley
  .goto 1454,56.84,33.03
  .accept 97275 -- Whuut's the Rush
step
  .goto 1454,66.0,28.4
  .complete 97242,2 -- Yelmak's Medley
step
  .goto 1454,55.79,32.9
  .turnin 97275 -- Whuut's the Rush
]]
)
