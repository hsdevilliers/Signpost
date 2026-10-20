-- PLANNED: the thorough alt 1 route for Troll Hunter: tools/route_planner.py troll --preset all --install --force --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"troll-hunter-13-the-barrens",
	[[
#chapter 23-24 The Barrens
step
  .goto 1413,64.3,39.13
  .complete 92706 -- WANTED: Bruuz
step
  .goto 1413,63.07,36.32
  .accept 97253 -- Parts and Pieces
  .goto 1413,62.68,36.23
  .turnin 92706 -- WANTED: Bruuz
step
  .goto 1413,62.0,45.2
  .complete 97253 -- Parts and Pieces
step
  .goto 1413,61.96,54.96
  .accept 898 -- Free From the Hold
step
  .goto 1413,57.43,53.76
  .complete 865 -- Raptor Horns
step
  .goto 1413,52.46,46.56
  .complete 905 -- The Angry Scytheclaws
step
  .goto 1413,55.61,42.75
  .complete 877 -- The Stagnant Oasis
step
  .goto 1413,62.29,39.03
  .turnin 898 -- Free From the Hold
  .goto 1413,62.37,37.62
  .turnin 865 -- Raptor Horns
  .goto 1413,63.07,36.32
  .turnin 97253 -- Parts and Pieces
step
  .goto 1413,52.26,31.93
  .turnin 877 -- The Stagnant Oasis
  .goto 1413,52.23,31.01
  .turnin 905 -- The Angry Scytheclaws
  .accept 3261 -- Jorn Skyseer
step
  .goto 1413,45.1,57.68
  .accept 893 -- Weapons of Choice
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
  .goto 1413,43.27,48.0
  .complete 878,3 -- Tribes at War
  .complete 907 -- Enraged Thunder Lizards
step
  .goto 1413,44.86,59.14
  .turnin 907 -- Enraged Thunder Lizards
  .accept 913 -- Cry of the Thunderhawk
step
  .goto 1413,42.87,55.25
  .complete 878,1 -- Tribes at War
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
  .goto 1413,44.77,63.05
  .complete 913 -- Cry of the Thunderhawk
step
  .goto 1413,44.86,59.14
  .turnin 913 -- Cry of the Thunderhawk
step
  .goto 1413,41.16,79.14
  .complete 893 -- Weapons of Choice
  .complete 879,3 -- Betrayal from Within
step
  .goto 1413,45.89,77.0
  .accept 843 -- Gann's Reclamation
  .goto 1413,46.35,73.88
  .accept 79192 -- Stepping Stones
step
  .goto 1413,48.77,77.21
  .complete 97250 -- Wrongly Blamed, Justly Corrected
step
  .goto 1413,44.62,59.27
  .turnin 97250 -- Wrongly Blamed, Justly Corrected
  .goto 1413,45.1,57.68
  .turnin 893 -- Weapons of Choice
step
  .todo "travel from The Barrens to Thunder Bluff: the travel graph has no route yet"
  .zone 1456 >> Go to Thunder Bluff
]]
)
