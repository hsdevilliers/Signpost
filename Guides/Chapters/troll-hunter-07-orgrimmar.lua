-- PLANNED: the thorough alt 5 route for Troll Hunter: tools/route_planner.py troll --preset all --install --force --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"troll-hunter-07-orgrimmar",
	[[
#chapter 16-17 Orgrimmar
step
  .goto 1454,63.65,49.93
  .turnin 65601 -- Love Hurts
step
  .goto 1454,31.73,37.82
  .turnin 5730 -- Hidden Enemies
step
  .todo "travel from Orgrimmar to The Barrens: the travel graph has no route yet"
  .zone 1413 >> Go to The Barrens
step
  .goto 1413,43.8,12.21
  .accept 95494 -- Bruised Pride and Lion Hides
  .accept 95495 -- The Hermit Tanner
  .accept 95507 -- Vrang's Game
  .goto 1413,42.02,11.45
  .turnin 95495 -- The Hermit Tanner
  .accept 95621 -- Trouble in the Valley
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
]]
)
