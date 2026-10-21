-- PLANNED: the thorough alt 4 route for Tauren Druid (HARDCORE): tools/route_planner.py tauren --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"tauren-druid-25-thousand-needles",
	[[
#chapter 29-29 Thousand Needles
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
  .goto 1441,84.2,70.73
  .complete 1176 -- Load Lightening
  .complete 1105 -- Hardened Shells
  .complete 1104 -- Salt Flat Venom
step
  .goto 1441,80.18,75.88
  .turnin 1176 -- Load Lightening
  .goto 1441,78.14,77.12
  .turnin 1105 -- Hardened Shells
  .goto 1441,78.06,77.13
  .turnin 1104 -- Salt Flat Venom
step
  .goto 1441,66.27,49.56
  .complete 1153 -- A New Ore Sample
step
  .todo "border The Barrens/Thousand Needles: no crossing coordinates yet (record them in game or in Borders.lua)"
  .zone 1413 >> Go into The Barrens
]]
)
