-- PLANNED: the thorough alt 4 route for Skyborne Druid (HARDCORE): tools/route_planner.py windshaper --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"windshaper-druid-19-thunder-bluff",
	[[
#chapter 27-27 Thunder Bluff
step
  .goto 1456,54.97,51.41
  .accept 1195 -- The Sacred Flame
  .todo "The Sacred Flame: objective 1 has no position in the pack"
  .complete 1195,1 -- The Sacred Flame
  .turnin 1195 -- The Sacred Flame
step
  .todo "travel from Thunder Bluff to The Barrens: the travel graph has no route yet"
  .zone 1413 >> Go to The Barrens
step
  .goto 1413,44.86,59.14
  .accept 874 -- Mahren Skyseer
  .goto 1413,44.55,59.26
  .accept 879 -- Betrayal from Within
step
  .goto 1413,41.16,79.14
  .complete 893,2 -- Weapons of Choice
  .complete 879,3 -- Betrayal from Within
  .complete 893,3 -- Weapons of Choice
step
  .goto 1413,43.5,82.82
  .complete 893,1 -- Weapons of Choice
  .complete 879,2 -- Betrayal from Within
  .complete 879,1 -- Betrayal from Within
step
  .goto 1413,45.89,77.0
  .accept 843 -- Gann's Reclamation
]]
)
