-- PLANNED: the thorough alt 4 route for Skyborne Druid (HARDCORE): tools/route_planner.py windshaper --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"windshaper-druid-12-the-barrens",
	[[
#chapter 22-23 The Barrens
step
  .goto 1413,51.95,31.58
  .turnin 899 -- Consumed by Hatred
  .turnin 4921 -- Lost in Battle
  .turnin 95774 -- Her Name Is Olgra
step
  .goto 1413,57.62,27.24
  .complete 97003 -- Chol'aruk the Ravener
step
  .goto 1413,52.65,29.06
  .turnin 97003 -- Chol'aruk the Ravener
step
  .goto 1413,62.98,37.22
  .turnin 1094 -- Further Instructions
  .goto 1413,63.35,38.45
  .turnin 896 -- Miner's Fortune
step
  .goto 1413,44.86,59.14
  .accept 913 -- Cry of the Thunderhawk
  .accept 6382 -- The Ashenvale Hunt
  .goto 1413,44.62,59.27
  .accept 97250 -- Wrongly Blamed, Justly Corrected
  .goto 1413,44.55,59.26
  .accept 878 -- Tribes at War
step
  .goto 1413,44.77,63.05
  .complete 913 -- Cry of the Thunderhawk
step
  .goto 1413,44.86,59.14
  .turnin 913 -- Cry of the Thunderhawk
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
  .goto 1413,48.77,77.21
  .complete 97250 -- Wrongly Blamed, Justly Corrected
step
  .goto 1413,46.37,73.79
  .accept 79192 -- Stepping Stones
step
  .goto 1413,44.62,59.27
  .turnin 97250 -- Wrongly Blamed, Justly Corrected
  .goto 1413,44.55,59.26
  .turnin 5052 -- Blood Shards of Agamaggan
  .goto 1413,45.1,57.68
  .accept 893 -- Weapons of Choice
step
  .todo "border The Barrens/Stonetalon Mountains: no crossing coordinates yet (record them in game or in Borders.lua)"
  .zone 1442 >> Go into Stonetalon Mountains
]]
)
