-- PLANNED: the thorough route for Tauren Druid (HARDCORE): tools/route_planner.py tauren --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"tauren-druid-08-stonetalon-mountains",
	[[
#chapter 18-18 Stonetalon Mountains
step
  .goto 1442,80.76,89.41
  .complete 6548 -- Avenge My Village
step
  .todo "border The Barrens/Stonetalon Mountains: no crossing coordinates yet (record them in game or in Borders.lua)"
  .zone 1413 >> Go into The Barrens
step
  .goto 1413,35.19,27.76
  .turnin 6548 -- Avenge My Village
  .accept 6629 -- Kill Grundig Darkcloud
step
  .todo "border The Barrens/Stonetalon Mountains: no crossing coordinates yet (record them in game or in Borders.lua)"
  .zone 1442 >> Go into Stonetalon Mountains
step
  .goto 1442,73.65,86.12
  .complete 6629 -- Kill Grundig Darkcloud
step
  .goto 1442,71.25,95.02
  .accept 6461 -- Blood Feeders
step
  .goto 1442,58.98,73.79
  .complete 6461,1 -- Blood Feeders
step
  .goto 1442,47.22,64.04
  .accept 6421 -- Boulderslide Ravine
step
  .todo "travel from Stonetalon Mountains to Mulgore: the travel graph has no route yet"
  .zone 1412 >> Go to Mulgore
step
  .goto 1412,33.39,22.09
  .accept 6126 .class DRUID -- Lessons Anew
  .note Moonglade again: this chain goes back and forth between Thunder Bluff, Moonglade and the Crossroads. VERIFY(beta): the way there and back is unconfirmed (see the note on the first Moonglade quest).
step
  .todo "travel from Mulgore to Thunder Bluff: the travel graph has no route yet"
  .zone 1456 >> Go to Thunder Bluff
step
  .goto 1456,45.77,55.84
  .turnin 6362 -- Ride to Thunder Bluff
  .accept 6363 -- Tal the Wind Rider Master
  .goto 1456,47.0,49.83
  .turnin 6363 -- Tal the Wind Rider Master
]]
)
