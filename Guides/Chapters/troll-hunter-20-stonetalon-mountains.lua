-- PLANNED: the thorough alt 4 route for Troll Hunter: tools/route_planner.py troll --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"troll-hunter-20-stonetalon-mountains",
	[[
#chapter 27-28 Stonetalon Mountains
step
  .goto 1442,58.99,62.6
  .turnin 1095 -- Further Instructions
  .accept 1096 -- Gerenzo Wrenchwhistle
step
  .goto 1442,64.49,40.25
  .complete 1096 -- Gerenzo Wrenchwhistle
step
  .goto 1442,58.99,62.6
  .turnin 1096 -- Gerenzo Wrenchwhistle
  .level 28 -- reach it first: kill or grind on the way
  .note Grind about 3,800 experience before you go on: about 21 kills of creatures near your level (an estimate)
step
  .todo "Walk from Stonetalon Mountains to Mulgore: the guide has no waypoints for this yet, so find your own way. This step is done when you arrive in Mulgore."
  .zone 1412 >> Go to Mulgore
step
  .goto 1412,33.42,7.46
  .complete 96261 -- The Broodmother
step
  .goto 1412,33.41,22.59
  .turnin 96261 -- The Broodmother
step
  .todo "Walk from Mulgore to Thousand Needles: the guide has no waypoints for this yet, so find your own way. This step is done when you arrive in Thousand Needles."
  .zone 1441 >> Go to Thousand Needles
]]
)
