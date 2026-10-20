-- PLANNED: the beam route for Troll Hunter, planned by tools/route_planner.py on 2026-10-20 (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"troll-hunter-06-the-barrens",
	[[
#chapter 13-16 The Barrens
step
  .goto 1413,43.22,33.71
  .complete 903 -- Prowlers of the Barrens
step
  .goto 1413,52.23,31.01
  .turnin 903 -- Prowlers of the Barrens
  .accept 881 -- Echeyakee
  .todo "Echeyakee: objective 1 has no position in the pack"
  .complete 881,1 -- Echeyakee
  .turnin 881 -- Echeyakee
step
  .goto 1413,45.34,28.41
  .accept 855 -- Centaur Bracers
  .level 11
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
  .goto 1413,42.02,11.45
  .level 14
  .accept 95508 -- Unwelcome Guests
  .accept 95621 -- Trouble in the Valley
  .turnin 95508 -- Unwelcome Guests
  .accept 95494 -- Bruised Pride and Lion Hides
  .accept 95495 -- The Hermit Tanner
  .accept 95507 -- Vrang's Game
  .turnin 95495 -- The Hermit Tanner
step
  .level 15 -- reach it first: kill or grind on the way
step
  .goto 1413,41.83,15.54
  .complete 95621 -- Trouble in the Valley
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
  .accept 863 -- The Escape
step
  .todo "travel from The Barrens to Undercity: the travel graph has no route yet"
  .zone 1458 >> Go to Undercity
step
  .level 16 -- reach it first: kill or grind on the way
]]
)
