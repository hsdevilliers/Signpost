-- PLANNED: the thorough alt 4 route for Tauren Druid (HARDCORE): tools/route_planner.py tauren --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"tauren-druid-15-stonetalon-mountains",
	[[
#chapter 24-24 Stonetalon Mountains
step
  .goto 1442,47.46,58.38
  .accept 6301 -- Cycle of Rebirth
  .goto 1442,47.36,64.25
  .accept 6562 -- Trouble in the Deeps
  .accept 6393 -- Elemental War
step
  .goto 1442,40.76,52.57
  .accept 79980 -- Scramble
  .goto 1442,39.62,49.86
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
  .goto 1442,47.36,64.25
  .turnin 6393 -- Elemental War
step
  .goto 1442,35.85,70.31
  .complete 6381 -- New Life
step
  .goto 1442,47.46,58.38
  .turnin 6381 -- New Life
step
  .todo "border The Barrens/Stonetalon Mountains: no crossing coordinates yet (record them in game or in Borders.lua)"
  .zone 1413 >> Go into The Barrens
step
  .todo "border The Barrens/Ashenvale: no crossing coordinates yet (record them in game or in Borders.lua)"
  .zone 1440 >> Go into Ashenvale
]]
)
