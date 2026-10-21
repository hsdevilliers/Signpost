-- PLANNED: the thorough route for Tauren Druid (HARDCORE): tools/route_planner.py tauren --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"tauren-druid-13-silverpine-forest",
	[[
#chapter 21-22 Silverpine Forest
step
  .goto 1421,59.58,40.99
  .complete 98298 -- Arugal's Folly
step
  .goto 1421,58.44,34.9
  .turnin 438 -- The Decrepit Ferry
  .accept 439 -- Rot Hide Clues
step
  .goto 1421,44.2,39.81
  .turnin 98298 -- Arugal's Folly
  .goto 1421,43.42,40.86
  .turnin 439 -- Rot Hide Clues
step
  .goto 1421,58.06,69.89
  .complete 516 -- Beren's Peril
step
  .goto 1421,58.12,69.77
  .accept 95883 -- The Tortured Soul
  .accept 95885 -- The Offering of Blood
step
  .goto 1421,58.06,69.89
  .complete 95883 -- The Tortured Soul
  .complete 95885 -- The Offering of Blood
step
  .goto 1421,58.12,69.77
  .turnin 95883 -- The Tortured Soul
  .turnin 95885 -- The Offering of Blood
step
  .goto 1421,63.5,63.2
  .complete 78127 -- The Dalaran Digest
  .complete 95981 -- Watching the Roads
step
  .todo "travel from Silverpine Forest to Undercity: the travel graph has no route yet"
  .zone 1458 >> Go to Undercity
]]
)
