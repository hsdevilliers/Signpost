-- PLANNED: the thorough alt 5 route for Skyborne Druid (HARDCORE): tools/route_planner.py windshaper --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"windshaper-druid-21-ashenvale",
	[[
#chapter 27-28 Ashenvale
step
  .goto 1440,73.06,61.48
  .accept 6441 -- Satyr Horns
  .note The horns drop from the satyrs of the camps, among them the named Prince Raze (near 81.6,48.5) and Geltharis (near 78,42.4), whom the data does not rank: take the ordinary satyrs one at a time and leave the named ones if a fight looks bad.
  .goto 1440,73.78,61.46
  .turnin 6382 -- The Ashenvale Hunt
  .accept 6383 -- The Ashenvale Hunt
  .turnin 6383 -- The Ashenvale Hunt
step
  .goto 1440,67.12,56.41
  .complete 6441 -- Satyr Horns
step
  .goto 1440,73.06,61.48
  .turnin 6441 -- Satyr Horns
step
  .todo "border The Barrens/Ashenvale: no crossing coordinates yet (record them in game or in Borders.lua)"
  .zone 1413 >> Go into The Barrens
step
  .todo "border The Barrens/Stonetalon Mountains: no crossing coordinates yet (record them in game or in Borders.lua)"
  .zone 1442 >> Go into Stonetalon Mountains
step
  .goto 1442,58.99,62.6
  .turnin 1095 -- Further Instructions
  .accept 1096 -- Gerenzo Wrenchwhistle
step
  .goto 1442,40.76,52.57
  .turnin 79192 -- Stepping Stones
step
  .goto 1442,47.5,41.0
  .complete 97538 -- Pigments for Paints
step
  .goto 1442,64.49,40.25
  .complete 1096 -- Gerenzo Wrenchwhistle
step
  .goto 1442,58.99,62.6
  .turnin 1096 -- Gerenzo Wrenchwhistle
step
  .todo "travel from Stonetalon Mountains to Thunder Bluff: the travel graph has no route yet"
  .zone 1456 >> Go to Thunder Bluff
step
  .level 28 -- reach it first: kill or grind on the way
]]
)
