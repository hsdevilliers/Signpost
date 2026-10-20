-- PLANNED: the beam route for Troll Hunter, planned by tools/route_planner.py on 2026-10-20 (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"troll-hunter-17-thousand-needles",
	[[
#chapter 26-27 Thousand Needles
step
  .goto 1441,32.24,22.17
  .accept 4542 -- Message to Freewind Post
step
  .goto 1441,37.95,26.45
  .accept 4904 -- Free at Last
step
  .goto 1441,44.93,48.92
  .accept 4767 -- Wind Rider
  .accept 4821 -- Alien Egg
  .turnin 4542 -- Message to Freewind Post
  .accept 4841 -- Pacify the Centaur
  .accept 5147 -- Wanted - Arnak Grimtotem
  .turnin 1196 -- The Sacred Flame
  .accept 1197 -- The Sacred Flame
  .turnin 4904 -- Free at Last
step
  .goto 1441,52.34,55.25
  .complete 4821 -- Alien Egg
step
  .goto 1441,44.64,50.29
  .turnin 4821 -- Alien Egg
  .accept 4865 -- Serpent Wild
step
  .goto 1441,44.23,36.83
  .complete 4841,3 -- Pacify the Centaur
  .complete 4841,1 -- Pacify the Centaur
  .complete 1197 -- The Sacred Flame
step
  .goto 1441,46.14,51.71
  .turnin 1197 -- The Sacred Flame
step
  .goto 1441,47.17,40.32
  .complete 4841,2 -- Pacify the Centaur
step
  .goto 1441,45.67,50.74
  .turnin 4841 -- Pacify the Centaur
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
  .accept 5062 -- Sacred Fire
  .accept 5151 -- Hypercapacitor Gizmo
  .optional 5151 -- group quest: Hypercapacitor Gizmo
step
  .goto 1441,17.89,40.57
  .accept 4770 -- Homeward Bound
step
  .goto 1441,18.02,41.68
  .complete 4767 -- Wind Rider
step
  .goto 1441,21.54,32.35
  .turnin 4770 -- Homeward Bound
step
  .goto 1441,36.05,37.41
  .complete 5062 -- Sacred Fire
step
  .goto 1441,44.93,48.92
  .turnin 4767 -- Wind Rider
step
  .goto 1441,38.11,26.87
  .complete 5147 -- Wanted - Arnak Grimtotem
step
  .goto 1441,45.67,50.74
  .turnin 5147 -- Wanted - Arnak Grimtotem
step
  .goto 1441,55.62,50.45
  .complete 1153 -- A New Ore Sample
step
  .goto 1441,53.95,41.49
  .accept 1149 -- Test of Faith
  .turnin 1149 -- Test of Faith
  .accept 1150 -- Test of Endurance
step
  .level 27 -- reach it first: kill or grind on the way
step
  .goto 1441,53.95,41.49
  .todo "Test of Endurance: objective 1 has no position in the pack"
  .complete 1150,1 -- Test of Endurance
  .turnin 1150 -- Test of Endurance
  .accept 1151 -- Test of Strength
  .optional 1151 -- group quest: Test of Strength
step
  .todo "border The Barrens/Thousand Needles: no crossing coordinates yet (record them in game or in Borders.lua)"
  .zone 1413 >> Go into The Barrens
]]
)
