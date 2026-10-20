-- PLANNED: the thorough alt 1 route for Troll Hunter: tools/route_planner.py troll --preset all --install --force --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"troll-hunter-16-stonetalon-mountains",
	[[
#chapter 25-26 Stonetalon Mountains
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
  .goto 1442,62.73,53.48
  .complete 1093 -- Super Reaper 6000
step
  .goto 1442,58.99,62.6
  .turnin 1093 -- Super Reaper 6000
step
  .goto 1442,47.46,58.38
  .accept 6301 -- Cycle of Rebirth
  .goto 1442,47.2,61.16
  .accept 6282 -- Harpies Threaten
  .accept 86576 -- Bloodfury Trinkets
  .goto 1442,47.36,64.25
  .accept 6393 -- Elemental War
step
  .goto 1442,37.28,65.74
  .complete 6282,3 -- Harpies Threaten
  .complete 86576 -- Bloodfury Trinkets
  .complete 6393 -- Elemental War
  .complete 6282,4 -- Harpies Threaten
step
  .goto 1442,47.22,64.04
  .turnin 86576 -- Bloodfury Trinkets
  .goto 1442,47.36,64.25
  .turnin 6393 -- Elemental War
step
  .goto 1442,34.51,60.8
  .complete 6282,1 -- Harpies Threaten
  .complete 6282,2 -- Harpies Threaten
step
  .goto 1442,47.2,61.16
  .turnin 6282 -- Harpies Threaten
  .accept 6283 -- Bloodfury Bloodline
  .optional 6283 -- group quest: Bloodfury Bloodline
step
  .goto 1442,48.92,43.85
  .complete 6301 -- Cycle of Rebirth
  .complete 97538 -- Pigments for Paints
step
  .goto 1442,47.46,58.38
  .turnin 6301 -- Cycle of Rebirth
  .accept 6381 -- New Life
step
  .goto 1442,31.36,68.54
  .complete 6381 -- New Life
  .complete 6283 -- Bloodfury Bloodline
  .optional 6283 -- group quest: Bloodfury Bloodline
step
  .goto 1442,47.2,61.16
  .turnin 6283 -- Bloodfury Bloodline
  .optional 6283 -- group quest: Bloodfury Bloodline
  .goto 1442,47.46,58.38
  .turnin 6381 -- New Life
step
  .todo "travel from Stonetalon Mountains to Thunder Bluff: the travel graph has no route yet"
  .zone 1456 >> Go to Thunder Bluff
]]
)
