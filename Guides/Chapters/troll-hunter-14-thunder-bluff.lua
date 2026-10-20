-- PLANNED: the thorough alt 1 route for Troll Hunter: tools/route_planner.py troll --preset all --install --force --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"troll-hunter-14-thunder-bluff",
	[[
#chapter 24-25 Thunder Bluff
step
  .goto 1456,54.97,51.41
  .accept 1195 -- The Sacred Flame
  .todo "The Sacred Flame: objective 1 has no position in the pack"
  .complete 1195,1 -- The Sacred Flame
  .turnin 1195 -- The Sacred Flame
step
  .goto 1456,54.14,47.05
  .accept 97538 -- Pigments for Paints
step
  .todo "travel from Thunder Bluff to Stonetalon Mountains: the travel graph has no route yet"
  .zone 1442 >> Go to Stonetalon Mountains
step
  .goto 1442,40.76,52.57
  .turnin 79192 -- Stepping Stones
  .accept 79980 -- Scramble
  .goto 1442,39.62,49.86
  .turnin 79980 -- Scramble
step
  .todo "border The Barrens/Stonetalon Mountains: no crossing coordinates yet (record them in game or in Borders.lua)"
  .zone 1413 >> Go into The Barrens
step
  .todo "border The Barrens/Ashenvale: no crossing coordinates yet (record them in game or in Borders.lua)"
  .zone 1440 >> Go into Ashenvale
step
  .goto 1440,11.69,34.91
  .accept 6442 -- Naga at the Zoram Strand
  .goto 1440,12.06,34.63
  .accept 6641 -- Vorsha the Lasher
  .goto 1440,12.22,34.22
  .turnin 6641 -- Vorsha the Lasher
step
  .goto 1440,11.56,34.29
  .accept 6921 -- Amongst the Ruins
  .todo "Amongst the Ruins: objective 1 has no position in the pack"
  .complete 6921,1 -- Amongst the Ruins
  .turnin 6921 -- Amongst the Ruins
step
  .goto 1440,11.25,31.02
  .complete 6442 -- Naga at the Zoram Strand
step
  .goto 1440,11.69,34.91
  .turnin 6442 -- Naga at the Zoram Strand
]]
)
