-- PLANNED: the thorough alt 3 route for Tauren Druid (HARDCORE): tools/route_planner.py tauren --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"tauren-druid-05-the-barrens",
	[[
#chapter 12-15 The Barrens
step
  .goto 1413,52.26,31.93
  .accept 870 -- The Forgotten Pools
  .goto 1413,52.23,31.01
  .accept 844 -- Plainstrider Menace
step
  .goto 1413,51.5,30.34 >> Go to the flight master
  .fp 1413,Crossroads
step
  .goto 1413,52.76,28.2
  .complete 844 -- Plainstrider Menace
step
  .goto 1413,51.93,30.32
  .accept 869 -- Raptor Thieves
  .note Takk the Leaper, a rare elite raptor (near 59.6,8.3), is one of the creatures that drop the heads: take them from the ordinary raptors and keep away from him.
  .goto 1413,51.5,30.87
  .accept 871 -- Disrupt the Attacks
  .goto 1413,51.21,29.05
  .accept 6361 -- A Bundle of Hides
  .goto 1413,51.5,30.34
  .turnin 6361 -- A Bundle of Hides
  .accept 6362 -- Ride to Thunder Bluff
  .goto 1413,52.23,31.01
  .turnin 844 -- Plainstrider Menace
  .accept 845 -- The Zhevra
  .note Swiftmane, a rare elite zhevra (near 61.2,34.5), drops the hooves too: take them from the ordinary zhevras and keep away from him.
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
  .note Rocklance (rare elite, near 56.5,41.7) and Warlord Krom'zar (elite) are among the Kolkar that drop the bracers: kill ordinary Kolkar one at a time and leave those two alone.
step
  .goto 1413,47.54,24.55
  .complete 855 -- Centaur Bracers
  .complete 869 -- Raptor Thieves
step
  .goto 1413,45.34,28.41
  .turnin 855 -- Centaur Bracers
step
  .goto 1413,45.06,22.53
  .complete 870 -- The Forgotten Pools
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
  .goto 1413,58.55,25.86
  .complete 5041 -- Supplies for the Crossroads
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
  .turnin 5041 -- Supplies for the Crossroads
  .accept 872 -- The Disruption Ends
  .goto 1413,51.44,30.15
  .accept 848 -- Fungal Spores
step
  .goto 1413,40.95,21.48
  .complete 903 -- Prowlers of the Barrens
  .complete 867 -- Harpy Raiders
step
  .goto 1413,45.18,23.27
  .complete 848 -- Fungal Spores
step
  .goto 1413,51.44,30.15
  .turnin 848 -- Fungal Spores
  .goto 1413,51.62,30.9
  .turnin 867 -- Harpy Raiders
  .goto 1413,52.23,31.01
  .turnin 903 -- Prowlers of the Barrens
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
  .level 15 -- reach it first: kill or grind on the way
  .note Grind about 3 experience before you go on: about 1 kill of creatures near your level (an estimate)
step
  .goto 1413,52.4,11.65
  .accept 902 -- Samophlange
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
  .goto 1413,62.59,37.47
  .accept 895 -- WANTED: Baron Longshore
  .goto 1413,62.98,37.22
  .turnin 902 -- Samophlange
  .accept 3921 -- Wenikee Boltbucket
step
  .goto 1413,58.52,27.04
  .complete 872 -- The Disruption Ends
step
  .goto 1413,51.5,30.87
  .turnin 872 -- The Disruption Ends
  .goto 1413,51.62,30.9
  .accept 875 -- Harpy Lieutenants
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
  .todo "Walk from The Barrens to Orgrimmar: the guide has no waypoints for this yet, so find your own way. This step is done when you arrive in Orgrimmar."
  .zone 1454 >> Go to Orgrimmar
]]
)
