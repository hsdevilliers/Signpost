-- PLANNED: the thorough alt 4 route for Tauren Druid (HARDCORE): tools/route_planner.py tauren --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"tauren-druid-24-the-barrens",
	[[
#chapter 28-29 The Barrens
step
  .goto 1413,45.89,77.0
  .accept 843 -- Gann's Reclamation
step
  .goto 1413,44.55,59.26
  .turnin 879 -- Betrayal from Within
  .accept 906 -- Betrayal from Within
  .goto 1413,45.1,57.68
  .accept 1153 -- A New Ore Sample
step
  .goto 1413,51.5,30.87
  .turnin 906 -- Betrayal from Within
step
  .goto 1413,62.37,37.62
  .accept 1221 -- Blueleaf Tubers
  .todo "Blueleaf Tubers: objective 1 has no position in the pack"
  .complete 1221,1 -- Blueleaf Tubers
step
  .goto 1413,62.98,37.22
  .accept 1095 -- Further Instructions
step
  .goto 1413,62.32,37.62
  .complete 1221,2 -- Blueleaf Tubers
  .complete 1221,3 -- Blueleaf Tubers
  .complete 1221,4 -- Blueleaf Tubers
step
  .goto 1413,62.37,37.62
  .turnin 1221 -- Blueleaf Tubers
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
step
  .goto 1413,45.89,77.0
  .turnin 849 -- Revenge of Gann
step
  .level 29 -- reach it first: kill or grind on the way
step
  .goto 1413,48.97,86.31
  .accept 857 -- The Tear of the Moons
step
  .goto 1413,49.13,84.25
  .complete 857 -- The Tear of the Moons
step
  .goto 1413,48.97,86.31
  .turnin 857 -- The Tear of the Moons
step
  .todo "border The Barrens/Thousand Needles: no crossing coordinates yet (record them in game or in Borders.lua)"
  .zone 1441 >> Go into Thousand Needles
]]
)
