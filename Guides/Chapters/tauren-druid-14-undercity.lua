-- PLANNED: the thorough route for Tauren Druid (HARDCORE): tools/route_planner.py tauren --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"tauren-druid-14-undercity",
	[[
#chapter 22-23 Undercity
step
  .goto 1458,73.4,33.0
  .turnin 78127 -- The Dalaran Digest
  .turnin 79096 -- Ataeric: On Arcane Curiosities
step
  .goto 1458,67.69,13.55
  .complete 92401 -- A Frightened Request
step
  .todo "travel from Undercity to Silverpine Forest: the travel graph has no route yet"
  .zone 1421 >> Go to Silverpine Forest
step
  .goto 1421,43.98,40.93
  .turnin 95981 -- Watching the Roads
  .turnin 516 -- Beren's Peril
  .goto 1421,44.52,43.02
  .turnin 92401 -- A Frightened Request
step
  .goto 1421,45.96,85.77
  .complete 98299 -- Stop the Spread
step
  .goto 1421,44.2,39.81
  .turnin 98299 -- Stop the Spread
step
  .todo "travel from Silverpine Forest to Thunder Bluff: the travel graph has no route yet"
  .zone 1456 >> Go to Thunder Bluff
step
  .goto 1456,76.48,27.22
  .turnin 6130 .class DRUID -- Power over Poison
  .turnin 98362 .class DRUID -- To Thunder Bluff
step
  .todo "travel from Thunder Bluff to Stonetalon Mountains: the travel graph has no route yet"
  .zone 1442 >> Go to Stonetalon Mountains
step
  .goto 1442,62.14,93.05
  .complete 6421 -- Boulderslide Ravine
]]
)
