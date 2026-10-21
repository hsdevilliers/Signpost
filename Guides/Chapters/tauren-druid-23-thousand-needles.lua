-- PLANNED: the thorough alt 4 route for Tauren Druid (HARDCORE): tools/route_planner.py tauren --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"tauren-druid-23-thousand-needles",
	[[
#chapter 27-28 Thousand Needles
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
  .accept 5064 -- Grimtotem Spying
step
  .goto 1441,33.76,39.99
  .complete 5064 -- Grimtotem Spying
step
  .goto 1441,21.54,32.35
  .turnin 4865 -- Serpent Wild
step
  .goto 1441,45.67,50.74
  .turnin 5064 -- Grimtotem Spying
  .goto 1441,46.0,50.86
  .level 25
  .accept 5147 -- Wanted - Arnak Grimtotem
  .goto 1441,44.93,48.92
  .accept 4767 -- Wind Rider
step
  .goto 1441,38.11,26.87
  .complete 5147 -- Wanted - Arnak Grimtotem
step
  .goto 1441,37.95,26.45
  .accept 4904 -- Free at Last
step
  .goto 1441,53.95,41.49
  .accept 1149 -- Test of Faith
step
  .goto 1441,45.67,50.74
  .turnin 5147 -- Wanted - Arnak Grimtotem
  .goto 1441,45.97,51.61
  .turnin 4904 -- Free at Last
step
  .goto 1441,18.02,41.68
  .complete 4767 -- Wind Rider
step
  .goto 1441,17.89,40.57
  .accept 4770 -- Homeward Bound
step
  .goto 1441,21.54,32.35
  .turnin 4770 -- Homeward Bound
step
  .goto 1441,26.43,32.93
  .complete 1149 -- Test of Faith
step
  .goto 1441,44.93,48.92
  .turnin 4767 -- Wind Rider
step
  .goto 1441,53.95,41.49
  .turnin 1149 -- Test of Faith
step
  .todo "border The Barrens/Thousand Needles: no crossing coordinates yet (record them in game or in Borders.lua)"
  .zone 1413 >> Go into The Barrens
]]
)
