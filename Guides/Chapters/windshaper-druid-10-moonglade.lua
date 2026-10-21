-- PLANNED: the thorough alt 4 route for Skyborne Druid (HARDCORE): tools/route_planner.py windshaper --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"windshaper-druid-10-moonglade",
	[[
#chapter 20-21 Moonglade
step
  .goto 1450,56.21,30.64
  .turnin 94913 .class DRUID -- Moonglade
  .turnin 98340 .class DRUID -- The Great Cat Spirit
  .accept 98341 .class DRUID -- The Great Windborne Cat Spirit
step
  .goto 1450,43.92,73.44
  .turnin 98341 .class DRUID -- The Great Windborne Cat Spirit
  .accept 98404 .class DRUID -- The Great Windborne Cat Spirit
  .todo "The Great Windborne Cat Spirit: objective 1 is only in places this guide does not go"
  .complete 98404,1 .class DRUID -- The Great Windborne Cat Spirit
  .todo "The Great Windborne Cat Spirit: objective 2 is only in places this guide does not go"
  .complete 98404,2 .class DRUID -- The Great Windborne Cat Spirit
  .todo "The Great Windborne Cat Spirit: objective 3 is only in places this guide does not go"
  .complete 98404,3 .class DRUID -- The Great Windborne Cat Spirit
  .turnin 98404 .class DRUID -- The Great Windborne Cat Spirit
  .accept 98738 .class DRUID -- Blessings of the Great Windborne Cat Spirit
step
  .goto 1450,56.21,30.64
  .turnin 98738 .class DRUID -- Blessings of the Great Windborne Cat Spirit
  .accept 98362 .class DRUID -- To Thunder Bluff
step
  .todo "travel from Moonglade to Ashenvale: the travel graph has no route yet"
  .zone 1440 >> Go to Ashenvale
step
  .goto 1440,40.43,61.48
  .accept 98251 -- Never Coming Back
  .accept 98252 -- A Void Path
  .goto 1440,38.23,58.15
  .turnin 98252 -- A Void Path
step
  .goto 1440,39.52,70.3
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
]]
)
