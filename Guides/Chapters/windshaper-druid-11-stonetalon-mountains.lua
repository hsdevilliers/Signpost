-- PLANNED: the beam route for Skyborne Druid (HARDCORE): tools/route_planner.py windshaper --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"windshaper-druid-11-stonetalon-mountains",
	[[
#chapter 22-22 Stonetalon Mountains
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
  .accept 1094 -- Further Instructions
step
  .goto 1442,73.48,85.59
  .accept 6523 -- Protect Kaya
step
  .goto 1442,74.4,85.7
  .complete 78149 -- Fury of the Land
step
  .goto 1442,71.25,95.02
  .accept 6461 -- Blood Feeders
step
  .goto 1442,58.98,73.79
  .complete 6461,1 -- Blood Feeders
step
  .goto 1442,47.36,64.25
  .accept 6562 -- Trouble in the Deeps
  .goto 1442,47.46,58.38
  .accept 6301 -- Cycle of Rebirth
step
  .goto 1442,46.31,39.6
  .complete 6301 -- Cycle of Rebirth
step
  .goto 1442,47.46,58.38
  .turnin 6301 -- Cycle of Rebirth
step
  .goto 1442,53.7,74.14
  .complete 6461,2 -- Blood Feeders
step
  .goto 1442,71.25,95.02
  .turnin 6461 -- Blood Feeders
step
  .todo "border The Barrens/Stonetalon Mountains: no crossing coordinates yet (record them in game or in Borders.lua)"
  .zone 1413 >> Go into The Barrens
]]
)
