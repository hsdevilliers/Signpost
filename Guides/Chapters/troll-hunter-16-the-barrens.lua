-- PLANNED: the beam route for Troll Hunter, planned by tools/route_planner.py on 2026-10-20 (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"troll-hunter-16-the-barrens",
	[[
#chapter 25-26 The Barrens
step
  .goto 1413,42.87,55.25
  .complete 878,1 -- Tribes at War
step
  .goto 1413,43.27,48.0
  .complete 878,3 -- Tribes at War
step
  .goto 1413,44.78,51.51
  .complete 878,2 -- Tribes at War
step
  .goto 1413,44.55,59.26
  .turnin 878 -- Tribes at War
  .accept 5052 -- Blood Shards of Agamaggan
step
  .goto 1413,42.87,55.25
  .complete 5052 -- Blood Shards of Agamaggan
step
  .goto 1413,44.55,59.26
  .turnin 5052 -- Blood Shards of Agamaggan
  .accept 879 -- Betrayal from Within
step
  .goto 1413,46.37,73.79
  .accept 79192 -- Stepping Stones
step
  .goto 1413,45.12,80.07
  .complete 879,1 -- Betrayal from Within
step
  .goto 1413,40.15,80.54
  .complete 879,3 -- Betrayal from Within
step
  .goto 1413,43.75,83.26
  .complete 879,2 -- Betrayal from Within
step
  .todo "border The Barrens/Thousand Needles: no crossing coordinates yet (record them in game or in Borders.lua)"
  .zone 1441 >> Go into Thousand Needles
]]
)
