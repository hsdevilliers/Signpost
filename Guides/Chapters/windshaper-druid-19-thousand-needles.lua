-- PLANNED: the thorough alt 5 route for Skyborne Druid (HARDCORE): tools/route_planner.py windshaper --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"windshaper-druid-19-thousand-needles",
	[[
#chapter 26-27 Thousand Needles
step
  .goto 1441,32.24,22.17
  .level 23
  .accept 4542 -- Message to Freewind Post
step
  .goto 1441,44.64,50.29
  .level 24
  .accept 4821 -- Alien Egg
  .goto 1441,45.67,50.74
  .turnin 4542 -- Message to Freewind Post
  .accept 4841 -- Pacify the Centaur
step
  .goto 1441,52.34,55.25
  .complete 4821 -- Alien Egg
step
  .goto 1441,44.64,50.29
  .turnin 4821 -- Alien Egg
  .accept 4865 -- Serpent Wild
step
  .goto 1441,46.57,41.16
  .complete 4841 -- Pacify the Centaur
step
  .goto 1441,45.67,50.74
  .turnin 4841 -- Pacify the Centaur
step
  .level 27 -- reach it first: kill or grind on the way
step
  .goto 1441,45.67,50.74
  .accept 5064 -- Grimtotem Spying
step
  .goto 1441,39.34,41.53
  .complete 5064 -- Grimtotem Spying
step
  .goto 1441,45.67,50.74
  .turnin 5064 -- Grimtotem Spying
step
  .goto 1441,21.54,32.35
  .turnin 4865 -- Serpent Wild
step
  .todo "border The Barrens/Thousand Needles: no crossing coordinates yet (record them in game or in Borders.lua)"
  .zone 1413 >> Go into The Barrens
]]
)
