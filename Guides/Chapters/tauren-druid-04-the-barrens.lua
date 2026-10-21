-- PLANNED: the thorough route for Tauren Druid (HARDCORE): tools/route_planner.py tauren --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"tauren-druid-04-the-barrens",
	[[
#chapter 12-14 The Barrens
step
  .goto 1413,52.76,28.2
  .complete 844 -- Plainstrider Menace
step
  .goto 1413,52.23,31.01
  .turnin 844 -- Plainstrider Menace
  .accept 845 -- The Zhevra
step
  .goto 1413,54.6,23.16
  .complete 869 -- Raptor Thieves
  .complete 871 -- Disrupt the Attacks
step
  .goto 1413,51.93,30.32
  .turnin 869 -- Raptor Thieves
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
  .goto 1413,51.5,30.87
  .accept 5041 -- Supplies for the Crossroads
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
step
  .goto 1413,51.5,30.87
  .turnin 5041 -- Supplies for the Crossroads
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
  .todo "travel from The Barrens to Orgrimmar: the travel graph has no route yet"
  .zone 1454 >> Go to Orgrimmar
]]
)
