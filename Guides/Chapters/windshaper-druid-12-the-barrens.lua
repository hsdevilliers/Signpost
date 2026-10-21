-- PLANNED: the thorough route for Skyborne Druid (HARDCORE): tools/route_planner.py windshaper --preset all --install --force --quiet --completeness 0.6 --completeness-trip 45 (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"windshaper-druid-12-the-barrens",
	[[
#chapter 26-27 The Barrens
step
  .goto 1413,45.1,57.68
  .accept 893 -- Weapons of Choice
  .goto 1413,44.86,59.14
  .accept 874 -- Mahren Skyseer
  .accept 6382 -- The Ashenvale Hunt
  .goto 1413,44.62,59.27
  .accept 97250 -- Wrongly Blamed, Justly Corrected
  .goto 1413,44.55,59.26
  .accept 878 -- Tribes at War
step
  .goto 1413,41.93,78.74
  .complete 893 -- Weapons of Choice
step
  .goto 1413,48.77,77.21
  .complete 97250 -- Wrongly Blamed, Justly Corrected
step
  .goto 1413,44.62,59.27
  .turnin 97250 -- Wrongly Blamed, Justly Corrected
  .goto 1413,45.1,57.68
  .turnin 893 -- Weapons of Choice
step
  .goto 1413,62.37,37.62
  .accept 1221 -- Blueleaf Tubers
  .todo "Blueleaf Tubers: objective 1 has no position in the pack"
  .complete 1221,1 -- Blueleaf Tubers
step
  .goto 1413,62.98,37.22
  .turnin 1094 -- Further Instructions
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
  .goto 1413,53.32,53.19
  .complete 878 -- Tribes at War
step
  .goto 1413,44.55,59.26
  .turnin 878 -- Tribes at War
  .accept 5052 -- Blood Shards of Agamaggan
step
  .goto 1413,46.37,73.79
  .accept 79192 -- Stepping Stones
  .goto 1413,45.89,77.0
  .accept 843 -- Gann's Reclamation
step
  .goto 1413,47.91,84.77
  .complete 5052 -- Blood Shards of Agamaggan
  .complete 843 -- Gann's Reclamation
step
  .goto 1413,45.89,77.0
  .turnin 843 -- Gann's Reclamation
  .accept 846 -- Revenge of Gann
step
  .goto 1413,47.07,85.77
  .complete 846 -- Revenge of Gann
step
  .todo "Walk from The Barrens to Thousand Needles: the guide has no waypoints for this yet, so find your own way. This step is done when you arrive in Thousand Needles."
  .zone 1441 >> Go to Thousand Needles
]]
)
