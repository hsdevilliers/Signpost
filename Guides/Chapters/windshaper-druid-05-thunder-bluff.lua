-- PLANNED: the beam route for Skyborne Druid (HARDCORE): tools/route_planner.py windshaper --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"windshaper-druid-05-thunder-bluff",
	[[
#chapter 13-14 Thunder Bluff
step
  .goto 1456,37.75,59.57
  .turnin 744 -- Preparation for Ceremony
step
  .goto 1456,39.44,65.82
  .turnin 76156 -- Stalk With The Earthmother
  .accept 76160 -- Stalk With The Earthmother
  .todo "Stalk With The Earthmother: objective 1 has no position in the pack"
  .complete 76160,1 -- Stalk With The Earthmother
  .turnin 76160 -- Stalk With The Earthmother
  .accept 76240 -- Stalk With The Earthmother
  .todo "Stalk With The Earthmother: objective 1 has no position in the pack"
  .complete 76240,1 -- Stalk With The Earthmother
  .turnin 76240 -- Stalk With The Earthmother
step
  .todo "travel from Thunder Bluff to Orgrimmar: the travel graph has no route yet"
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
