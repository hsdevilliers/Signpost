-- PLANNED: the thorough alt 1 route for Tauren Druid (HARDCORE): tools/route_planner.py tauren --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"tauren-druid-06-the-barrens",
	[[
#chapter 15-19 The Barrens
step
  .goto 1413,62.26,19.38
  .turnin 840 -- Conscript of the Horde
  .accept 842 -- Crossroads Conscription
step
  .goto 1413,52.23,31.01
  .turnin 842 -- Crossroads Conscription
  .accept 903 -- Prowlers of the Barrens
  .goto 1413,52.26,31.93
  .accept 877 -- The Stagnant Oasis
step
  .goto 1413,43.22,33.71
  .complete 903 -- Prowlers of the Barrens
step
  .goto 1413,51.44,30.15
  .accept 848 -- Fungal Spores
  .goto 1413,51.5,30.87
  .accept 872 -- The Disruption Ends
  .goto 1413,51.62,30.9
  .level 12
  .accept 867 -- Harpy Raiders
step
  .goto 1413,52.23,31.01
  .turnin 903 -- Prowlers of the Barrens
  .accept 881 -- Echeyakee
  .todo "Echeyakee: objective 1 has no position in the pack"
  .complete 881,1 -- Echeyakee
  .turnin 881 -- Echeyakee
step
  .goto 1413,58.52,27.04
  .complete 872 -- The Disruption Ends
step
  .goto 1413,51.5,30.87
  .turnin 872 -- The Disruption Ends
step
  .goto 1413,45.18,23.27
  .complete 848 -- Fungal Spores
step
  .goto 1413,40.87,18.18
  .complete 867 -- Harpy Raiders
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
  .goto 1413,52.4,11.65
  .accept 902 -- Samophlange
step
  .goto 1413,51.62,30.9
  .turnin 875 -- Harpy Lieutenants
  .goto 1413,52.26,31.93
  .turnin 880 -- Altered Beings
  .accept 1489 -- Hamuul Runetotem
step
  .goto 1413,62.59,37.47
  .accept 895 -- WANTED: Baron Longshore
  .goto 1413,62.98,37.22
  .turnin 902 -- Samophlange
  .accept 3921 -- Wenikee Boltbucket
step
  .goto 1413,63.9,45.32
  .complete 887 -- Southsea Freebooters
step
  .goto 1413,62.68,36.23
  .turnin 887 -- Southsea Freebooters
step
  .goto 1413,49.05,11.17
  .turnin 3921 -- Wenikee Boltbucket
  .accept 3922 -- Nugget Slugs
step
  .goto 1413,56.37,8.12
  .complete 3922 -- Nugget Slugs
step
  .goto 1413,56.52,7.45
  .level 13
  .accept 858 -- Ignition
step
  .goto 1413,56.27,8.58
  .complete 858 -- Ignition
step
  .goto 1413,56.52,7.45
  .turnin 858 -- Ignition
step
  .goto 1413,49.05,11.17
  .turnin 3922 -- Nugget Slugs
  .level 18 -- reach it first: kill or grind on the way
  .note Grind about 13,000 experience before you go on: about 100 kills of creatures near your level (an estimate)
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
  .goto 1413,52.23,31.01
  .accept 3261 -- Jorn Skyseer
step
  .goto 1413,62.37,37.62
  .accept 865 -- Raptor Horns
  .note Takk the Leaper, a rare elite raptor (near 59.6,8.3), drops the horns too: take them from the ordinary raptors and keep away from him.
  .goto 1413,63.35,38.45
  .accept 896 -- Miner's Fortune
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
step
  .goto 1413,61.06,3.95
  .complete 896 -- Miner's Fortune
step
  .goto 1413,63.35,38.45
  .turnin 896 -- Miner's Fortune
  .level 19 -- reach it first: kill or grind on the way
  .note Grind about 27 experience before you go on: about 1 kill of creatures near your level (an estimate)
step
  .goto 1413,51.95,31.58
  .accept 899 -- Consumed by Hatred
  .accept 4921 -- Lost in Battle
  .accept 95774 -- Her Name Is Olgra
  .goto 1413,51.62,30.9
  .accept 876 -- Serena Bloodfeather
step
  .goto 1413,49.33,50.32
  .complete 4921 -- Lost in Battle
  .complete 899 -- Consumed by Hatred
  .complete 95774 -- Her Name Is Olgra
step
  .goto 1413,39.16,12.17
  .complete 876 -- Serena Bloodfeather
step
  .goto 1413,51.62,30.9
  .turnin 876 -- Serena Bloodfeather
  .accept 1060 -- Letter to Jin'Zil
  .goto 1413,51.95,31.58
  .turnin 899 -- Consumed by Hatred
  .turnin 4921 -- Lost in Battle
  .turnin 95774 -- Her Name Is Olgra
step
  .goto 1413,35.26,27.88
  .accept 1062 -- Goblin Invaders
  .goto 1413,35.19,27.76
  .accept 6548 -- Avenge My Village
step
  .todo "Walk from The Barrens to Stonetalon Mountains: the guide has no waypoints for this yet, so find your own way. This step is done when you arrive in Stonetalon Mountains."
  .zone 1442 >> Go to Stonetalon Mountains
]]
)
