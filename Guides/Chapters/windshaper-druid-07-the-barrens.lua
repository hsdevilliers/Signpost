-- PLANNED: the thorough alt 4 route for Skyborne Druid (HARDCORE): tools/route_planner.py windshaper --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"windshaper-druid-07-the-barrens",
	[[
#chapter 14-19 The Barrens
step
  .goto 1413,51.93,30.32
  .turnin 869 -- Raptor Thieves
  .goto 1413,51.62,30.9
  .level 12
  .accept 867 -- Harpy Raiders
  .goto 1413,51.5,30.87
  .turnin 98024 -- Journey to the Crossroads
  .goto 1413,51.44,30.15
  .accept 848 -- Fungal Spores
step
  .goto 1413,48.96,37.55
  .complete 845 -- The Zhevra
step
  .goto 1413,52.23,31.01
  .turnin 845 -- The Zhevra
  .accept 903 -- Prowlers of the Barrens
step
  .goto 1413,45.34,28.41
  .accept 855 -- Centaur Bracers
  .accept 850 -- Kolkar Leaders
step
  .goto 1413,45.18,23.27
  .complete 848 -- Fungal Spores
  .complete 870 -- The Forgotten Pools
  .complete 855 -- Centaur Bracers
step
  .goto 1413,45.34,28.41
  .turnin 855 -- Centaur Bracers
step
  .goto 1413,43.22,33.71
  .complete 903 -- Prowlers of the Barrens
step
  .goto 1413,52.26,31.93
  .turnin 870 -- The Forgotten Pools
  .accept 877 -- The Stagnant Oasis
step
  .goto 1413,52.23,31.01
  .turnin 903 -- Prowlers of the Barrens
  .accept 881 -- Echeyakee
  .todo "Echeyakee: objective 1 has no position in the pack"
  .complete 881,1 -- Echeyakee
  .turnin 881 -- Echeyakee
step
  .goto 1413,54.38,25.9
  .complete 871 -- Disrupt the Attacks
step
  .goto 1413,51.5,30.87
  .turnin 871 -- Disrupt the Attacks
  .accept 872 -- The Disruption Ends
  .accept 5041 -- Supplies for the Crossroads
  .goto 1413,51.44,30.15
  .turnin 848 -- Fungal Spores
step
  .goto 1413,57.32,24.6
  .complete 872 -- The Disruption Ends
  .complete 5041 -- Supplies for the Crossroads
step
  .goto 1413,51.5,30.87
  .turnin 872 -- The Disruption Ends
  .turnin 5041 -- Supplies for the Crossroads
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
  .goto 1413,52.26,31.93
  .turnin 880 -- Altered Beings
  .accept 1489 -- Hamuul Runetotem
step
  .goto 1413,42.8,23.52
  .complete 850 -- Kolkar Leaders
step
  .goto 1413,40.87,15.25
  .complete 867 -- Harpy Raiders
step
  .goto 1413,43.8,12.21
  .level 14
  .accept 95494 -- Bruised Pride and Lion Hides
  .accept 95495 -- The Hermit Tanner
  .accept 95507 -- Vrang's Game
  .goto 1413,42.02,11.45
  .turnin 95495 -- The Hermit Tanner
  .accept 95621 -- Trouble in the Valley
step
  .goto 1413,43.9,14.5
  .complete 95507 -- Vrang's Game
  .complete 95494 -- Bruised Pride and Lion Hides
step
  .goto 1413,43.8,12.21
  .turnin 95494 -- Bruised Pride and Lion Hides
  .turnin 95507 -- Vrang's Game
step
  .goto 1413,41.83,15.54
  .complete 95621 -- Trouble in the Valley
step
  .goto 1413,42.02,11.45
  .turnin 95621 -- Trouble in the Valley
step
  .goto 1413,45.34,28.41
  .turnin 850 -- Kolkar Leaders
step
  .goto 1413,51.62,30.9
  .turnin 867 -- Harpy Raiders
  .accept 875 -- Harpy Lieutenants
  .goto 1413,52.23,31.01
  .accept 3261 -- Jorn Skyseer
step
  .goto 1413,62.68,36.23
  .accept 887 -- Southsea Freebooters
  .goto 1413,63.07,36.32
  .accept 97253 -- Parts and Pieces
step
  .goto 1413,63.9,45.32
  .complete 887 -- Southsea Freebooters
  .complete 97253 -- Parts and Pieces
step
  .goto 1413,62.68,36.23
  .turnin 887 -- Southsea Freebooters
  .goto 1413,63.07,36.32
  .turnin 97253 -- Parts and Pieces
  .goto 1413,62.98,37.22
  .accept 894 -- Samophlange
  .goto 1413,62.37,37.62
  .accept 865 -- Raptor Horns
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
  .goto 1413,48.95,59.71
  .complete 907 -- Enraged Thunder Lizards
step
  .goto 1413,44.86,59.14
  .turnin 907 -- Enraged Thunder Lizards
step
  .goto 1413,39.18,15.68
  .complete 875 -- Harpy Lieutenants
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
  .goto 1413,52.4,11.65
  .turnin 894 -- Samophlange
  .accept 900 -- Samophlange
step
  .goto 1413,52.4,11.41
  .complete 900 -- Samophlange
step
  .goto 1413,52.4,11.65
  .turnin 900 -- Samophlange
  .accept 901 -- Samophlange
step
  .goto 1413,52.84,10.39
  .complete 901 -- Samophlange
step
  .goto 1413,52.4,11.65
  .turnin 901 -- Samophlange
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
  .goto 1413,56.3,8.8
  .accept 78145 -- Arcanic Systems Manual
  .complete 78145,1 -- Arcanic Systems Manual
step
  .goto 1413,62.98,37.22
  .turnin 902 -- Samophlange
  .accept 3921 -- Wenikee Boltbucket
  .goto 1413,62.59,37.47
  .accept 92706 -- WANTED: Bruuz
  .goto 1413,62.37,37.62
  .turnin 865 -- Raptor Horns
  .accept 1491 -- Smart Drinks
step
  .goto 1413,64.3,39.13
  .complete 92706 -- WANTED: Bruuz
step
  .goto 1413,62.7,36.3
  .accept 79097 -- Baxtan: On Destructive Magics
  .complete 79097,1 -- Baxtan: On Destructive Magics
  .goto 1413,62.68,36.23
  .turnin 92706 -- WANTED: Bruuz
step
  .goto 1413,51.62,30.9
  .turnin 875 -- Harpy Lieutenants
  .accept 876 -- Serena Bloodfeather
step
  .goto 1413,49.3,32.88
  .accept 78143 -- Secrets of the Dreamers
  .complete 78143,1 -- Secrets of the Dreamers
step
  .goto 1413,47.58,33.05
  .complete 1491 -- Smart Drinks
step
  .goto 1413,62.37,37.62
  .turnin 1491 -- Smart Drinks
step
  .todo "travel from The Barrens to Undercity: the travel graph has no route yet"
  .zone 1458 >> Go to Undercity
]]
)
