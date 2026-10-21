-- PLANNED: the thorough route for Tauren Druid (HARDCORE): tools/route_planner.py tauren --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"tauren-druid-19-ashenvale",
	[[
#chapter 26-26 Ashenvale
step
  .goto 1440,11.9,34.54
  .accept 216 -- Between a Rock and a Thistlefur
step
  .goto 1440,11.56,34.29
  .accept 6921 -- Amongst the Ruins
  .todo "Amongst the Ruins: objective 1 has no position in the pack"
  .complete 6921,1 -- Amongst the Ruins
  .turnin 6921 -- Amongst the Ruins
step
  .goto 1440,31.74,38.0
  .complete 216 -- Between a Rock and a Thistlefur
step
  .goto 1440,11.9,34.54
  .turnin 216 -- Between a Rock and a Thistlefur
  .accept 6621 -- King of the Foulweald
  .todo "King of the Foulweald: objective 1 has no position in the pack"
  .complete 6621,1 -- King of the Foulweald
  .turnin 6621 -- King of the Foulweald
step
  .todo "border The Barrens/Ashenvale: no crossing coordinates yet (record them in game or in Borders.lua)"
  .zone 1413 >> Go into The Barrens
step
  .goto 1413,39.16,12.17
  .complete 876 -- Serena Bloodfeather
step
  .goto 1413,51.62,30.9
  .turnin 876 -- Serena Bloodfeather
step
  .goto 1413,45.89,77.0
  .accept 846 -- Revenge of Gann
step
  .goto 1413,49.22,84.08
  .complete 846 -- Revenge of Gann
step
  .goto 1413,45.89,77.0
  .turnin 846 -- Revenge of Gann
  .accept 849 -- Revenge of Gann
step
  .todo "border The Barrens/Thousand Needles: no crossing coordinates yet (record them in game or in Borders.lua)"
  .zone 1441 >> Go into Thousand Needles
]]
)
