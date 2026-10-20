-- PLANNED: the thorough alt 1 route for Troll Hunter: tools/route_planner.py troll --preset all --install --force --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"troll-hunter-19-thousand-needles",
	[[
#chapter 28-29 Thousand Needles
step
  .goto 1441,52.34,55.25
  .complete 4821 -- Alien Egg
step
  .goto 1441,44.64,50.29
  .turnin 4821 -- Alien Egg
  .accept 4865 -- Serpent Wild
step
  .goto 1441,21.54,32.35
  .turnin 4865 -- Serpent Wild
  .goto 1441,21.43,32.55
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
  .goto 1441,44.93,48.92
  .turnin 4767 -- Wind Rider
  .goto 1441,45.67,50.74
  .turnin 4542 -- Message to Freewind Post
  .turnin 5147 -- Wanted - Arnak Grimtotem
  .accept 4841 -- Pacify the Centaur
step
  .goto 1441,46.57,41.16
  .complete 4841 -- Pacify the Centaur
step
  .goto 1441,45.67,50.74
  .turnin 4841 -- Pacify the Centaur
step
  .goto 1441,27.84,50.23
  .complete 98070 -- Stop the Screeching
step
  .goto 1441,46.21,51.51
  .turnin 98070 -- Stop the Screeching
step
  .goto 1441,77.79,77.27
  .level 28
  .accept 1110 -- Rocket Car Parts
  .goto 1441,78.06,77.13
  .accept 1104 -- Salt Flat Venom
  .goto 1441,78.14,77.12
  .accept 1105 -- Hardened Shells
step
  .goto 1441,77.96,85.39
  .complete 1110 -- Rocket Car Parts
  .complete 1105 -- Hardened Shells
step
  .goto 1441,77.79,77.27
  .turnin 1110 -- Rocket Car Parts
  .goto 1441,78.14,77.12
  .turnin 1105 -- Hardened Shells
  .goto 1441,80.18,75.88
  .level 29
  .accept 1176 -- Load Lightening
step
  .goto 1441,70.99,75.35
  .complete 1176 -- Load Lightening
  .complete 1104 -- Salt Flat Venom
step
  .goto 1441,78.06,77.13
  .turnin 1104 -- Salt Flat Venom
  .goto 1441,80.18,75.88
  .turnin 1176 -- Load Lightening
step
  .todo "border The Barrens/Thousand Needles: no crossing coordinates yet (record them in game or in Borders.lua)"
  .zone 1413 >> Go into The Barrens
]]
)
