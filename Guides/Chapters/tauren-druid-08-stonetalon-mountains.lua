-- PLANNED: the thorough alt 4 route for Tauren Druid (HARDCORE): tools/route_planner.py tauren --preset all --install --quiet (docs/PLANNER.md)
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
  .goto 1442,73.48,85.59
  .accept 6523 -- Protect Kaya
step
  .todo "border The Barrens/Stonetalon Mountains: no crossing coordinates yet (record them in game or in Borders.lua)"
  .zone 1413 >> Go into The Barrens
step
  .goto 1413,35.19,27.76
  .turnin 6523 -- Protect Kaya
  .turnin 6548 -- Avenge My Village
  .accept 6629 -- Kill Grundig Darkcloud
step
  .todo "border The Barrens/Stonetalon Mountains: no crossing coordinates yet (record them in game or in Borders.lua)"
  .zone 1442 >> Go into Stonetalon Mountains
step
  .goto 1442,77.79,86.33
  .complete 6629 -- Kill Grundig Darkcloud
step
  .goto 1442,71.25,95.02
  .accept 6461 -- Blood Feeders
step
  .goto 1442,65.36,92.28
  .complete 6461,1 -- Blood Feeders
step
  .todo "travel from Stonetalon Mountains to Thunder Bluff: the travel graph has no route yet"
  .zone 1456 >> Go to Thunder Bluff
step
  .goto 1456,76.48,27.22
  .accept 6126 .class DRUID -- Lessons Anew
  .accept 26 .class DRUID -- A Lesson to Learn
  .goto 1456,78.62,28.56
  .turnin 1489 -- Hamuul Runetotem
  .accept 1490 -- Nara Wildmane
  .goto 1456,75.65,31.61
  .turnin 1490 -- Nara Wildmane
step
  .todo "travel from Thunder Bluff to Moonglade: the travel graph has no route yet"
  .zone 1450 >> Go to Moonglade
]]
)
