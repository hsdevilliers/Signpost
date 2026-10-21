-- PLANNED: the thorough alt 4 route for Tauren Druid (HARDCORE): tools/route_planner.py tauren --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"tauren-druid-12-stonetalon-mountains",
	[[
#chapter 20-21 Stonetalon Mountains
step
  .goto 1442,62.73,53.48
  .complete 1093 -- Super Reaper 6000
step
  .goto 1442,71.87,60.0
  .accept 1090 -- Gerenzo's Orders
  .turnin 1090 -- Gerenzo's Orders
  .accept 1092 -- Gerenzo's Orders
step
  .goto 1442,58.99,62.6
  .turnin 1093 -- Super Reaper 6000
  .turnin 1092 -- Gerenzo's Orders
  .accept 1094 -- Further Instructions
step
  .goto 1442,71.25,95.02
  .turnin 6461 -- Blood Feeders
step
  .todo "travel from Stonetalon Mountains to Thunder Bluff: the travel graph has no route yet"
  .zone 1456 >> Go to Thunder Bluff
step
  .goto 1456,76.48,27.22
  .turnin 6130 .class DRUID -- Power over Poison
  .turnin 98362 .class DRUID -- To Thunder Bluff
step
  .todo "travel from Thunder Bluff to The Barrens: the travel graph has no route yet"
  .zone 1413 >> Go to The Barrens
step
  .goto 1413,35.26,27.88
  .turnin 1062 -- Goblin Invaders
  .goto 1413,35.19,27.76
  .turnin 6629 -- Kill Grundig Darkcloud
step
  .goto 1413,48.17,52.89
  .complete 899 -- Consumed by Hatred
  .complete 95774 -- Her Name Is Olgra
step
  .goto 1413,52.02,46.47
  .complete 905 -- The Angry Scytheclaws
]]
)
