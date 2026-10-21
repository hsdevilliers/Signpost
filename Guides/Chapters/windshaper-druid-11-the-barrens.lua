-- PLANNED: the thorough alt 2 route for Skyborne Druid (HARDCORE): tools/route_planner.py windshaper --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"windshaper-druid-11-the-barrens",
	[[
#chapter 27-27 The Barrens
step
  .goto 1413,46.97,85.63
  .complete 849 -- Revenge of Gann
step
  .goto 1413,45.89,77.0
  .turnin 849 -- Revenge of Gann
  .goto 1413,46.35,73.88
  .accept 79192 -- Stepping Stones
step
  .goto 1413,65.84,43.86
  .turnin 874 -- Mahren Skyseer
  .accept 873 -- Isha Awak
step
  .goto 1413,63.53,53.85
  .complete 873 -- Isha Awak
step
  .goto 1413,65.84,43.86
  .turnin 873 -- Isha Awak
step
  .goto 1413,62.98,37.22
  .turnin 1094 -- Further Instructions
  .accept 1095 -- Further Instructions
step
  .goto 1413,62.37,37.62
  .accept 1221 -- Blueleaf Tubers
  .todo "Blueleaf Tubers: objective 1 has no position in the pack"
  .complete 1221,1 -- Blueleaf Tubers
step
  .goto 1413,62.34,37.6
  .complete 1221,4 -- Blueleaf Tubers
  .complete 1221,3 -- Blueleaf Tubers
  .complete 1221,2 -- Blueleaf Tubers
step
  .goto 1413,62.37,37.62
  .turnin 1221 -- Blueleaf Tubers
step
  .goto 1413,63.08,37.16 >> Go to the flight master
  .fly Sun Rock Retreat
]]
)
