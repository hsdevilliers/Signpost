-- PLANNED: the thorough route for Skyborne Druid (HARDCORE): tools/route_planner.py windshaper --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"windshaper-druid-17-mulgore",
	[[
#chapter 29-29 Mulgore
step
  .goto 1412,46.68,63.83
  .accept 99079 -- Longwalker Malah
step
  .goto 1412,47.28,57.63
  .accept 99411 -- Kyle's Gone Missing!
step
  .goto 1412,46.28,62.34
  .complete 99411 -- Kyle's Gone Missing!
step
  .goto 1412,46.13,67.4
  .accept 96605 -- The Great Outdoors
step
  .goto 1412,46.21,67.31
  .complete 96605 -- The Great Outdoors
step
  .goto 1412,46.13,67.4
  .turnin 96605 -- The Great Outdoors
  .accept 96661 -- Camping 101: Cooking
step
  .goto 1412,54.76,64.27
  .accept 749 -- The Ravaged Caravan
  .goto 1412,57.62,63.18
  .turnin 99079 -- Longwalker Malah
  .accept 99081 -- Grim Tidings
step
  .goto 1412,51.87,53.37
  .turnin 749 -- The Ravaged Caravan
  .accept 751 -- The Ravaged Caravan
step
  .goto 1412,54.76,64.27
  .turnin 751 -- The Ravaged Caravan
step
  .goto 1412,47.28,57.63
  .turnin 99411 -- Kyle's Gone Missing!
step
  .goto 1412,46.68,63.83
  .turnin 99081 -- Grim Tidings
  .accept 99101 -- Our Ancient Enemy
  .goto 1412,44.92,61.67
  .complete 96661,1 -- Camping 101: Cooking
  .turnin 96661 -- Camping 101: Cooking
  .goto 1412,46.67,63.38
  .turnin 99101 -- Our Ancient Enemy
step
  .todo "Walk from Mulgore to The Barrens: the guide has no waypoints for this yet, so find your own way. This step is done when you arrive in The Barrens."
  .zone 1413 >> Go to The Barrens
]]
)
