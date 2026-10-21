-- PLANNED: the thorough alt 4 route for Skyborne Druid (HARDCORE): tools/route_planner.py windshaper --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"windshaper-druid-21-thousand-needles",
	[[
#chapter 28-29 Thousand Needles
step
  .goto 1441,17.89,40.57
  .level 25
  .accept 4770 -- Homeward Bound
step
  .goto 1441,21.54,32.35
  .turnin 4770 -- Homeward Bound
step
  .goto 1441,32.24,22.17
  .accept 4542 -- Message to Freewind Post
step
  .goto 1441,37.95,26.45
  .accept 4904 -- Free at Last
step
  .goto 1441,44.93,48.92
  .accept 4767 -- Wind Rider
  .goto 1441,44.64,50.29
  .accept 4821 -- Alien Egg
  .goto 1441,45.67,50.74
  .turnin 4542 -- Message to Freewind Post
  .accept 4841 -- Pacify the Centaur
  .goto 1441,46.0,50.86
  .accept 5147 -- Wanted - Arnak Grimtotem
  .goto 1441,45.97,51.61
  .turnin 4904 -- Free at Last
step
  .goto 1441,46.57,41.16
  .complete 4841 -- Pacify the Centaur
step
  .goto 1441,52.34,55.25
  .complete 4821 -- Alien Egg
step
  .goto 1441,45.67,50.74
  .turnin 4841 -- Pacify the Centaur
  .accept 5064 -- Grimtotem Spying
  .goto 1441,44.64,50.29
  .turnin 4821 -- Alien Egg
  .accept 4865 -- Serpent Wild
step
  .goto 1441,39.34,41.53
  .complete 5064 -- Grimtotem Spying
step
  .goto 1441,45.67,50.74
  .turnin 5064 -- Grimtotem Spying
step
  .goto 1441,53.95,41.49
  .accept 1149 -- Test of Faith
step
  .goto 1441,38.11,26.87
  .complete 5147 -- Wanted - Arnak Grimtotem
step
  .goto 1441,21.54,32.35
  .turnin 4865 -- Serpent Wild
step
  .goto 1441,18.02,41.68
  .complete 4767 -- Wind Rider
step
  .goto 1441,26.43,32.93
  .complete 1149 -- Test of Faith
step
  .goto 1441,44.93,48.92
  .turnin 4767 -- Wind Rider
  .goto 1441,45.67,50.74
  .turnin 5147 -- Wanted - Arnak Grimtotem
step
  .goto 1441,53.95,41.49
  .turnin 1149 -- Test of Faith
step
  .level 29 -- reach it first: kill or grind on the way
step
  .goto 1441,53.95,41.49
  .accept 1150 -- Test of Endurance
  .todo "Test of Endurance: objective 1 has no position in the pack"
  .complete 1150,1 -- Test of Endurance
  .turnin 1150 -- Test of Endurance
step
  .goto 1441,78.06,77.13
  .accept 1104 -- Salt Flat Venom
  .goto 1441,78.14,77.12
  .accept 1105 -- Hardened Shells
  .goto 1441,80.18,75.88
  .accept 1176 -- Load Lightening
step
  .goto 1441,79.89,85.72
  .complete 1105 -- Hardened Shells
  .complete 1176 -- Load Lightening
  .complete 1104 -- Salt Flat Venom
step
  .goto 1441,78.14,77.12
  .turnin 1105 -- Hardened Shells
  .goto 1441,78.06,77.13
  .turnin 1104 -- Salt Flat Venom
  .goto 1441,80.18,75.88
  .turnin 1176 -- Load Lightening
step
  .todo "border The Barrens/Thousand Needles: no crossing coordinates yet (record them in game or in Borders.lua)"
  .zone 1413 >> Go into The Barrens
]]
)
