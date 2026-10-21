-- PLANNED: the thorough route for Skyborne Druid (HARDCORE): tools/route_planner.py windshaper --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"windshaper-druid-14-the-barrens",
	[[
#chapter 27-27 The Barrens
step
  .goto 1413,45.89,77.0
  .turnin 846 -- Revenge of Gann
  .accept 849 -- Revenge of Gann
step
  .goto 1413,46.97,85.63
  .complete 849 -- Revenge of Gann
step
  .goto 1413,45.89,77.0
  .turnin 849 -- Revenge of Gann
step
  .goto 1413,44.55,59.26
  .turnin 5052 -- Blood Shards of Agamaggan
step
  .goto 1413,44.45,59.15 >> Go to the flight master
  .fly Sun Rock Retreat
]]
)
