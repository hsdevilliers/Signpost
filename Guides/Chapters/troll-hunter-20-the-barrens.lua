-- PLANNED: the thorough alt 1 route for Troll Hunter: tools/route_planner.py troll --preset all --install --force --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"troll-hunter-20-the-barrens",
	[[
#chapter 29-29 The Barrens
step
  .goto 1413,49.18,84.13
  .complete 846 -- Revenge of Gann
step
  .goto 1413,45.89,77.0
  .turnin 846 -- Revenge of Gann
  .accept 849 -- Revenge of Gann
step
  .goto 1413,46.97,85.63
  .complete 849 -- Revenge of Gann
step
  .goto 1413,45.89,77.0
  .turnin 849 -- Revenge of Gann
step
  .goto 1413,45.12,80.07
  .complete 879,1 -- Betrayal from Within
step
  .goto 1413,43.75,83.26
  .complete 879,2 -- Betrayal from Within
step
  .goto 1413,44.55,59.26
  .turnin 879 -- Betrayal from Within
  .accept 906 -- Betrayal from Within
step
  .goto 1413,51.5,30.87
  .turnin 906 -- Betrayal from Within
step
  .todo "travel from The Barrens to Orgrimmar: the travel graph has no route yet"
  .zone 1454 >> Go to Orgrimmar
step
  .goto 1454,57.2,53.32
  .accept 95697 -- Changing Tastes
  .todo "Changing Tastes: objective 1 has no position in the pack"
  .complete 95697,1 -- Changing Tastes
  .turnin 95697 -- Changing Tastes
step
  .goto 1454,47.06,46.43
  .accept 65601 -- Love Hurts
]]
)
