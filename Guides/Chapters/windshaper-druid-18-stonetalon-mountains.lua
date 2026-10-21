-- PLANNED: the beam route for Skyborne Druid (HARDCORE): tools/route_planner.py windshaper --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"windshaper-druid-18-stonetalon-mountains",
	[[
#chapter 25-26 Stonetalon Mountains
step
  .goto 1442,74.54,97.94
  .turnin 1060 -- Letter to Jin'Zil
step
  .goto 1442,47.2,61.16
  .accept 6282 -- Harpies Threaten
  .accept 86576 -- Bloodfury Trinkets
  .note Elites roam among these harpies: Bloodfury Ripper (elite, near 31,62) and Sister Riven (rare elite, near 30,69). Kill only the ordinary harpies and keep away from those two.
step
  .goto 1442,36.51,68.19
  .complete 86576 -- Bloodfury Trinkets
  .complete 6282,3 -- Harpies Threaten
  .complete 6282,4 -- Harpies Threaten
step
  .goto 1442,31.34,60.42
  .complete 6282,1 -- Harpies Threaten
  .complete 6282,2 -- Harpies Threaten
step
  .goto 1442,47.2,61.16
  .turnin 6282 -- Harpies Threaten
  .goto 1442,47.22,64.04
  .turnin 86576 -- Bloodfury Trinkets
step
  .goto 1442,47.5,41.0
  .complete 97538 -- Pigments for Paints
step
  .todo "travel from Stonetalon Mountains to Thunder Bluff: the travel graph has no route yet"
  .zone 1456 >> Go to Thunder Bluff
]]
)
