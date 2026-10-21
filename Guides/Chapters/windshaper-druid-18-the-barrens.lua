-- PLANNED: the thorough route for Skyborne Druid (HARDCORE): tools/route_planner.py windshaper --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"windshaper-druid-18-the-barrens",
	[[
#chapter 29-29 The Barrens
step
  .goto 1413,48.97,86.31
  .accept 857 -- The Tear of the Moons
step
  .goto 1413,49.13,84.25
  .complete 857 -- The Tear of the Moons
step
  .goto 1413,48.97,86.31
  .turnin 857 -- The Tear of the Moons
step
  .goto 1413,44.45,59.15 >> Go to the flight master
  .fly Freewind Post
]]
)
