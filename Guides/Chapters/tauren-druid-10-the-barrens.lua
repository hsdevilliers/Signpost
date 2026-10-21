-- PLANNED: the thorough alt 3 route for Tauren Druid (HARDCORE): tools/route_planner.py tauren --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"tauren-druid-10-the-barrens",
	[[
#chapter 20-20 The Barrens
step
  .goto 1413,39.16,12.17
  .complete 876 -- Serena Bloodfeather
step
  .goto 1413,51.62,30.9
  .turnin 876 -- Serena Bloodfeather
  .accept 1060 -- Letter to Jin'Zil
step
  .goto 1413,35.26,27.88
  .accept 1062 -- Goblin Invaders
  .goto 1413,35.19,27.76
  .accept 6548 -- Avenge My Village
step
  .todo "Walk from The Barrens to Stonetalon Mountains: the guide has no waypoints for this yet, so find your own way. This step is done when you arrive in Stonetalon Mountains."
  .zone 1442 >> Go to Stonetalon Mountains
]]
)
