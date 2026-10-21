-- PLANNED: the thorough route for Skyborne Druid (HARDCORE): tools/route_planner.py windshaper --preset all --install --force --quiet --completeness 0.6 --completeness-trip 45 (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"windshaper-druid-04-the-barrens",
	[[
#chapter 16-20 The Barrens
step
  .goto 1413,51.93,30.32
  .accept 869 -- Raptor Thieves
  .note Takk the Leaper, a rare elite raptor (near 59.6,8.3), is one of the creatures that drop the heads: take them from the ordinary raptors and keep away from him.
  .goto 1413,51.62,30.9
  .level 12
  .accept 867 -- Harpy Raiders
  .goto 1413,51.5,30.87
  .turnin 98024 -- Journey to the Crossroads
  .accept 871 -- Disrupt the Attacks
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
step
  .goto 1413,45.34,28.41
  .turnin 855 -- Centaur Bracers
step
  .goto 1413,45.18,23.27
  .complete 848 -- Fungal Spores
  .complete 870 -- The Forgotten Pools
step
  .goto 1413,48.85,23.82
  .complete 869 -- Raptor Thieves
step
  .goto 1413,51.44,30.15
  .turnin 848 -- Fungal Spores
  .goto 1413,51.93,30.32
  .turnin 869 -- Raptor Thieves
  .goto 1413,52.23,31.01
  .turnin 845 -- The Zhevra
  .accept 903 -- Prowlers of the Barrens
  .goto 1413,52.26,31.93
  .turnin 870 -- The Forgotten Pools
  .accept 877 -- The Stagnant Oasis
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
  .goto 1413,41.83,15.54
  .complete 95621 -- Trouble in the Valley
  .complete 867 -- Harpy Raiders
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
  .goto 1413,54.74,15.11
  .complete 903 -- Prowlers of the Barrens
step
  .goto 1413,51.62,30.9
  .turnin 867 -- Harpy Raiders
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
  .accept 3261 -- Jorn Skyseer
step
  .goto 1413,46.98,39.59
  .complete 880 -- Altered Beings
step
  .goto 1413,52.26,31.93
  .turnin 880 -- Altered Beings
step
  .goto 1413,54.38,25.9
  .complete 871 -- Disrupt the Attacks
step
  .goto 1413,51.5,30.87
  .turnin 871 -- Disrupt the Attacks
  .accept 872 -- The Disruption Ends
  .accept 5041 -- Supplies for the Crossroads
step
  .goto 1413,57.32,24.6
  .complete 872 -- The Disruption Ends
  .complete 5041 -- Supplies for the Crossroads
step
  .goto 1413,51.5,30.87
  .turnin 872 -- The Disruption Ends
  .turnin 5041 -- Supplies for the Crossroads
  .goto 1413,51.95,31.58
  .accept 899 -- Consumed by Hatred
  .accept 4921 -- Lost in Battle
  .accept 95774 -- Her Name Is Olgra
step
  .goto 1413,49.3,32.88
  .accept 78143 -- Secrets of the Dreamers
  .complete 78143,1 -- Secrets of the Dreamers
step
  .goto 1413,44.78,51.51
  .complete 899 -- Consumed by Hatred
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
  .accept 913 -- Cry of the Thunderhawk
step
  .goto 1413,44.77,63.05
  .complete 913 -- Cry of the Thunderhawk
step
  .goto 1413,44.86,59.14
  .turnin 913 -- Cry of the Thunderhawk
step
  .goto 1413,48.17,52.89
  .complete 95774 -- Her Name Is Olgra
  .complete 4921 -- Lost in Battle
step
  .goto 1413,51.95,31.58
  .turnin 899 -- Consumed by Hatred
  .turnin 4921 -- Lost in Battle
  .turnin 95774 -- Her Name Is Olgra
step
  .goto 1413,62.7,36.3
  .accept 79097 -- Baxtan: On Destructive Magics
  .complete 79097,1 -- Baxtan: On Destructive Magics
step
  .goto 1413,56.3,8.8
  .accept 78145 -- Arcanic Systems Manual
  .complete 78145,1 -- Arcanic Systems Manual
step
  .todo "Get from The Barrens to Undercity: they are on different continents, so you need a boat, a zeppelin or another ride, and the guide has no dock for it yet. This step is done when you arrive in Undercity."
  .zone 1458 >> Go to Undercity
]]
)
