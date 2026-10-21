-- PLANNED: the beam route for Skyborne Druid (HARDCORE): tools/route_planner.py windshaper --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"windshaper-druid-15-stonetalon-mountains",
	[[
#chapter 24-24 Stonetalon Mountains
step
  .goto 1442,47.36,64.25
  .turnin 6393 -- Elemental War
step
  .goto 1442,35.85,70.31
  .complete 6381 -- New Life
step
  .goto 1442,47.46,58.38
  .turnin 6381 -- New Life
step
  .goto 1442,66.32,56.51
  .complete 1062 -- Goblin Invaders
step
  .todo "border The Barrens/Stonetalon Mountains: no crossing coordinates yet (record them in game or in Borders.lua)"
  .zone 1413 >> Go into The Barrens
step
  .goto 1413,35.26,27.88
  .turnin 1062 -- Goblin Invaders
  .accept 1063 -- The Elder Crone
step
  .todo "travel from The Barrens to Thunder Bluff: the travel graph has no route yet"
  .zone 1456 >> Go to Thunder Bluff
step
  .goto 1456,54.97,51.41
  .accept 1195 -- The Sacred Flame
  .todo "The Sacred Flame: objective 1 has no position in the pack"
  .complete 1195,1 -- The Sacred Flame
  .turnin 1195 -- The Sacred Flame
step
  .goto 1456,69.85,30.91
  .turnin 1063 -- The Elder Crone
  .goto 1456,76.48,27.22
  .accept 98340 .class DRUID -- The Great Cat Spirit
  .goto 1456,78.62,28.56
  .turnin 1489 -- Hamuul Runetotem
step
  .todo "travel from Thunder Bluff to Moonglade: the travel graph has no route yet"
  .zone 1450 >> Go to Moonglade
step
  .goto 1450,56.21,30.64
  .turnin 94913 .class DRUID -- Moonglade
  .turnin 98340 .class DRUID -- The Great Cat Spirit
  .accept 98341 .class DRUID -- The Great Windborne Cat Spirit
]]
)
