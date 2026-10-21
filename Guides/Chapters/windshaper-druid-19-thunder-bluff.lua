-- PLANNED: the beam route for Skyborne Druid (HARDCORE): tools/route_planner.py windshaper --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"windshaper-druid-19-thunder-bluff",
	[[
#chapter 26-26 Thunder Bluff
step
  .goto 1456,54.14,47.05
  .turnin 97538 -- Pigments for Paints
step
  .todo "travel from Thunder Bluff to The Barrens: the travel graph has no route yet"
  .zone 1413 >> Go to The Barrens
step
  .goto 1413,46.37,73.79
  .accept 79192 -- Stepping Stones
  .goto 1413,45.89,77.0
  .accept 843 -- Gann's Reclamation
step
  .goto 1413,47.61,85.33
  .complete 843 -- Gann's Reclamation
step
  .goto 1413,45.89,77.0
  .turnin 843 -- Gann's Reclamation
  .accept 846 -- Revenge of Gann
step
  .goto 1413,49.22,84.08
  .complete 846 -- Revenge of Gann
step
  .goto 1413,45.89,77.0
  .turnin 846 -- Revenge of Gann
  .accept 849 -- Revenge of Gann
step
  .goto 1413,46.97,85.63
  .complete 849 -- Revenge of Gann
]]
)
