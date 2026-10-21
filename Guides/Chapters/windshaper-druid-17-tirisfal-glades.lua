-- PLANNED: the thorough alt 4 route for Skyborne Druid (HARDCORE): tools/route_planner.py windshaper --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"windshaper-druid-17-tirisfal-glades",
	[[
#chapter 26-26 Tirisfal Glades
step
  .goto 1420,65.25,60.2
  .accept 92422 -- The Wrath of Rath'mael
  .todo "The Wrath of Rath'mael: objective 1 has no position in the pack"
  .complete 92422,1 -- The Wrath of Rath'mael
  .turnin 92422 -- The Wrath of Rath'mael
step
  .todo "travel from Tirisfal Glades to Undercity: the travel graph has no route yet"
  .zone 1458 >> Go to Undercity
step
  .goto 1458,73.4,33.0
  .turnin 78127 -- The Dalaran Digest
step
  .goto 1458,53.74,54.46
  .accept 1013 -- The Book of Ur
  .todo "The Book of Ur: objective 1 has no position in the pack"
  .complete 1013,1 -- The Book of Ur
  .turnin 1013 -- The Book of Ur
step
  .todo "travel from Undercity to Ashenvale: the travel graph has no route yet"
  .zone 1440 >> Go to Ashenvale
step
  .goto 1440,31.74,38.0
  .complete 216 -- Between a Rock and a Thistlefur
step
  .goto 1440,11.9,34.54
  .turnin 216 -- Between a Rock and a Thistlefur
  .accept 6621 -- King of the Foulweald
  .todo "King of the Foulweald: objective 1 has no position in the pack"
  .complete 6621,1 -- King of the Foulweald
  .turnin 6621 -- King of the Foulweald
step
  .goto 1440,11.56,34.29
  .accept 6921 -- Amongst the Ruins
  .todo "Amongst the Ruins: objective 1 has no position in the pack"
  .complete 6921,1 -- Amongst the Ruins
  .turnin 6921 -- Amongst the Ruins
step
  .todo "border The Barrens/Ashenvale: no crossing coordinates yet (record them in game or in Borders.lua)"
  .zone 1413 >> Go into The Barrens
step
  .todo "border The Barrens/Stonetalon Mountains: no crossing coordinates yet (record them in game or in Borders.lua)"
  .zone 1442 >> Go into Stonetalon Mountains
step
  .goto 1442,47.46,58.38
  .accept 6301 -- Cycle of Rebirth
  .goto 1442,47.2,61.16
  .accept 6282 -- Harpies Threaten
  .accept 86576 -- Bloodfury Trinkets
  .goto 1442,47.36,64.25
  .accept 6393 -- Elemental War
]]
)
