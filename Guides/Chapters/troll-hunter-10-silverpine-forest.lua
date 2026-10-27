-- PLANNED: the beam route for Troll Hunter: tools/route_planner.py troll --preset all --install --force --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"troll-hunter-10-silverpine-forest",
	[[
#chapter 19-21 Silverpine Forest
step
  .goto 1421,65.89,23.86
  .complete 443 -- Rot Hide Ichor
step
  .goto 1421,42.8,40.86
  .turnin 443 -- Rot Hide Ichor
  .accept 444 -- Rot Hide Origins
  .goto 1421,44.52,43.02
  .turnin 92401 -- A Frightened Request
step
  .goto 1421,59.24,65.64
  .complete 479 -- Ambermill Investigations
step
  .goto 1421,58.12,69.77
  .level 20
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
  .goto 1421,46.08,85.63
  .complete 98299 -- Stop the Spread
step
  .goto 1421,46.5,74.39
  .accept 452 -- Pyrewood Ambush
  .complete 452,1 -- Pyrewood Ambush
  .note Pyrewood Ambush: event: the quest finishes when something happens here (an ambush, a ritual); read the quest log
  .turnin 452 -- Pyrewood Ambush
step
  .goto 1421,43.98,40.93
  .turnin 479 -- Ambermill Investigations
  .turnin 516 -- Beren's Peril
  .accept 480 -- The Weaver
  .goto 1421,44.2,39.81
  .turnin 98299 -- Stop the Spread
  .level 21 -- reach it first: kill or grind on the way
  .note Grind about 1,700 experience before you go on: about 12 kills of creatures near your level (an estimate)
step
  .goto 1421,63.4,64.27
  .complete 480 -- The Weaver
step
  .goto 1421,43.98,40.93
  .turnin 480 -- The Weaver
step
  .goto 1421,53.0,26.69
  .complete 421 -- Prove Your Worth
  .complete 91920 -- Wild Eyes
step
  .goto 1421,46.4,25.62
  .complete 429 -- Wild Hearts
step
  .goto 1421,44.2,39.81
  .turnin 421 -- Prove Your Worth
  .accept 422 -- Arugal's Folly
  .goto 1421,42.8,40.86
  .turnin 429 -- Wild Hearts
  .turnin 91920 -- Wild Eyes
  .accept 430 -- Return to Quinn
step
  .goto 1421,52.83,28.58
  .complete 422 -- Arugal's Folly
step
  .goto 1421,44.2,39.81
  .turnin 422 -- Arugal's Folly
  .accept 423 -- Arugal's Folly
step
  .goto 1421,59.43,42.4
  .complete 423 -- Arugal's Folly
step
  .goto 1421,44.2,39.81
  .turnin 423 -- Arugal's Folly
  .accept 424 -- Arugal's Folly
step
  .goto 1421,58.58,44.86
  .complete 424 -- Arugal's Folly
step
  .goto 1421,44.2,39.81
  .turnin 424 -- Arugal's Folly
step
  .goto 1421,53.43,12.59
  .turnin 430 -- Return to Quinn
step
  .goto 1421,45.62,42.6 >> Go to the flight master
  .fly Undercity
step
  .goto 1458,53.74,54.46
  .accept 1013 -- The Book of Ur
  .note The Book of Ur: dungeon quest: needs a group
  .optional 1013 -- dungeon quest: The Book of Ur
  .goto 1458,62.01,42.75
  .turnin 441 -- Raleigh and the Undercity
step
  .goto 1458,84.07,17.45
  .turnin 444 -- Rot Hide Origins
step
  .todo "Walk from Undercity to Hillsbrad Foothills: the guide has no waypoints for this yet, so find your own way. This step is done when you arrive in Hillsbrad Foothills."
  .zone 1424 >> Go to Hillsbrad Foothills
]]
)
