-- PLANNED: the beam route for Troll Hunter: tools/route_planner.py troll --preset all --install --force --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"troll-hunter-03-the-barrens",
	[[
#chapter 11-16 The Barrens
step
  .goto 1413,62.26,19.38
  .turnin 840 -- Conscript of the Horde
  .accept 842 -- Crossroads Conscription
step
  .goto 1413,52.62,29.84
  .accept 6365 -- Meats to Orgrimmar
  .goto 1413,52.23,31.01
  .turnin 842 -- Crossroads Conscription
  .accept 844 -- Plainstrider Menace
  .goto 1413,52.26,31.93
  .accept 870 -- The Forgotten Pools
  .goto 1413,51.93,30.32
  .accept 869 -- Raptor Thieves
  .goto 1413,51.5,30.87
  .accept 871 -- Disrupt the Attacks
  .goto 1413,51.5,30.34
  .turnin 6365 -- Meats to Orgrimmar
  .accept 6384 -- Ride to Orgrimmar
  .goto 1413,51.44,30.15
  .accept 848 -- Fungal Spores
step
  .goto 1413,51.5,30.34 >> Go to the flight master
  .fp 1413,Crossroads
step
  .goto 1413,52.76,28.2
  .complete 844 -- Plainstrider Menace
step
  .goto 1413,52.23,31.01
  .turnin 844 -- Plainstrider Menace
  .accept 845 -- The Zhevra
  .goto 1413,51.62,30.9
  .level 12
  .accept 867 -- Harpy Raiders
step
  .goto 1413,54.38,25.9
  .complete 871 -- Disrupt the Attacks
  .complete 869 -- Raptor Thieves
step
  .goto 1413,51.93,30.32
  .turnin 869 -- Raptor Thieves
  .goto 1413,51.5,30.87
  .turnin 871 -- Disrupt the Attacks
  .accept 872 -- The Disruption Ends
  .accept 5041 -- Supplies for the Crossroads
step
  .goto 1413,48.96,37.55
  .complete 845 -- The Zhevra
  .complete 848 -- Fungal Spores
step
  .goto 1413,51.44,30.15
  .turnin 848 -- Fungal Spores
  .goto 1413,52.23,31.01
  .turnin 845 -- The Zhevra
  .accept 903 -- Prowlers of the Barrens
step
  .goto 1413,45.34,28.41
  .accept 855 -- Centaur Bracers
  .accept 850 -- Kolkar Leaders
step
  .goto 1413,47.54,24.55
  .complete 855 -- Centaur Bracers
step
  .goto 1413,45.34,28.41
  .turnin 855 -- Centaur Bracers
step
  .goto 1413,40.95,21.48
  .complete 903 -- Prowlers of the Barrens
step
  .goto 1413,45.06,22.53
  .complete 870 -- The Forgotten Pools
step
  .goto 1413,52.23,31.01
  .turnin 903 -- Prowlers of the Barrens
  .accept 881 -- Echeyakee
  .todo "Echeyakee: objective 1 has no position in the pack"
  .complete 881,1 -- Echeyakee
  .turnin 881 -- Echeyakee
  .accept 905 -- The Angry Scytheclaws
step
  .goto 1413,52.26,31.93
  .turnin 870 -- The Forgotten Pools
  .accept 877 -- The Stagnant Oasis
step
  .goto 1413,57.32,24.6
  .complete 872 -- The Disruption Ends
  .complete 5041 -- Supplies for the Crossroads
step
  .goto 1413,51.5,30.87
  .turnin 872 -- The Disruption Ends
  .turnin 5041 -- Supplies for the Crossroads
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
  .goto 1413,40.87,15.25
  .complete 867 -- Harpy Raiders
step
  .goto 1413,42.8,23.52
  .complete 850 -- Kolkar Leaders
step
  .goto 1413,51.62,30.9
  .turnin 867 -- Harpy Raiders
  .accept 875 -- Harpy Lieutenants
step
  .goto 1413,45.34,28.41
  .turnin 850 -- Kolkar Leaders
  .accept 851 -- Verog the Dervish
  .todo "Verog the Dervish: objective 1 has no position in the pack"
  .complete 851,1 -- Verog the Dervish
  .turnin 851 -- Verog the Dervish
  .accept 852 -- Hezrul Bloodmark
step
  .goto 1413,42.7,21.2
  .complete 95507 -- Vrang's Game
step
  .goto 1413,43.8,12.21
  .turnin 95507 -- Vrang's Game
step
  .goto 1413,41.83,15.54
  .complete 95621 -- Trouble in the Valley
step
  .goto 1413,39.18,15.68
  .complete 875 -- Harpy Lieutenants
step
  .goto 1413,42.02,11.45
  .turnin 95621 -- Trouble in the Valley
step
  .goto 1413,44.42,15.78
  .complete 95494 -- Bruised Pride and Lion Hides
step
  .goto 1413,43.8,12.21
  .turnin 95494 -- Bruised Pride and Lion Hides
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
  .goto 1413,51.5,30.34 >> Go to the flight master
  .fly Orgrimmar
]]
)
