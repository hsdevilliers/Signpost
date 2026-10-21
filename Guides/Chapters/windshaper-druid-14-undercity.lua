-- PLANNED: the thorough alt 5 route for Skyborne Druid (HARDCORE): tools/route_planner.py windshaper --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"windshaper-druid-14-undercity",
	[[
#chapter 23-24 Undercity
step
  .goto 1458,73.4,33.0
  .turnin 78127 -- The Dalaran Digest
  .turnin 79096 -- Ataeric: On Arcane Curiosities
step
  .goto 1458,67.69,13.55
  .complete 92401 -- A Frightened Request
step
  .todo "travel from Undercity to Tirisfal Glades: the travel graph has no route yet"
  .zone 1420 >> Go to Tirisfal Glades
step
  .goto 1420,65.25,60.2
  .accept 92422 -- The Wrath of Rath'mael
  .todo "The Wrath of Rath'mael: objective 1 has no position in the pack"
  .complete 92422,1 -- The Wrath of Rath'mael
  .turnin 92422 -- The Wrath of Rath'mael
step
  .todo "travel from Tirisfal Glades to Silverpine Forest: the travel graph has no route yet"
  .zone 1421 >> Go to Silverpine Forest
step
  .goto 1421,43.98,40.93
  .turnin 479 -- Ambermill Investigations
  .accept 480 -- The Weaver
  .goto 1421,44.52,43.02
  .turnin 92401 -- A Frightened Request
step
  .goto 1421,63.4,64.27
  .complete 480 -- The Weaver
step
  .goto 1421,59.58,40.99
  .complete 98298 -- Arugal's Folly
step
  .goto 1421,66.67,33.01
  .complete 443 -- Rot Hide Ichor
step
  .goto 1421,44.2,39.81
  .turnin 98298 -- Arugal's Folly
  .goto 1421,43.98,40.93
  .turnin 480 -- The Weaver
  .goto 1421,42.8,40.86
  .turnin 443 -- Rot Hide Ichor
step
  .todo "travel from Silverpine Forest to Ashenvale: the travel graph has no route yet"
  .zone 1440 >> Go to Ashenvale
]]
)
