-- PLANNED: the thorough alt 4 route for Troll Hunter: tools/route_planner.py troll --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"troll-hunter-14-the-barrens",
	[[
#chapter 22-24 The Barrens
step
  .goto 1413,49.33,50.32
  .complete 4921 -- Lost in Battle
  .complete 899 -- Consumed by Hatred
  .complete 95774 -- Her Name Is Olgra
step
  .goto 1413,52.02,46.47
  .complete 905 -- The Angry Scytheclaws
step
  .goto 1413,55.61,42.75
  .complete 877 -- The Stagnant Oasis
step
  .goto 1413,52.26,31.93
  .turnin 877 -- The Stagnant Oasis
  .goto 1413,51.95,31.58
  .turnin 899 -- Consumed by Hatred
  .turnin 4921 -- Lost in Battle
  .turnin 95774 -- Her Name Is Olgra
  .goto 1413,52.23,31.01
  .turnin 905 -- The Angry Scytheclaws
  .accept 3261 -- Jorn Skyseer
step
  .goto 1413,46.01,35.74
  .accept 1487 -- Deviate Eradication
  .todo "Deviate Eradication: objective 1 has no position in the pack"
  .complete 1487,1 -- Deviate Eradication
  .todo "Deviate Eradication: objective 2 has no position in the pack"
  .complete 1487,2 -- Deviate Eradication
  .todo "Deviate Eradication: objective 3 has no position in the pack"
  .complete 1487,3 -- Deviate Eradication
  .todo "Deviate Eradication: objective 4 has no position in the pack"
  .complete 1487,4 -- Deviate Eradication
  .turnin 1487 -- Deviate Eradication
  .optional 1487 -- group quest: Deviate Eradication
step
  .goto 1413,45.1,57.68
  .accept 893 -- Weapons of Choice
step
  .goto 1413,44.45,59.15 >> Go to the flight master
  .fp 1413,Camp Taurajo
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
  .goto 1413,48.44,75.43
  .complete 907 -- Enraged Thunder Lizards
  .complete 97250 -- Wrongly Blamed, Justly Corrected
step
  .goto 1413,44.62,59.27
  .turnin 97250 -- Wrongly Blamed, Justly Corrected
  .goto 1413,44.86,59.14
  .turnin 907 -- Enraged Thunder Lizards
  .accept 913 -- Cry of the Thunderhawk
step
  .goto 1413,45.51,53.76
  .complete 878,1 -- Tribes at War
  .complete 878,2 -- Tribes at War
step
  .goto 1413,43.27,48.0
  .complete 878,3 -- Tribes at War
  .complete 913 -- Cry of the Thunderhawk
step
  .goto 1413,44.86,59.14
  .turnin 913 -- Cry of the Thunderhawk
  .accept 874 -- Mahren Skyseer
  .goto 1413,44.55,59.26
  .turnin 878 -- Tribes at War
  .accept 5052 -- Blood Shards of Agamaggan
step
  .goto 1413,41.16,79.14
  .complete 5052 -- Blood Shards of Agamaggan
  .complete 893,2 -- Weapons of Choice
  .complete 893,3 -- Weapons of Choice
step
  .goto 1413,43.97,80.51
  .complete 893,1 -- Weapons of Choice
step
  .goto 1413,46.35,73.88
  .accept 79192 -- Stepping Stones
step
  .goto 1413,44.55,59.26
  .turnin 5052 -- Blood Shards of Agamaggan
  .goto 1413,45.1,57.68
  .turnin 893 -- Weapons of Choice
step
  .todo "Walk from The Barrens to Thunder Bluff: the guide has no waypoints for this yet, so find your own way. This step is done when you arrive in Thunder Bluff."
  .zone 1456 >> Go to Thunder Bluff
]]
)
