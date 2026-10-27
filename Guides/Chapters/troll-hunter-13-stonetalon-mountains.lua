-- PLANNED: the beam route for Troll Hunter: tools/route_planner.py troll --preset all --install --force --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"troll-hunter-13-stonetalon-mountains",
	[[
#chapter 25-27 Stonetalon Mountains
step
  .goto 1442,40.76,52.57
  .turnin 79192 -- Stepping Stones
  .accept 79980 -- Scramble
  .goto 1442,39.62,49.86
  .turnin 79980 -- Scramble
step
  .goto 1442,47.46,58.38
  .accept 6301 -- Cycle of Rebirth
  .goto 1442,47.2,61.16
  .accept 6282 -- Harpies Threaten
  .accept 86576 -- Bloodfury Trinkets
  .goto 1442,47.36,64.25
  .accept 6562 -- Trouble in the Deeps
  .note Trouble in the Deeps: dungeon quest: needs a group
  .accept 6393 -- Elemental War
  .optional 6562 -- dungeon quest: Trouble in the Deeps
step
  .goto 1442,45.12,59.84 >> Go to the flight master
  .fp 1442,Sun Rock Retreat
step
  .goto 1442,32.89,60.74
  .complete 86576 -- Bloodfury Trinkets
  .complete 6282,1 -- Harpies Threaten
  .complete 6282,2 -- Harpies Threaten
step
  .goto 1442,47.22,64.04
  .turnin 86576 -- Bloodfury Trinkets
step
  .goto 1442,37.28,65.74
  .complete 6282,3 -- Harpies Threaten
  .complete 6393 -- Elemental War
  .complete 6282,4 -- Harpies Threaten
step
  .goto 1442,47.36,64.25
  .turnin 6393 -- Elemental War
  .goto 1442,47.2,61.16
  .turnin 6282 -- Harpies Threaten
  .accept 6283 -- Bloodfury Bloodline
  .optional 6283 -- group quest: Bloodfury Bloodline
step
  .goto 1442,58.99,62.6
  .accept 1093 -- Super Reaper 6000
step
  .goto 1442,62.73,53.48
  .complete 1093 -- Super Reaper 6000
step
  .goto 1442,71.87,60.0
  .accept 1090 -- Gerenzo's Orders
  .complete 1090,1 -- Gerenzo's Orders
  .note Gerenzo's Orders: event: the quest finishes when something happens here (an ambush, a ritual); read the quest log
  .turnin 1090 -- Gerenzo's Orders
  .accept 1092 -- Gerenzo's Orders
step
  .goto 1442,58.99,62.6
  .turnin 1093 -- Super Reaper 6000
  .turnin 1092 -- Gerenzo's Orders
step
  .goto 1442,48.92,43.85
  .complete 6301 -- Cycle of Rebirth
  .complete 97538 -- Pigments for Paints
step
  .goto 1442,47.46,58.38
  .turnin 6301 -- Cycle of Rebirth
  .accept 6381 -- New Life
step
  .goto 1442,35.85,70.31
  .complete 6381 -- New Life
step
  .goto 1442,47.46,58.38
  .turnin 6381 -- New Life
step
  .goto 1442,30.75,61.91
  .complete 6283 -- Bloodfury Bloodline
  .optional 6283 -- group quest: Bloodfury Bloodline
step
  .goto 1442,47.2,61.16
  .turnin 6283 -- Bloodfury Bloodline
  .optional 6283 -- group quest: Bloodfury Bloodline
step
  .goto 1442,45.12,59.84 >> Go to the flight master
  .fly Thunder Bluff
step
  .goto 1456,54.14,47.05
  .turnin 97538 -- Pigments for Paints
  .goto 1456,71.06,34.19
  .level 24
  .accept 98823 -- Earthen Echo
step
  .todo "Walk from Thunder Bluff to Mulgore: the guide has no waypoints for this yet, so find your own way. This step is done when you arrive in Mulgore."
  .zone 1412 >> Go to Mulgore
step
  .goto 1412,33.41,22.59
  .turnin 98823 -- Earthen Echo
  .accept 96259 -- Defending the Dead
  .accept 96261 -- The Broodmother
  .goto 1412,32.5,20.66
  .accept 96241 -- Talkin' bout Toxins, Mon
  .goto 1412,32.47,19.98
  .accept 96260 -- Stronger than Steel
  .level 27 -- reach it first: kill or grind on the way
  .note Grind about 2,100 experience before you go on: about 12 kills of creatures near your level (an estimate)
step
  .todo "Walk from Mulgore to Stonetalon Mountains: the guide has no waypoints for this yet, so find your own way. This step is done when you arrive in Stonetalon Mountains."
  .zone 1442 >> Go to Stonetalon Mountains
step
  .goto 1442,74.54,97.94
  .turnin 1060 -- Letter to Jin'Zil
step
  .goto 1442,45.12,59.84 >> Go to the flight master
  .fly Crossroads
step
  .todo "Walk from The Barrens to Ashenvale: the guide has no waypoints for this yet, so find your own way. This step is done when you arrive in Ashenvale."
  .zone 1440 >> Go to Ashenvale
]]
)
