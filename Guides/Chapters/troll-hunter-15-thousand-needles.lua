-- PLANNED: the beam route for Troll Hunter: tools/route_planner.py troll --preset all --install --force --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"troll-hunter-15-thousand-needles",
	[[
#chapter 28-29 Thousand Needles
step
  .goto 1441,44.64,50.29
  .accept 4821 -- Alien Egg
  .goto 1441,46.0,50.86
  .accept 5147 -- Wanted - Arnak Grimtotem
step
  .goto 1441,45.14,49.11 >> Go to the flight master
  .fp 1441,Freewind Post
step
  .goto 1441,46.21,51.51
  .accept 98069 -- Stolen Freewind Supplies
  .accept 98070 -- Stop the Screeching
  .todo "Stolen Freewind Supplies: objective 1 has no position in the pack"
  .complete 98069,1 -- Stolen Freewind Supplies
  .turnin 98069 -- Stolen Freewind Supplies
step
  .goto 1441,37.63,56.13
  .complete 4821 -- Alien Egg
step
  .goto 1441,27.84,50.23
  .complete 98070 -- Stop the Screeching
step
  .goto 1441,44.64,50.29
  .turnin 4821 -- Alien Egg
  .accept 4865 -- Serpent Wild
  .goto 1441,46.21,51.51
  .turnin 98070 -- Stop the Screeching
step
  .goto 1441,21.54,32.35
  .turnin 4865 -- Serpent Wild
  .goto 1441,21.43,32.55
  .accept 5151 -- Hypercapacitor Gizmo
  .optional 5151 -- group quest: Hypercapacitor Gizmo
step
  .goto 1441,22.76,24.62
  .complete 5151 -- Hypercapacitor Gizmo
  .optional 5151 -- group quest: Hypercapacitor Gizmo
step
  .goto 1441,21.43,32.55
  .turnin 5151 -- Hypercapacitor Gizmo
  .optional 5151 -- group quest: Hypercapacitor Gizmo
step
  .goto 1441,32.24,22.17
  .accept 4542 -- Message to Freewind Post
step
  .goto 1441,38.11,26.87
  .complete 5147 -- Wanted - Arnak Grimtotem
step
  .goto 1441,45.67,50.74
  .turnin 4542 -- Message to Freewind Post
  .turnin 5147 -- Wanted - Arnak Grimtotem
  .accept 4841 -- Pacify the Centaur
step
  .goto 1441,46.57,41.16
  .complete 4841 -- Pacify the Centaur
step
  .goto 1441,53.95,41.49
  .accept 1149 -- Test of Faith
step
  .goto 1441,45.67,50.74
  .turnin 4841 -- Pacify the Centaur
  .accept 5064 -- Grimtotem Spying
step
  .goto 1441,33.76,39.99
  .complete 5064 -- Grimtotem Spying
step
  .goto 1441,26.43,32.93
  .complete 1149 -- Test of Faith
step
  .goto 1441,45.67,50.74
  .turnin 5064 -- Grimtotem Spying
step
  .goto 1441,53.95,41.49
  .turnin 1149 -- Test of Faith
  .accept 1150 -- Test of Endurance
  .todo "Test of Endurance: objective 1 has no position in the pack"
  .complete 1150,1 -- Test of Endurance
  .turnin 1150 -- Test of Endurance
step
  .goto 1441,45.14,49.11 >> Go to the flight master
  .fly Camp Taurajo
]]
)
