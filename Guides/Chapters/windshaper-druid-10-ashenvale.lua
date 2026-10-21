-- PLANNED: the thorough alt 5 route for Skyborne Druid (HARDCORE): tools/route_planner.py windshaper --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"windshaper-druid-10-ashenvale",
	[[
#chapter 21-21 Ashenvale
step
  .goto 1440,40.43,61.48
  .accept 98251 -- Never Coming Back
  .accept 98252 -- A Void Path
step
  .goto 1440,40.64,66.15
  .complete 98251 -- Never Coming Back
step
  .goto 1440,40.43,61.48
  .turnin 98251 -- Never Coming Back
  .goto 1440,38.23,58.15
  .turnin 98252 -- A Void Path
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
  .todo "travel from Stonetalon Mountains to Thunder Bluff: the travel graph has no route yet"
  .zone 1456 >> Go to Thunder Bluff
]]
)
