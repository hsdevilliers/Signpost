-- PLANNED: the thorough route for Skyborne Druid (HARDCORE): tools/route_planner.py windshaper --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"windshaper-druid-06-silverpine-forest",
	[[
#chapter 21-23 Silverpine Forest
step
  .goto 1421,44.2,39.81
  .accept 98298 -- Arugal's Folly
  .accept 98299 -- Stop the Spread
  .goto 1421,43.98,40.93
  .accept 477 -- Border Crossings
  .accept 95981 -- Watching the Roads
  .accept 516 -- Beren's Peril
step
  .goto 1421,45.62,42.6 >> Go to the flight master
  .fp 1421,The Sepulcher
step
  .goto 1421,43.42,40.86
  .accept 437 -- The Dead Fields
  .todo "The Dead Fields: objective 1 has no position in the pack"
  .complete 437,1 -- The Dead Fields
  .turnin 437 -- The Dead Fields
  .accept 438 -- The Decrepit Ferry
step
  .goto 1421,43.4,41.2
  .complete 79096 -- Ataeric: On Arcane Curiosities
step
  .goto 1421,44.52,43.02
  .accept 92401 -- A Frightened Request
step
  .goto 1421,58.44,34.9
  .turnin 438 -- The Decrepit Ferry
  .accept 439 -- Rot Hide Clues
step
  .goto 1421,63.51,58.13
  .complete 95981 -- Watching the Roads
step
  .goto 1421,59.58,40.99
  .complete 98298 -- Arugal's Folly
step
  .goto 1421,43.98,40.93
  .turnin 95981 -- Watching the Roads
  .goto 1421,43.42,40.86
  .turnin 439 -- Rot Hide Clues
  .accept 440 -- The Engraved Ring
  .accept 443 -- Rot Hide Ichor
  .goto 1421,44.2,39.81
  .turnin 98298 -- Arugal's Folly
step
  .goto 1421,45.96,85.77
  .complete 98299 -- Stop the Spread
step
  .goto 1421,44.2,39.81
  .turnin 98299 -- Stop the Spread
step
  .goto 1421,49.89,60.33
  .turnin 477 -- Border Crossings
  .accept 478 -- Maps and Runes
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
step
  .goto 1421,66.67,33.01
  .complete 443 -- Rot Hide Ichor
step
  .goto 1421,45.62,42.6 >> Go to the flight master
  .fly Undercity
step
  .goto 1458,73.4,33.0
  .turnin 78127 -- The Dalaran Digest
  .turnin 79096 -- Ataeric: On Arcane Curiosities
step
  .goto 1458,67.69,13.55
  .complete 92401 -- A Frightened Request
step
  .goto 1458,63.25,48.56 >> Go to the flight master
  .fly The Sepulcher
step
  .goto 1421,43.98,40.93
  .turnin 478 -- Maps and Runes
  .turnin 516 -- Beren's Peril
  .accept 481 -- Dalar's Analysis
  .goto 1421,42.8,40.86
  .turnin 443 -- Rot Hide Ichor
  .goto 1421,44.52,43.02
  .turnin 92401 -- A Frightened Request
  .goto 1421,44.2,39.81
  .turnin 481 -- Dalar's Analysis
  .accept 482 -- Dalaran's Intentions
  .turnin 482 -- Dalaran's Intentions
  .accept 479 -- Ambermill Investigations
step
  .goto 1421,58.65,63.2
  .complete 479 -- Ambermill Investigations
step
  .goto 1421,43.98,40.93
  .turnin 479 -- Ambermill Investigations
  .accept 480 -- The Weaver
  .note Archmage Ataeric (near 63,64) is the named boss of Ambermill Keep, where the Dalaran wizards of the earlier quests stand together, and the data does not rank him: do this one at full health with the keep's wizards pulled one at a time, or leave it.
  .level 23 -- reach it first: kill or grind on the way
  .note Grind about 2,600 experience before you go on: about 17 kills of creatures near your level (an estimate)
step
  .goto 1421,63.4,64.27
  .complete 480 -- The Weaver
step
  .goto 1421,43.98,40.93
  .turnin 480 -- The Weaver
step
  .todo "Walk from Silverpine Forest to Hillsbrad Foothills: the guide has no waypoints for this yet, so find your own way. This step is done when you arrive in Hillsbrad Foothills."
  .zone 1424 >> Go to Hillsbrad Foothills
]]
)
