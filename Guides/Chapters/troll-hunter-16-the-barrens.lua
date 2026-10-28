-- PLANNED: the beam route for Troll Hunter: tools/route_planner.py troll --preset all --install --force --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"troll-hunter-16-the-barrens",
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
  .goto 1413,43.75,83.26
  .complete 879,2 -- Betrayal from Within
step
  .goto 1413,45.12,80.07
  .complete 879,1 -- Betrayal from Within
step
  .goto 1413,44.55,59.26
  .turnin 879 -- Betrayal from Within
  .accept 906 -- Betrayal from Within
step
  .goto 1413,51.5,30.87
  .turnin 906 -- Betrayal from Within
  .goto 1413,51.07,29.63
  .level 29
  .accept 1145 -- The Swarm Grows
  .goto 1413,52.23,31.01
  .turnin 905 -- The Angry Scytheclaws
  .goto 1413,52.26,31.93
  .turnin 877 -- The Stagnant Oasis
step
  .goto 1413,51.5,30.34 >> Go to the flight master
  .fly Orgrimmar
step
  .goto 1454,57.2,53.32
  .accept 95697 -- Changing Tastes
  .todo "Changing Tastes: objective 1 has no position in the pack"
  .complete 95697,1 -- Changing Tastes
  .turnin 95697 -- Changing Tastes
step
  .goto 1454,75.23,34.24
  .turnin 1145 -- The Swarm Grows
]]
)
