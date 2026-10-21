-- PLANNED: the thorough route for Tauren Druid (HARDCORE): tools/route_planner.py tauren --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"tauren-druid-18-stonetalon-mountains",
	[[
#chapter 25-26 Stonetalon Mountains
step
  .goto 1442,37.34,60.45
  .complete 6393 -- Elemental War
  .complete 6282,1 -- Harpies Threaten
  .complete 86576 -- Bloodfury Trinkets
step
  .goto 1442,31.11,58.55
  .complete 6282,2 -- Harpies Threaten
step
  .goto 1442,47.22,64.04
  .turnin 86576 -- Bloodfury Trinkets
  .goto 1442,47.36,64.25
  .turnin 6393 -- Elemental War
step
  .goto 1442,37.28,65.74
  .complete 6282,3 -- Harpies Threaten
  .complete 6381 -- New Life
  .complete 6282,4 -- Harpies Threaten
step
  .goto 1442,47.2,61.16
  .turnin 6282 -- Harpies Threaten
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
