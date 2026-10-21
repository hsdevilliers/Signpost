-- PLANNED: the thorough route for Skyborne Druid (HARDCORE): tools/route_planner.py windshaper --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"windshaper-druid-07-hillsbrad-foothills",
	[[
#chapter 23-24 Hillsbrad Foothills
step
  .goto 1424,61.44,19.06
  .accept 496 -- Elixir of Suffering
  .accept 501 -- Elixir of Pain
  .goto 1424,62.33,20.45
  .accept 527 -- Battle of Hillsbrad
  .goto 1424,62.58,20.65
  .accept 549 -- WANTED: Syndicate Personnel
  .goto 1424,63.24,20.66
  .accept 498 -- The Rescue
step
  .goto 1424,54.68,31.22
  .complete 501 -- Elixir of Pain
  .complete 496,1 -- Elixir of Suffering
step
  .goto 1424,75.02,40.67
  .complete 549 -- WANTED: Syndicate Personnel
  .complete 498,1 -- The Rescue
step
  .goto 1424,62.33,20.45
  .turnin 549 -- WANTED: Syndicate Personnel
  .goto 1424,61.44,19.06
  .turnin 501 -- Elixir of Pain
  .accept 502 -- Elixir of Pain
step
  .goto 1424,67.54,10.22
  .complete 496,2 -- Elixir of Suffering
step
  .goto 1424,61.44,19.06
  .turnin 496 -- Elixir of Suffering
  .accept 499 -- Elixir of Suffering
  .goto 1424,61.55,19.14
  .turnin 499 -- Elixir of Suffering
step
  .goto 1424,33.22,34.76
  .complete 527,3 -- Battle of Hillsbrad
step
  .goto 1424,32.66,35.32
  .turnin 502 -- Elixir of Pain
step
  .goto 1424,31.7,34.93
  .complete 527,1 -- Battle of Hillsbrad
  .complete 527,2 -- Battle of Hillsbrad
  .complete 527,4 -- Battle of Hillsbrad
step
  .goto 1424,62.33,20.45
  .turnin 527 -- Battle of Hillsbrad
  .level 24 -- reach it first: kill or grind on the way
  .note Grind about 1,900 experience before you go on: about 12 kills of creatures near your level (an estimate)
step
  .goto 1424,62.33,20.45
  .accept 528 -- Battle of Hillsbrad
  .accept 98094 -- Scout Support
step
  .goto 1424,62.11,19.7
  .accept 546 -- Souvenirs of Death
  .todo "Souvenirs of Death: objective 1 has no position in the pack"
  .complete 546,1 -- Souvenirs of Death
  .turnin 546 -- Souvenirs of Death
step
  .goto 1424,79.79,39.65
  .complete 498,2 -- The Rescue
step
  .goto 1424,63.58,53.11
  .turnin 98094 -- Scout Support
step
  .goto 1424,63.24,20.66
  .turnin 498 -- The Rescue
step
  .goto 1424,34.76,46.11
  .complete 528 -- Battle of Hillsbrad
step
  .goto 1424,62.33,20.45
  .turnin 528 -- Battle of Hillsbrad
step
  .todo "Walk from Hillsbrad Foothills to Tirisfal Glades: the guide has no waypoints for this yet, so find your own way. This step is done when you arrive in Tirisfal Glades."
  .zone 1420 >> Go to Tirisfal Glades
step
  .goto 1420,61.26,50.84
  .turnin 440 -- The Engraved Ring
  .accept 441 -- Raleigh and the Undercity
step
  .todo "Walk from Tirisfal Glades to Undercity: the guide has no waypoints for this yet, so find your own way. This step is done when you arrive in Undercity."
  .zone 1458 >> Go to Undercity
step
  .goto 1458,62.01,42.75
  .turnin 441 -- Raleigh and the Undercity
step
  .todo "Get from Undercity to Ashenvale: they are on different continents, so you need a boat, a zeppelin or another ride, and the guide has no dock for it yet. This step is done when you arrive in Ashenvale."
  .zone 1440 >> Go to Ashenvale
]]
)
