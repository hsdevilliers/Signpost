-- PLANNED: the thorough route for Skyborne Druid (HARDCORE): tools/route_planner.py windshaper --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"windshaper-druid-15-stonetalon-mountains",
	[[
#chapter 27-27 Stonetalon Mountains
step
  .goto 1442,40.76,52.57
  .turnin 79192 -- Stepping Stones
step
  .goto 1442,47.5,41.0
  .complete 97538 -- Pigments for Paints
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
  .goto 1442,45.12,59.84 >> Go to the flight master
  .fly Thunder Bluff
step
  .goto 1456,54.14,47.05
  .turnin 97538 -- Pigments for Paints
step
  .goto 1456,47.0,49.83 >> Go to the flight master
  .fly Camp Taurajo
step
  .todo "Walk from The Barrens to Ashenvale: the guide has no waypoints for this yet, so find your own way. This step is done when you arrive in Ashenvale."
  .zone 1440 >> Go to Ashenvale
]]
)
