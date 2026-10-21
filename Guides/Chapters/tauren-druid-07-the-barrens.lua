-- PLANNED: the thorough route for Tauren Druid (HARDCORE): tools/route_planner.py tauren --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"tauren-druid-07-the-barrens",
	[[
#chapter 15-18 The Barrens
step
  .goto 1413,52.23,31.01
  .turnin 842 -- Crossroads Conscription
  .accept 903 -- Prowlers of the Barrens
  .goto 1413,52.26,31.93
  .accept 877 -- The Stagnant Oasis
step
  .goto 1413,58.52,27.04
  .complete 872 -- The Disruption Ends
step
  .goto 1413,54.74,15.11
  .complete 903 -- Prowlers of the Barrens
step
  .goto 1413,52.23,31.01
  .turnin 903 -- Prowlers of the Barrens
  .accept 881 -- Echeyakee
  .todo "Echeyakee: objective 1 has no position in the pack"
  .complete 881,1 -- Echeyakee
  .turnin 881 -- Echeyakee
step
  .goto 1413,51.5,30.87
  .turnin 872 -- The Disruption Ends
step
  .goto 1413,45.34,28.41
  .accept 850 -- Kolkar Leaders
step
  .goto 1413,45.18,23.27
  .complete 848 -- Fungal Spores
step
  .goto 1413,40.87,18.18
  .complete 867 -- Harpy Raiders
step
  .goto 1413,42.8,23.52
  .complete 850 -- Kolkar Leaders
step
  .goto 1413,45.34,28.41
  .turnin 850 -- Kolkar Leaders
step
  .goto 1413,51.44,30.15
  .turnin 848 -- Fungal Spores
  .goto 1413,51.62,30.9
  .turnin 867 -- Harpy Raiders
  .accept 875 -- Harpy Lieutenants
  .goto 1413,52.23,31.01
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
  .goto 1413,39.18,15.68
  .complete 875 -- Harpy Lieutenants
step
  .goto 1413,51.62,30.9
  .turnin 875 -- Harpy Lieutenants
  .goto 1413,52.26,31.93
  .turnin 880 -- Altered Beings
  .accept 1489 -- Hamuul Runetotem
step
  .level 17 -- reach it first: kill or grind on the way
step
  .goto 1413,52.23,31.01
  .accept 3261 -- Jorn Skyseer
step
  .goto 1413,43.8,12.21
  .accept 95494 -- Bruised Pride and Lion Hides
  .accept 95495 -- The Hermit Tanner
  .accept 95507 -- Vrang's Game
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
  .goto 1413,43.9,14.5
  .complete 95507 -- Vrang's Game
  .complete 95494 -- Bruised Pride and Lion Hides
step
  .goto 1413,43.8,12.21
  .turnin 95494 -- Bruised Pride and Lion Hides
  .turnin 95507 -- Vrang's Game
step
  .goto 1413,52.4,11.65
  .accept 902 -- Samophlange
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
  .goto 1413,62.98,37.22
  .turnin 902 -- Samophlange
  .accept 3921 -- Wenikee Boltbucket
  .goto 1413,62.37,37.62
  .accept 865 -- Raptor Horns
  .goto 1413,63.35,38.45
  .accept 896 -- Miner's Fortune
step
  .goto 1413,59.62,8.34
  .complete 865 -- Raptor Horns
step
  .goto 1413,59.99,4.12
  .complete 896 -- Miner's Fortune
step
  .goto 1413,48.12,5.42
  .accept 6543 -- The Warsong Reports
  .todo "The Warsong Reports: objective 1 has no position in the pack"
  .complete 6543,1 -- The Warsong Reports
  .todo "The Warsong Reports: objective 2 has no position in the pack"
  .complete 6543,2 -- The Warsong Reports
  .todo "The Warsong Reports: objective 3 has no position in the pack"
  .complete 6543,3 -- The Warsong Reports
  .turnin 6543 -- The Warsong Reports
step
  .goto 1413,49.05,11.17
  .turnin 3921 -- Wenikee Boltbucket
  .accept 3922 -- Nugget Slugs
step
  .goto 1413,56.37,8.12
  .complete 3922 -- Nugget Slugs
step
  .goto 1413,49.05,11.17
  .turnin 3922 -- Nugget Slugs
step
  .goto 1413,62.37,37.62
  .turnin 865 -- Raptor Horns
  .accept 1491 -- Smart Drinks
  .goto 1413,63.35,38.45
  .turnin 896 -- Miner's Fortune
step
  .goto 1413,47.58,33.05
  .complete 1491 -- Smart Drinks
step
  .goto 1413,35.26,27.88
  .accept 1062 -- Goblin Invaders
  .goto 1413,35.19,27.76
  .accept 6548 -- Avenge My Village
step
  .todo "border The Barrens/Stonetalon Mountains: no crossing coordinates yet (record them in game or in Borders.lua)"
  .zone 1442 >> Go into Stonetalon Mountains
]]
)
