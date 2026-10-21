-- PLANNED: the beam route for Skyborne Druid (HARDCORE): tools/route_planner.py windshaper --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"windshaper-druid-23-stonetalon-mountains",
	[[
#chapter 28-29 Stonetalon Mountains
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
  .goto 1442,40.76,52.57
  .turnin 79192 -- Stepping Stones
step
  .todo "travel from Stonetalon Mountains to Mulgore: the travel graph has no route yet"
  .zone 1412 >> Go to Mulgore
step
  .level 29 -- reach it first: kill or grind on the way
step
  .goto 1412,32.47,19.98
  .accept 96260 -- Stronger than Steel
  .goto 1412,32.5,20.66
  .accept 96241 -- Talkin' bout Toxins, Mon
  .goto 1412,33.41,22.59
  .accept 96259 -- Defending the Dead
step
  .goto 1412,33.33,15.39
  .complete 96259 -- Defending the Dead
  .complete 96260 -- Stronger than Steel
  .complete 96241 -- Talkin' bout Toxins, Mon
]]
)
