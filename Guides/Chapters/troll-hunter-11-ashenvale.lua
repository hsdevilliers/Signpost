-- PLANNED: the beam route for Troll Hunter, planned by tools/route_planner.py on 2026-10-20 (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"troll-hunter-11-ashenvale",
	[[
#chapter 21-22 Ashenvale
step
  .goto 1440,43.4,70.4
  .accept 78132 -- Dragonslayer's Helm
  .accept 78133 -- Dragonslayer's Shield
  .accept 78134 -- Dragonslayer's Lance
  .turnin 78132 -- Dragonslayer's Helm
  .turnin 78133 -- Dragonslayer's Shield
  .turnin 78134 -- Dragonslayer's Lance
step
  .goto 1440,40.43,61.48
  .accept 98251 -- Never Coming Back
  .accept 98252 -- A Void Path
  .turnin 98252 -- A Void Path
step
  .goto 1440,51.43,55.27
  .complete 98251 -- Never Coming Back
step
  .goto 1440,40.43,61.48
  .turnin 98251 -- Never Coming Back
step
  .todo "border The Barrens/Ashenvale: no crossing coordinates yet (record them in game or in Borders.lua)"
  .zone 1413 >> Go into The Barrens
step
  .todo "border The Barrens/Stonetalon Mountains: no crossing coordinates yet (record them in game or in Borders.lua)"
  .zone 1442 >> Go into Stonetalon Mountains
step
  .goto 1442,71.87,60.0
  .accept 1090 -- Gerenzo's Orders
  .turnin 1090 -- Gerenzo's Orders
  .accept 1092 -- Gerenzo's Orders
step
  .goto 1442,58.99,62.6
  .turnin 1092 -- Gerenzo's Orders
  .accept 1093 -- Super Reaper 6000
step
  .goto 1442,58.22,51.74
  .accept 78270 -- Goblin Lockpicks
  .turnin 78270 -- Goblin Lockpicks
step
  .goto 1442,47.46,58.38
  .accept 6301 -- Cycle of Rebirth
  .accept 86576 -- Bloodfury Trinkets
  .accept 6421 -- Boulderslide Ravine
  .accept 6562 -- Trouble in the Deeps
  .accept 6393 -- Elemental War
]]
)
