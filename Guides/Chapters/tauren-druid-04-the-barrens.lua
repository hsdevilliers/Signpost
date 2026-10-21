-- PLANNED: the thorough alt 4 route for Tauren Druid (HARDCORE): tools/route_planner.py tauren --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"tauren-druid-04-the-barrens",
	[[
#chapter 12-16 The Barrens
step
  .goto 1413,51.21,29.05
  .accept 6361 -- A Bundle of Hides
  .goto 1413,51.5,30.34
  .turnin 6361 -- A Bundle of Hides
  .goto 1413,51.5,30.87
  .accept 871 -- Disrupt the Attacks
  .goto 1413,51.93,30.32
  .accept 869 -- Raptor Thieves
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
step
  .goto 1413,54.38,25.9
  .complete 871 -- Disrupt the Attacks
step
  .goto 1413,51.5,30.87
  .turnin 871 -- Disrupt the Attacks
step
  .goto 1413,45.5,30.18
  .complete 845 -- The Zhevra
step
  .goto 1413,45.34,28.41
  .accept 855 -- Centaur Bracers
step
  .goto 1413,45.06,22.53
  .complete 870 -- The Forgotten Pools
  .complete 855 -- Centaur Bracers
step
  .goto 1413,45.34,28.41
  .turnin 855 -- Centaur Bracers
step
  .goto 1413,48.85,23.82
  .complete 869 -- Raptor Thieves
step
  .goto 1413,51.5,30.87
  .accept 5041 -- Supplies for the Crossroads
  .goto 1413,51.93,30.32
  .turnin 869 -- Raptor Thieves
  .goto 1413,52.23,31.01
  .turnin 845 -- The Zhevra
  .goto 1413,52.26,31.93
  .turnin 870 -- The Forgotten Pools
step
  .goto 1413,62.68,36.23
  .accept 887 -- Southsea Freebooters
  .goto 1413,63.07,36.32
  .accept 97253 -- Parts and Pieces
  .goto 1413,62.98,37.22
  .accept 894 -- Samophlange
step
  .goto 1413,62.0,45.2
  .complete 97253 -- Parts and Pieces
  .complete 887 -- Southsea Freebooters
step
  .goto 1413,63.07,36.32
  .turnin 97253 -- Parts and Pieces
  .goto 1413,62.68,36.23
  .turnin 887 -- Southsea Freebooters
step
  .goto 1413,52.23,31.01
  .accept 903 -- Prowlers of the Barrens
  .goto 1413,51.62,30.9
  .level 12
  .accept 867 -- Harpy Raiders
  .goto 1413,51.5,30.87
  .accept 872 -- The Disruption Ends
  .goto 1413,51.44,30.15
  .accept 848 -- Fungal Spores
step
  .goto 1413,54.74,15.11
  .complete 903 -- Prowlers of the Barrens
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
step
  .goto 1413,45.18,23.27
  .complete 848 -- Fungal Spores
step
  .goto 1413,51.44,30.15
  .turnin 848 -- Fungal Spores
  .goto 1413,52.23,31.01
  .turnin 903 -- Prowlers of the Barrens
step
  .goto 1413,58.52,27.04
  .complete 872 -- The Disruption Ends
  .complete 5041 -- Supplies for the Crossroads
step
  .goto 1413,51.5,30.87
  .turnin 872 -- The Disruption Ends
  .turnin 5041 -- Supplies for the Crossroads
step
  .goto 1413,52.23,31.01
  .accept 881 -- Echeyakee
  .todo "Echeyakee: objective 1 has no position in the pack"
  .complete 881,1 -- Echeyakee
  .turnin 881 -- Echeyakee
step
  .goto 1413,52.26,31.93
  .accept 877 -- The Stagnant Oasis
step
  .goto 1413,55.61,42.75
  .complete 877 -- The Stagnant Oasis
step
  .goto 1413,52.26,31.93
  .turnin 877 -- The Stagnant Oasis
  .accept 880 -- Altered Beings
step
  .goto 1413,45.34,28.41
  .accept 850 -- Kolkar Leaders
step
  .goto 1413,42.8,23.52
  .complete 850 -- Kolkar Leaders
step
  .goto 1413,40.5,18.62
  .complete 867 -- Harpy Raiders
step
  .goto 1413,45.34,28.41
  .turnin 850 -- Kolkar Leaders
step
  .goto 1413,46.98,39.59
  .complete 880 -- Altered Beings
step
  .goto 1413,52.26,31.93
  .turnin 880 -- Altered Beings
  .accept 1489 -- Hamuul Runetotem
  .goto 1413,51.62,30.9
  .turnin 867 -- Harpy Raiders
  .accept 875 -- Harpy Lieutenants
step
  .todo "travel from The Barrens to Orgrimmar: the travel graph has no route yet"
  .zone 1454 >> Go to Orgrimmar
]]
)
