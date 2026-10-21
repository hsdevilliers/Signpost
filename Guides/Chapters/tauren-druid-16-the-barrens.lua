-- PLANNED: the thorough route for Tauren Druid (HARDCORE): tools/route_planner.py tauren --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"tauren-druid-16-the-barrens",
	[[
#chapter 23-25 The Barrens
step
  .goto 1413,35.26,27.88
  .turnin 1062 -- Goblin Invaders
step
  .goto 1413,42.89,46.9
  .complete 907 -- Enraged Thunder Lizards
step
  .goto 1413,45.1,57.68
  .accept 893 -- Weapons of Choice
  .goto 1413,44.86,59.14
  .turnin 907 -- Enraged Thunder Lizards
  .accept 913 -- Cry of the Thunderhawk
  .accept 6382 -- The Ashenvale Hunt
  .goto 1413,44.62,59.27
  .accept 97250 -- Wrongly Blamed, Justly Corrected
  .goto 1413,44.55,59.26
  .accept 878 -- Tribes at War
step
  .goto 1413,45.51,53.76
  .complete 878,1 -- Tribes at War
  .complete 878,2 -- Tribes at War
step
  .goto 1413,43.27,48.0
  .complete 878,3 -- Tribes at War
step
  .goto 1413,44.55,59.26
  .turnin 878 -- Tribes at War
  .accept 5052 -- Blood Shards of Agamaggan
step
  .goto 1413,48.61,76.25
  .complete 913 -- Cry of the Thunderhawk
  .complete 97250 -- Wrongly Blamed, Justly Corrected
step
  .goto 1413,44.62,59.27
  .turnin 97250 -- Wrongly Blamed, Justly Corrected
  .goto 1413,44.86,59.14
  .turnin 913 -- Cry of the Thunderhawk
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
  .goto 1413,45.89,77.0
  .accept 843 -- Gann's Reclamation
step
  .goto 1413,45.12,80.07
  .complete 879,1 -- Betrayal from Within
  .complete 893,1 -- Weapons of Choice
step
  .goto 1413,43.75,83.26
  .complete 879,2 -- Betrayal from Within
step
  .goto 1413,47.51,85.38
  .complete 843 -- Gann's Reclamation
step
  .goto 1413,45.89,77.0
  .turnin 843 -- Gann's Reclamation
step
  .goto 1413,41.62,78.93
  .complete 893,3 -- Weapons of Choice
  .complete 893,2 -- Weapons of Choice
  .complete 879,3 -- Betrayal from Within
step
  .goto 1413,44.55,59.26
  .turnin 879 -- Betrayal from Within
  .accept 906 -- Betrayal from Within
  .goto 1413,45.1,57.68
  .turnin 893 -- Weapons of Choice
step
  .goto 1413,51.5,30.87
  .turnin 906 -- Betrayal from Within
step
  .todo "border The Barrens/Ashenvale: no crossing coordinates yet (record them in game or in Borders.lua)"
  .zone 1440 >> Go into Ashenvale
]]
)
