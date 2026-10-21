-- PLANNED: the thorough alt 4 route for Tauren Druid (HARDCORE): tools/route_planner.py tauren --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"tauren-druid-21-undercity",
	[[
#chapter 26-27 Undercity
step
  .goto 1458,73.4,33.0
  .turnin 78127 -- The Dalaran Digest
step
  .todo "travel from Undercity to Ashenvale: the travel graph has no route yet"
  .zone 1440 >> Go to Ashenvale
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
  .goto 1440,13.59,13.14
  .complete 6563 -- The Essence of Aku'Mai
step
  .goto 1440,11.56,34.29
  .turnin 6563 -- The Essence of Aku'Mai
step
  .todo "border The Barrens/Ashenvale: no crossing coordinates yet (record them in game or in Borders.lua)"
  .zone 1413 >> Go into The Barrens
step
  .todo "border The Barrens/Stonetalon Mountains: no crossing coordinates yet (record them in game or in Borders.lua)"
  .zone 1442 >> Go into Stonetalon Mountains
step
  .goto 1442,47.2,61.16
  .accept 6282 -- Harpies Threaten
  .accept 86576 -- Bloodfury Trinkets
step
  .goto 1442,37.28,65.74
  .complete 6282,3 -- Harpies Threaten
  .complete 86576 -- Bloodfury Trinkets
step
  .goto 1442,47.22,64.04
  .turnin 86576 -- Bloodfury Trinkets
step
  .goto 1442,34.51,60.8
  .complete 6282,1 -- Harpies Threaten
  .complete 6282,2 -- Harpies Threaten
]]
)
