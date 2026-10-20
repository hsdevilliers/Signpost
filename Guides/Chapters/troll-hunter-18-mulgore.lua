-- PLANNED: the thorough alt 5 route for Troll Hunter: tools/route_planner.py troll --preset all --install --force --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"troll-hunter-18-mulgore",
	[[
#chapter 28-28 Mulgore
step
  .goto 1412,33.42,7.46
  .complete 96261 -- The Broodmother
step
  .goto 1412,33.41,22.59
  .turnin 96261 -- The Broodmother
step
  .todo "travel from Mulgore to Thousand Needles: the travel graph has no route yet"
  .zone 1441 >> Go to Thousand Needles
step
  .goto 1441,44.93,48.92
  .accept 4767 -- Wind Rider
  .goto 1441,44.64,50.29
  .accept 4821 -- Alien Egg
  .goto 1441,46.0,50.86
  .accept 5147 -- Wanted - Arnak Grimtotem
step
  .goto 1441,46.21,51.51
  .accept 98069 -- Stolen Freewind Supplies
  .accept 98070 -- Stop the Screeching
  .todo "Stolen Freewind Supplies: objective 1 has no position in the pack"
  .complete 98069,1 -- Stolen Freewind Supplies
  .turnin 98069 -- Stolen Freewind Supplies
step
  .goto 1441,52.34,55.25
  .complete 4821 -- Alien Egg
step
  .goto 1441,53.95,41.49
  .accept 1149 -- Test of Faith
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
]]
)
