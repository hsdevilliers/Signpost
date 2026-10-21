-- PLANNED: the thorough alt 5 route for Skyborne Druid (HARDCORE): tools/route_planner.py windshaper --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"windshaper-druid-13-silverpine-forest",
	[[
#chapter 22-23 Silverpine Forest
step
  .goto 1421,58.44,34.9
  .turnin 438 -- The Decrepit Ferry
  .accept 439 -- Rot Hide Clues
step
  .goto 1421,58.12,69.77
  .accept 95883 -- The Tortured Soul
  .accept 95885 -- The Offering of Blood
step
  .goto 1421,58.06,69.89
  .complete 516 -- Beren's Peril
  .complete 95883 -- The Tortured Soul
  .complete 95885 -- The Offering of Blood
step
  .goto 1421,58.12,69.77
  .turnin 95883 -- The Tortured Soul
  .turnin 95885 -- The Offering of Blood
step
  .goto 1421,63.51,58.13
  .complete 95981 -- Watching the Roads
step
  .goto 1421,46.08,85.63
  .complete 98299 -- Stop the Spread
step
  .goto 1421,49.89,60.33
  .turnin 477 -- Border Crossings
  .accept 478 -- Maps and Runes
step
  .goto 1421,43.98,40.93
  .turnin 478 -- Maps and Runes
  .turnin 95981 -- Watching the Roads
  .turnin 516 -- Beren's Peril
  .accept 481 -- Dalar's Analysis
  .goto 1421,43.42,40.86
  .turnin 439 -- Rot Hide Clues
  .accept 443 -- Rot Hide Ichor
  .goto 1421,44.2,39.81
  .turnin 98299 -- Stop the Spread
  .turnin 481 -- Dalar's Analysis
  .accept 482 -- Dalaran's Intentions
  .turnin 482 -- Dalaran's Intentions
  .accept 479 -- Ambermill Investigations
step
  .goto 1421,58.65,63.2
  .complete 479 -- Ambermill Investigations
  .complete 78127 -- The Dalaran Digest
step
  .todo "travel from Silverpine Forest to Undercity: the travel graph has no route yet"
  .zone 1458 >> Go to Undercity
]]
)
