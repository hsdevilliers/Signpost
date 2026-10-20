-- PLANNED: the thorough alt 1 route for Troll Hunter: tools/route_planner.py troll --preset all --install --force --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"troll-hunter-05-the-barrens",
	[[
#chapter 12-16 The Barrens
step
  .goto 1413,52.23,31.01
  .turnin 844 -- Plainstrider Menace
  .accept 845 -- The Zhevra
step
  .goto 1413,48.96,37.55
  .complete 845 -- The Zhevra
step
  .goto 1413,52.23,31.01
  .turnin 845 -- The Zhevra
  .accept 903 -- Prowlers of the Barrens
step
  .goto 1413,54.38,25.9
  .complete 871 -- Disrupt the Attacks
  .complete 869 -- Raptor Thieves
step
  .goto 1413,45.18,23.27
  .complete 848 -- Fungal Spores
  .complete 870 -- The Forgotten Pools
step
  .goto 1413,51.44,30.15
  .turnin 848 -- Fungal Spores
  .goto 1413,51.5,30.87
  .turnin 871 -- Disrupt the Attacks
  .goto 1413,51.93,30.32
  .turnin 869 -- Raptor Thieves
  .goto 1413,52.26,31.93
  .turnin 870 -- The Forgotten Pools
  .accept 877 -- The Stagnant Oasis
step
  .goto 1413,45.34,28.41
  .accept 855 -- Centaur Bracers
  .accept 850 -- Kolkar Leaders
step
  .goto 1413,43.47,23.56
  .complete 855 -- Centaur Bracers
  .complete 850 -- Kolkar Leaders
step
  .goto 1413,45.34,28.41
  .turnin 855 -- Centaur Bracers
  .turnin 850 -- Kolkar Leaders
  .accept 851 -- Verog the Dervish
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
  .goto 1413,40.95,21.48
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
  .goto 1413,51.62,30.9
  .turnin 867 -- Harpy Raiders
  .goto 1413,51.95,31.58
  .accept 899 -- Consumed by Hatred
  .accept 4921 -- Lost in Battle
  .accept 95774 -- Her Name Is Olgra
step
  .goto 1413,45.34,28.41
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
  .goto 1413,44.42,15.78
  .complete 95494 -- Bruised Pride and Lion Hides
step
  .goto 1413,43.8,12.21
  .turnin 95494 -- Bruised Pride and Lion Hides
step
  .goto 1413,41.83,15.54
  .complete 95621 -- Trouble in the Valley
step
  .goto 1413,42.02,11.45
  .turnin 95621 -- Trouble in the Valley
step
  .goto 1413,56.52,7.45
  .accept 858 -- Ignition
step
  .goto 1413,56.27,8.58
  .complete 858 -- Ignition
step
  .goto 1413,56.52,7.45
  .turnin 858 -- Ignition
  .accept 863 -- The Escape
step
  .todo "travel from The Barrens to Undercity: the travel graph has no route yet"
  .zone 1458 >> Go to Undercity
]]
)
