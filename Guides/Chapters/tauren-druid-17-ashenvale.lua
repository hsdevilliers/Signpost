-- PLANNED: the thorough route for Tauren Druid (HARDCORE): tools/route_planner.py tauren --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"tauren-druid-17-ashenvale",
	[[
#chapter 25-25 Ashenvale
step
  .goto 1440,73.78,61.46
  .turnin 6382 -- The Ashenvale Hunt
  .accept 6383 -- The Ashenvale Hunt
  .turnin 6383 -- The Ashenvale Hunt
  .goto 1440,73.06,61.48
  .level 21
  .accept 6441 -- Satyr Horns
step
  .goto 1440,67.12,56.41
  .complete 6441 -- Satyr Horns
step
  .goto 1440,73.06,61.48
  .turnin 6441 -- Satyr Horns
step
  .goto 1440,71.11,68.12
  .accept 6503 -- Ashenvale Outrunners
step
  .goto 1440,72.87,70.18
  .complete 6503 -- Ashenvale Outrunners
step
  .goto 1440,71.11,68.12
  .turnin 6503 -- Ashenvale Outrunners
step
  .todo "border The Barrens/Ashenvale: no crossing coordinates yet (record them in game or in Borders.lua)"
  .zone 1413 >> Go into The Barrens
step
  .todo "border The Barrens/Stonetalon Mountains: no crossing coordinates yet (record them in game or in Borders.lua)"
  .zone 1442 >> Go into Stonetalon Mountains
step
  .goto 1442,40.76,52.57
  .turnin 79192 -- Stepping Stones
step
  .goto 1442,47.46,58.38
  .accept 6381 -- New Life
  .goto 1442,47.2,61.16
  .accept 6282 -- Harpies Threaten
  .accept 86576 -- Bloodfury Trinkets
  .goto 1442,47.36,64.25
  .accept 6393 -- Elemental War
]]
)
