-- PLANNED: the thorough alt 3 route for Tauren Druid (HARDCORE): tools/route_planner.py tauren --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"tauren-druid-08-the-barrens",
	[[
#chapter 16-19 The Barrens
step
  .goto 1413,62.26,19.38
  .turnin 840 -- Conscript of the Horde
  .accept 842 -- Crossroads Conscription
step
  .goto 1413,52.23,31.01
  .turnin 842 -- Crossroads Conscription
  .accept 905 -- The Angry Scytheclaws
step
  .goto 1413,55.61,42.75
  .complete 877 -- The Stagnant Oasis
step
  .goto 1413,52.6,46.11
  .complete 905 -- The Angry Scytheclaws
step
  .goto 1413,52.26,31.93
  .turnin 877 -- The Stagnant Oasis
  .accept 880 -- Altered Beings
  .goto 1413,52.23,31.01
  .turnin 905 -- The Angry Scytheclaws
step
  .goto 1413,46.98,39.59
  .complete 880 -- Altered Beings
step
  .goto 1413,52.26,31.93
  .turnin 880 -- Altered Beings
step
  .goto 1413,39.18,15.68
  .complete 875 -- Harpy Lieutenants
step
  .goto 1413,43.8,12.21
  .accept 95494 -- Bruised Pride and Lion Hides
  .accept 95495 -- The Hermit Tanner
  .accept 95507 -- Vrang's Game
step
  .goto 1413,43.9,14.5
  .complete 95507 -- Vrang's Game
  .complete 95494 -- Bruised Pride and Lion Hides
step
  .goto 1413,43.8,12.21
  .turnin 95494 -- Bruised Pride and Lion Hides
  .turnin 95507 -- Vrang's Game
  .goto 1413,42.02,11.45
  .turnin 95495 -- The Hermit Tanner
  .accept 95621 -- Trouble in the Valley
step
  .goto 1413,41.83,15.54
  .complete 95621 -- Trouble in the Valley
step
  .goto 1413,42.02,11.45
  .turnin 95621 -- Trouble in the Valley
step
  .goto 1413,51.62,30.9
  .turnin 875 -- Harpy Lieutenants
  .goto 1413,52.23,31.01
  .accept 3261 -- Jorn Skyseer
step
  .goto 1413,62.37,37.62
  .accept 865 -- Raptor Horns
  .note Takk the Leaper, a rare elite raptor (near 59.6,8.3), drops the horns too: take them from the ordinary raptors and keep away from him.
  .goto 1413,63.35,38.45
  .accept 896 -- Miner's Fortune
step
  .goto 1413,59.99,4.12
  .complete 896 -- Miner's Fortune
step
  .goto 1413,56.52,7.45
  .accept 858 -- Ignition
step
  .goto 1413,56.27,8.58
  .complete 858 -- Ignition
step
  .goto 1413,56.52,7.45
  .turnin 858 -- Ignition
step
  .goto 1413,48.12,5.42
  .level 17
  .accept 6543 -- The Warsong Reports
  .todo "The Warsong Reports: objective 1 has no position in the pack"
  .complete 6543,1 -- The Warsong Reports
  .todo "The Warsong Reports: objective 2 has no position in the pack"
  .complete 6543,2 -- The Warsong Reports
  .todo "The Warsong Reports: objective 3 has no position in the pack"
  .complete 6543,3 -- The Warsong Reports
  .turnin 6543 -- The Warsong Reports
step
  .goto 1413,63.35,38.45
  .turnin 896 -- Miner's Fortune
step
  .goto 1413,52.15,46.62
  .complete 865 -- Raptor Horns
step
  .goto 1413,44.86,59.14
  .turnin 3261 -- Jorn Skyseer
  .accept 882 -- Ishamuhale
  .todo "Ishamuhale: objective 1 has no position in the pack"
  .complete 882,1 -- Ishamuhale
  .turnin 882 -- Ishamuhale
  .accept 907 -- Enraged Thunder Lizards
step
  .goto 1413,44.45,59.15 >> Go to the flight master
  .fp 1413,Camp Taurajo
step
  .goto 1413,48.95,59.71
  .complete 907 -- Enraged Thunder Lizards
step
  .goto 1413,44.86,59.14
  .turnin 907 -- Enraged Thunder Lizards
step
  .goto 1413,63.56,49.14
  .complete 895 -- WANTED: Baron Longshore
step
  .goto 1413,62.37,37.62
  .turnin 865 -- Raptor Horns
  .goto 1413,62.68,36.23
  .turnin 895 -- WANTED: Baron Longshore
  .level 19 -- reach it first: kill or grind on the way
  .note Grind about 450 experience before you go on: about 3 kills of creatures near your level (an estimate)
step
  .goto 1413,62.7,36.3
  .accept 79097 -- Baxtan: On Destructive Magics
  .complete 79097,1 -- Baxtan: On Destructive Magics
step
  .goto 1413,51.95,31.58
  .accept 899 -- Consumed by Hatred
  .accept 4921 -- Lost in Battle
  .accept 95774 -- Her Name Is Olgra
step
  .goto 1413,49.33,50.32
  .complete 4921 -- Lost in Battle
  .complete 899 -- Consumed by Hatred
  .complete 95774 -- Her Name Is Olgra
step
  .goto 1413,49.3,32.88
  .accept 78143 -- Secrets of the Dreamers
  .complete 78143,1 -- Secrets of the Dreamers
step
  .goto 1413,51.95,31.58
  .turnin 899 -- Consumed by Hatred
  .turnin 4921 -- Lost in Battle
  .turnin 95774 -- Her Name Is Olgra
  .goto 1413,51.62,30.9
  .accept 876 -- Serena Bloodfeather
step
  .goto 1413,56.3,8.8
  .accept 78145 -- Arcanic Systems Manual
  .complete 78145,1 -- Arcanic Systems Manual
step
  .todo "Get from The Barrens to Undercity: they are on different continents, so you need a boat, a zeppelin or another ride, and the guide has no dock for it yet. This step is done when you arrive in Undercity."
  .zone 1458 >> Go to Undercity
]]
)
