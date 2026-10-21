-- PLANNED: the thorough alt 3 route for Tauren Druid (HARDCORE): tools/route_planner.py tauren --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"tauren-druid-13-stonetalon-mountains",
	[[
#chapter 22-22 Stonetalon Mountains
step
  .goto 1442,62.14,93.05
  .complete 6421 -- Boulderslide Ravine
step
  .goto 1442,58.99,62.6
  .turnin 1093 -- Super Reaper 6000
  .accept 1094 -- Further Instructions
step
  .goto 1442,47.46,58.38
  .accept 6301 -- Cycle of Rebirth
  .goto 1442,47.22,64.04
  .turnin 6421 -- Boulderslide Ravine
step
  .goto 1442,45.12,59.84 >> Go to the flight master
  .fp 1442,Sun Rock Retreat
step
  .goto 1442,46.31,39.6
  .complete 6301 -- Cycle of Rebirth
step
  .goto 1442,47.46,58.38
  .turnin 6301 -- Cycle of Rebirth
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
step
  .goto 1442,75.59,83.58
  .complete 6629 -- Kill Grundig Darkcloud
step
  .goto 1442,45.12,59.84 >> Go to the flight master
  .fly Crossroads
step
  .goto 1413,35.19,27.76
  .turnin 6629 -- Kill Grundig Darkcloud
step
  .goto 1413,52.26,31.93
  .turnin 6127 .class DRUID -- The Principal Source
  .accept 6128 .class DRUID -- Gathering the Cure
step
  .todo "Get from The Barrens to Silverpine Forest: they are on different continents, so you need a boat, a zeppelin or another ride, and the guide has no dock for it yet. This step is done when you arrive in Silverpine Forest."
  .zone 1421 >> Go to Silverpine Forest
]]
)
