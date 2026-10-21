-- PLANNED: the thorough alt 4 route for Troll Hunter: tools/route_planner.py troll --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"troll-hunter-05-the-barrens",
	[[
#chapter 14-16 The Barrens
step
  .goto 1413,62.26,19.38
  .turnin 840 -- Conscript of the Horde
  .accept 842 -- Crossroads Conscription
  .goto 1413,62.34,20.07
  .turnin 809 -- Ak'Zeloth
  .accept 924 -- The Demon Seed
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
  .goto 1413,51.5,30.34
  .turnin 6365 -- Meats to Orgrimmar
  .goto 1413,51.44,30.15
  .accept 848 -- Fungal Spores
  .goto 1413,51.5,30.87
  .accept 871 -- Disrupt the Attacks
  .goto 1413,51.62,30.9
  .level 12
  .accept 867 -- Harpy Raiders
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
  .goto 1413,54.38,25.9
  .complete 871 -- Disrupt the Attacks
  .complete 869 -- Raptor Thieves
step
  .goto 1413,51.93,30.32
  .turnin 869 -- Raptor Thieves
  .goto 1413,51.5,30.87
  .turnin 871 -- Disrupt the Attacks
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
  .complete 867 -- Harpy Raiders
step
  .goto 1413,42.02,11.45
  .turnin 95621 -- Trouble in the Valley
step
  .goto 1413,40.95,21.48
  .complete 903 -- Prowlers of the Barrens
step
  .goto 1413,45.06,22.53
  .complete 870 -- The Forgotten Pools
step
  .goto 1413,47.98,19.07
  .complete 924 -- The Demon Seed
step
  .goto 1413,52.23,31.01
  .turnin 903 -- Prowlers of the Barrens
  .accept 881 -- Echeyakee
  .todo "Echeyakee: objective 1 has no position in the pack"
  .complete 881,1 -- Echeyakee
  .turnin 881 -- Echeyakee
  .accept 905 -- The Angry Scytheclaws
step
  .goto 1413,51.95,31.58
  .accept 899 -- Consumed by Hatred
  .accept 4921 -- Lost in Battle
  .accept 95774 -- Her Name Is Olgra
  .goto 1413,52.26,31.93
  .turnin 870 -- The Forgotten Pools
  .accept 877 -- The Stagnant Oasis
  .goto 1413,51.62,30.9
  .turnin 867 -- Harpy Raiders
step
  .goto 1413,62.34,20.07
  .turnin 924 -- The Demon Seed
step
  .todo "Get from The Barrens to Undercity: they are on different continents, so you need a boat, a zeppelin or another ride, and the guide has no dock for it yet. This step is done when you arrive in Undercity."
  .zone 1458 >> Go to Undercity
]]
)
