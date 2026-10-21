-- PLANNED: the thorough alt 1 route for Tauren Druid (HARDCORE): tools/route_planner.py tauren --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"tauren-druid-17-the-barrens",
	[[
#chapter 27-27 The Barrens
step
  .goto 1413,45.89,77.0
  .turnin 849 -- Revenge of Gann
step
  .goto 1413,50.73,56.83
  .complete 878,2 -- Tribes at War
step
  .goto 1413,53.32,53.19
  .complete 878,3 -- Tribes at War
  .complete 878,1 -- Tribes at War
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
  .todo "Walk from The Barrens to Ashenvale: the guide has no waypoints for this yet, so find your own way. This step is done when you arrive in Ashenvale."
  .zone 1440 >> Go to Ashenvale
]]
)
