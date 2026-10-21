-- PLANNED: the thorough alt 4 route for Skyborne Druid (HARDCORE): tools/route_planner.py windshaper --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"windshaper-druid-11-stonetalon-mountains",
	[[
#chapter 21-22 Stonetalon Mountains
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
  .goto 1442,74.54,97.94
  .turnin 1060 -- Letter to Jin'Zil
step
  .todo "travel from Stonetalon Mountains to Thunder Bluff: the travel graph has no route yet"
  .zone 1456 >> Go to Thunder Bluff
step
  .goto 1456,76.48,27.22
  .turnin 98362 .class DRUID -- To Thunder Bluff
step
  .todo "travel from Thunder Bluff to The Barrens: the travel graph has no route yet"
  .zone 1413 >> Go to The Barrens
step
  .goto 1413,35.19,27.76
  .turnin 6523 -- Protect Kaya
step
  .goto 1413,51.95,31.58
  .accept 899 -- Consumed by Hatred
  .accept 4921 -- Lost in Battle
  .accept 95774 -- Her Name Is Olgra
step
  .goto 1413,49.33,50.32
  .complete 4921 -- Lost in Battle
  .complete 899 -- Consumed by Hatred
  .complete 95774 -- Her Name Is Olgra
]]
)
