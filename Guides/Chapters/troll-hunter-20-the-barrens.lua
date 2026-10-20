-- PLANNED: the thorough alt 5 route for Troll Hunter: tools/route_planner.py troll --preset all --install --force --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"troll-hunter-20-the-barrens",
	[[
#chapter 29-30 The Barrens
step
  .goto 1413,48.97,86.31
  .accept 857 -- The Tear of the Moons
step
  .goto 1413,49.13,84.25
  .complete 857 -- The Tear of the Moons
step
  .goto 1413,48.97,86.31
  .turnin 857 -- The Tear of the Moons
step
  .todo "travel from The Barrens to Orgrimmar: the travel graph has no route yet"
  .zone 1454 >> Go to Orgrimmar
step
  .goto 1454,57.2,53.32
  .accept 95697 -- Changing Tastes
  .todo "Changing Tastes: objective 1 has no position in the pack"
  .complete 95697,1 -- Changing Tastes
  .turnin 95697 -- Changing Tastes
]]
)
