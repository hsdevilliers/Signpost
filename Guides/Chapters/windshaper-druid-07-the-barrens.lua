-- PLANNED: the thorough alt 5 route for Skyborne Druid (HARDCORE): tools/route_planner.py windshaper --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"windshaper-druid-07-the-barrens",
	[[
#chapter 15-19 The Barrens
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
  .goto 1413,52.23,31.01
  .accept 844 -- Plainstrider Menace
  .goto 1413,52.26,31.93
  .accept 870 -- The Forgotten Pools
step
  .goto 1413,52.76,28.2
  .complete 844 -- Plainstrider Menace
step
  .goto 1413,52.23,31.01
  .turnin 844 -- Plainstrider Menace
  .accept 845 -- The Zhevra
  .note Swiftmane, a rare elite zhevra (near 61.2,34.5), drops the hooves too: take them from the ordinary zhevras and keep away from him.
step
  .goto 1413,45.5,30.18
  .complete 845 -- The Zhevra
step
  .goto 1413,45.34,28.41
  .accept 855 -- Centaur Bracers
  .note Rocklance (rare elite, near 56.5,41.7) and Warlord Krom'zar (elite) are among the Kolkar that drop the bracers: kill ordinary Kolkar one at a time and leave those two alone.
step
  .goto 1413,43.47,23.56
  .complete 855 -- Centaur Bracers
  .complete 870 -- The Forgotten Pools
  .complete 848 -- Fungal Spores
step
  .goto 1413,45.34,28.41
  .turnin 855 -- Centaur Bracers
step
  .goto 1413,51.44,30.15
  .turnin 848 -- Fungal Spores
  .goto 1413,52.23,31.01
  .turnin 845 -- The Zhevra
  .accept 903 -- Prowlers of the Barrens
  .goto 1413,52.26,31.93
  .turnin 870 -- The Forgotten Pools
  .accept 877 -- The Stagnant Oasis
step
  .goto 1413,54.38,25.9
  .complete 871 -- Disrupt the Attacks
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
  .goto 1413,51.5,30.87
  .turnin 871 -- Disrupt the Attacks
  .accept 872 -- The Disruption Ends
  .accept 5041 -- Supplies for the Crossroads
step
  .goto 1413,58.52,27.04
  .complete 872 -- The Disruption Ends
  .complete 5041 -- Supplies for the Crossroads
step
  .goto 1413,51.5,30.87
  .turnin 872 -- The Disruption Ends
  .turnin 5041 -- Supplies for the Crossroads
step
  .goto 1413,40.87,15.25
  .complete 867 -- Harpy Raiders
step
  .level 17 -- reach it first: kill or grind on the way
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
  .goto 1413,42.02,11.45
  .turnin 95495 -- The Hermit Tanner
  .accept 95621 -- Trouble in the Valley
step
  .goto 1413,41.83,15.54
  .complete 95621 -- Trouble in the Valley
step
  .goto 1413,42.02,11.45
  .turnin 95621 -- Trouble in the Valley
  .goto 1413,43.8,12.21
  .turnin 95494 -- Bruised Pride and Lion Hides
  .turnin 95507 -- Vrang's Game
step
  .goto 1413,51.62,30.9
  .turnin 867 -- Harpy Raiders
  .goto 1413,52.23,31.01
  .accept 3261 -- Jorn Skyseer
step
  .goto 1413,55.6,42.43
  .complete 880 -- Altered Beings
step
  .goto 1413,62.68,36.23
  .accept 887 -- Southsea Freebooters
  .goto 1413,63.07,36.32
  .accept 97253 -- Parts and Pieces
  .goto 1413,62.98,37.22
  .accept 894 -- Samophlange
  .goto 1413,62.37,37.62
  .accept 865 -- Raptor Horns
  .note Takk the Leaper, a rare elite raptor (near 59.6,8.3), drops the horns too: take them from the ordinary raptors and keep away from him.
  .goto 1413,63.35,38.45
  .accept 896 -- Miner's Fortune
step
  .goto 1413,62.0,45.2
  .complete 97253 -- Parts and Pieces
step
  .goto 1413,63.07,36.32
  .turnin 97253 -- Parts and Pieces
step
  .goto 1413,52.26,31.93
  .turnin 880 -- Altered Beings
  .accept 1489 -- Hamuul Runetotem
step
  .goto 1413,52.4,11.65
  .turnin 894 -- Samophlange
  .accept 900 -- Samophlange
step
  .goto 1413,52.33,11.56
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
step
  .goto 1413,59.99,4.12
  .complete 896 -- Miner's Fortune
step
  .goto 1413,62.98,37.22
  .turnin 902 -- Samophlange
  .accept 3921 -- Wenikee Boltbucket
  .goto 1413,63.35,38.45
  .turnin 896 -- Miner's Fortune
step
  .goto 1413,63.9,45.32
  .complete 887 -- Southsea Freebooters
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
  .accept 913 -- Cry of the Thunderhawk
step
  .goto 1413,44.77,63.05
  .complete 913 -- Cry of the Thunderhawk
step
  .goto 1413,44.86,59.14
  .turnin 913 -- Cry of the Thunderhawk
step
  .goto 1413,62.37,37.62
  .turnin 865 -- Raptor Horns
  .goto 1413,62.59,37.47
  .accept 92706 -- WANTED: Bruuz
step
  .goto 1413,64.3,39.13
  .complete 92706 -- WANTED: Bruuz
step
  .goto 1413,62.7,36.3
  .accept 79097 -- Baxtan: On Destructive Magics
  .complete 79097,1 -- Baxtan: On Destructive Magics
  .goto 1413,62.68,36.23
  .turnin 887 -- Southsea Freebooters
  .turnin 92706 -- WANTED: Bruuz
step
  .goto 1413,56.3,8.8
  .accept 78145 -- Arcanic Systems Manual
  .complete 78145,1 -- Arcanic Systems Manual
step
  .todo "travel from The Barrens to Undercity: the travel graph has no route yet"
  .zone 1458 >> Go to Undercity
]]
)
