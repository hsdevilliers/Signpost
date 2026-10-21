-- PLANNED: the thorough route for Skyborne Druid (HARDCORE): tools/route_planner.py windshaper --preset all --install --force --quiet --completeness 0.6 --completeness-trip 45 (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"windshaper-druid-09-stonetalon-mountains",
	[[
#chapter 24-25 Stonetalon Mountains
step
  .goto 1442,71.87,60.0
  .accept 1090 -- Gerenzo's Orders
  .complete 1090,1 -- Gerenzo's Orders
  .note Gerenzo's Orders: HARDCORE event: enemies may come at you here; be healed and buffed first, and come back later if unsure
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
  .accept 1094 -- Further Instructions
step
  .goto 1442,47.46,58.38
  .accept 6301 -- Cycle of Rebirth
  .goto 1442,47.36,64.25
  .accept 6393 -- Elemental War
step
  .goto 1442,45.12,59.84 >> Go to the flight master
  .fp 1442,Sun Rock Retreat
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
  .level 25 -- reach it first: kill or grind on the way
  .note Grind about 350 experience before you go on: about 2 kills of creatures near your level (an estimate)
step
  .goto 1442,47.2,61.16
  .accept 6282 -- Harpies Threaten
  .accept 86576 -- Bloodfury Trinkets
  .note Elites roam among these harpies: Bloodfury Ripper (elite, near 31,62) and Sister Riven (rare elite, near 30,69). Kill only the ordinary harpies and keep away from those two.
step
  .goto 1442,34.51,60.8
  .complete 6282,1 -- Harpies Threaten
  .complete 86576 -- Bloodfury Trinkets
  .complete 6381 -- New Life
step
  .goto 1442,36.98,69.78
  .complete 6282,3 -- Harpies Threaten
  .complete 6282,4 -- Harpies Threaten
step
  .goto 1442,47.22,64.04
  .turnin 86576 -- Bloodfury Trinkets
  .goto 1442,47.46,58.38
  .turnin 6381 -- New Life
step
  .goto 1442,31.11,58.55
  .complete 6282,2 -- Harpies Threaten
step
  .goto 1442,47.2,61.16
  .turnin 6282 -- Harpies Threaten
step
  .goto 1442,45.12,59.84 >> Go to the flight master
  .fly Thunder Bluff
]]
)
