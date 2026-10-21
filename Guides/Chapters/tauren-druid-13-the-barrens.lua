-- PLANNED: the thorough alt 4 route for Tauren Druid (HARDCORE): tools/route_planner.py tauren --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"tauren-druid-13-the-barrens",
	[[
#chapter 21-23 The Barrens
step
  .goto 1413,51.95,31.58
  .turnin 899 -- Consumed by Hatred
  .turnin 95774 -- Her Name Is Olgra
  .goto 1413,52.23,31.01
  .turnin 905 -- The Angry Scytheclaws
  .accept 3261 -- Jorn Skyseer
  .goto 1413,51.07,29.63
  .accept 868 -- Egg Hunt
  .goto 1413,52.65,29.06
  .accept 97003 -- Chol'aruk the Ravener
step
  .goto 1413,57.62,27.24
  .complete 97003 -- Chol'aruk the Ravener
step
  .goto 1413,52.65,29.06
  .turnin 97003 -- Chol'aruk the Ravener
step
  .goto 1413,62.98,37.22
  .turnin 1094 -- Further Instructions
step
  .goto 1413,64.3,39.13
  .complete 92706 -- WANTED: Bruuz
step
  .goto 1413,62.68,36.23
  .turnin 92706 -- WANTED: Bruuz
step
  .goto 1413,44.86,59.14
  .turnin 3261 -- Jorn Skyseer
  .accept 882 -- Ishamuhale
  .accept 6382 -- The Ashenvale Hunt
  .todo "Ishamuhale: objective 1 has no position in the pack"
  .complete 882,1 -- Ishamuhale
  .turnin 882 -- Ishamuhale
  .accept 907 -- Enraged Thunder Lizards
step
  .goto 1413,44.62,59.27
  .accept 97250 -- Wrongly Blamed, Justly Corrected
  .goto 1413,44.55,59.26
  .accept 878 -- Tribes at War
step
  .goto 1413,48.95,59.71
  .complete 907 -- Enraged Thunder Lizards
step
  .goto 1413,44.86,59.14
  .turnin 907 -- Enraged Thunder Lizards
  .accept 913 -- Cry of the Thunderhawk
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
  .goto 1413,44.55,59.26
  .turnin 5052 -- Blood Shards of Agamaggan
step
  .goto 1413,48.77,77.21
  .complete 97250 -- Wrongly Blamed, Justly Corrected
step
  .goto 1413,44.62,59.27
  .turnin 97250 -- Wrongly Blamed, Justly Corrected
  .goto 1413,45.1,57.68
  .accept 893 -- Weapons of Choice
step
  .goto 1413,43.29,70.1
  .complete 868 -- Egg Hunt
step
  .goto 1413,41.93,78.74
  .complete 893 -- Weapons of Choice
step
  .goto 1413,45.1,57.68
  .turnin 893 -- Weapons of Choice
step
  .goto 1413,49.33,50.32
  .complete 4921 -- Lost in Battle
step
  .goto 1413,51.95,31.58
  .turnin 4921 -- Lost in Battle
  .goto 1413,51.07,29.63
  .turnin 868 -- Egg Hunt
step
  .todo "border The Barrens/Ashenvale: no crossing coordinates yet (record them in game or in Borders.lua)"
  .zone 1440 >> Go into Ashenvale
]]
)
