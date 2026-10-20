-- PLANNED: the beam route for Troll Hunter, planned by tools/route_planner.py on 2026-10-20 (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"troll-hunter-12-stonetalon-mountains",
	[[
#chapter 22-23 Stonetalon Mountains
step
  .goto 1442,40.76,52.57
  .accept 79980 -- Scramble
  .turnin 79980 -- Scramble
step
  .goto 1442,37.4,49.33
  .complete 6393 -- Elemental War
step
  .goto 1442,46.31,39.6
  .complete 6301 -- Cycle of Rebirth
step
  .goto 1442,47.46,58.38
  .turnin 6301 -- Cycle of Rebirth
  .accept 6381 -- New Life
  .turnin 6393 -- Elemental War
step
  .goto 1442,62.73,53.48
  .complete 1093 -- Super Reaper 6000
step
  .goto 1442,58.99,62.6
  .turnin 1093 -- Super Reaper 6000
  .accept 1094 -- Further Instructions
step
  .goto 1442,57.31,89.64
  .complete 6421 -- Boulderslide Ravine
step
  .goto 1442,47.22,64.04
  .turnin 6421 -- Boulderslide Ravine
  .accept 6481 -- Earthen Arise
  .todo "Earthen Arise: objective 1 has no position in the pack"
  .complete 6481,1 -- Earthen Arise
  .turnin 6481 -- Earthen Arise
  .optional 6481 -- group quest: Earthen Arise
step
  .goto 1442,35.85,70.31
  .complete 6381 -- New Life
step
  .goto 1442,47.46,58.38
  .turnin 6381 -- New Life
step
  .level 23 -- reach it first: kill or grind on the way
step
  .goto 1442,37.28,65.74
  .complete 86576 -- Bloodfury Trinkets
step
  .goto 1442,47.22,64.04
  .turnin 86576 -- Bloodfury Trinkets
step
  .todo "border The Barrens/Stonetalon Mountains: no crossing coordinates yet (record them in game or in Borders.lua)"
  .zone 1413 >> Go into The Barrens
step
  .todo "border The Barrens/Ashenvale: no crossing coordinates yet (record them in game or in Borders.lua)"
  .zone 1440 >> Go into Ashenvale
]]
)
