-- PLANNED: the thorough alt 4 route for Tauren Druid (HARDCORE): tools/route_planner.py tauren --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"tauren-druid-22-stonetalon-mountains",
	[[
#chapter 27-27 Stonetalon Mountains
step
  .goto 1442,34.86,69.12
  .complete 6282,4 -- Harpies Threaten
step
  .goto 1442,47.2,61.16
  .turnin 6282 -- Harpies Threaten
step
  .todo "travel from Stonetalon Mountains to Thunder Bluff: the travel graph has no route yet"
  .zone 1456 >> Go to Thunder Bluff
step
  .goto 1456,54.97,51.41
  .accept 1195 -- The Sacred Flame
  .todo "The Sacred Flame: objective 1 has no position in the pack"
  .complete 1195,1 -- The Sacred Flame
  .turnin 1195 -- The Sacred Flame
step
  .todo "travel from Thunder Bluff to The Barrens: the travel graph has no route yet"
  .zone 1413 >> Go to The Barrens
step
  .goto 1413,44.86,59.14
  .accept 874 -- Mahren Skyseer
  .goto 1413,44.55,59.26
  .accept 879 -- Betrayal from Within
step
  .goto 1413,40.15,80.54
  .complete 879,3 -- Betrayal from Within
step
  .goto 1413,45.12,80.07
  .complete 879,1 -- Betrayal from Within
step
  .goto 1413,43.75,83.26
  .complete 879,2 -- Betrayal from Within
step
  .todo "border The Barrens/Thousand Needles: no crossing coordinates yet (record them in game or in Borders.lua)"
  .zone 1441 >> Go into Thousand Needles
step
  .goto 1441,32.24,22.17
  .level 23
  .accept 4542 -- Message to Freewind Post
step
  .goto 1441,44.64,50.29
  .level 24
  .accept 4821 -- Alien Egg
  .goto 1441,45.67,50.74
  .turnin 4542 -- Message to Freewind Post
  .accept 4841 -- Pacify the Centaur
]]
)
