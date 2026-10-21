-- PLANNED: the thorough alt 3 route for Tauren Druid (HARDCORE): tools/route_planner.py tauren --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"tauren-druid-19-stonetalon-mountains",
	[[
#chapter 26-26 Stonetalon Mountains
step
  .goto 1442,40.76,52.57
  .turnin 79192 -- Stepping Stones
  .accept 79980 -- Scramble
  .goto 1442,39.62,49.86
  .turnin 79980 -- Scramble
step
  .goto 1442,47.46,58.38
  .accept 6381 -- New Life
  .goto 1442,47.2,61.16
  .accept 6282 -- Harpies Threaten
  .accept 86576 -- Bloodfury Trinkets
  .note Elites roam among these harpies: Bloodfury Ripper (elite, near 31,62) and Sister Riven (rare elite, near 30,69). Kill only the ordinary harpies and keep away from those two.
  .goto 1442,47.36,64.25
  .accept 6393 -- Elemental War
step
  .goto 1442,32.75,64.45
  .complete 6282,1 -- Harpies Threaten
  .complete 86576 -- Bloodfury Trinkets
  .complete 6393 -- Elemental War
  .complete 6381 -- New Life
step
  .goto 1442,47.22,64.04
  .turnin 86576 -- Bloodfury Trinkets
  .goto 1442,47.36,64.25
  .turnin 6393 -- Elemental War
  .goto 1442,47.46,58.38
  .turnin 6381 -- New Life
step
  .goto 1442,37.28,65.74
  .complete 6282,3 -- Harpies Threaten
  .complete 6282,4 -- Harpies Threaten
step
  .goto 1442,31.11,58.55
  .complete 6282,2 -- Harpies Threaten
step
  .goto 1442,47.2,61.16
  .turnin 6282 -- Harpies Threaten
step
  .goto 1442,47.5,41.0
  .complete 97538 -- Pigments for Paints
step
  .goto 1442,45.12,59.84 >> Go to the flight master
  .fly Crossroads
step
  .todo "Walk from The Barrens to Ashenvale: the guide has no waypoints for this yet, so find your own way. This step is done when you arrive in Ashenvale."
  .zone 1440 >> Go to Ashenvale
]]
)
