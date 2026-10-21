-- PLANNED: the thorough alt 3 route for Tauren Druid (HARDCORE): tools/route_planner.py tauren --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"tauren-druid-16-hillsbrad-foothills",
	[[
#chapter 23-25 Hillsbrad Foothills
step
  .goto 1424,61.44,19.06
  .turnin 1065 -- Journey to Tarren Mill
  .accept 1066 -- Blood of Innocents
  .accept 496 -- Elixir of Suffering
  .accept 501 -- Elixir of Pain
  .goto 1424,62.33,20.45
  .accept 527 -- Battle of Hillsbrad
  .goto 1424,62.58,20.65
  .accept 549 -- WANTED: Syndicate Personnel
  .goto 1424,63.24,20.66
  .accept 498 -- The Rescue
step
  .goto 1424,75.36,39.7
  .complete 549 -- WANTED: Syndicate Personnel
  .complete 498,1 -- The Rescue
  .complete 1066 -- Blood of Innocents
step
  .goto 1424,61.19,55.39
  .complete 496,2 -- Elixir of Suffering
  .complete 501 -- Elixir of Pain
step
  .goto 1424,62.33,20.45
  .turnin 549 -- WANTED: Syndicate Personnel
  .accept 98094 -- Scout Support
  .goto 1424,61.44,19.06
  .turnin 1066 -- Blood of Innocents
  .turnin 501 -- Elixir of Pain
  .accept 1067 -- Return to Thunder Bluff
  .accept 502 -- Elixir of Pain
step
  .goto 1424,63.58,53.11
  .turnin 98094 -- Scout Support
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
  .accept 528 -- Battle of Hillsbrad
step
  .goto 1424,62.11,19.7
  .accept 546 -- Souvenirs of Death
  .todo "Souvenirs of Death: objective 1 has no position in the pack"
  .complete 546,1 -- Souvenirs of Death
  .turnin 546 -- Souvenirs of Death
step
  .goto 1424,40.11,36.77
  .complete 496,1 -- Elixir of Suffering
step
  .goto 1424,34.76,46.11
  .complete 528 -- Battle of Hillsbrad
step
  .goto 1424,62.33,20.45
  .turnin 528 -- Battle of Hillsbrad
  .goto 1424,61.44,19.06
  .turnin 496 -- Elixir of Suffering
  .accept 499 -- Elixir of Suffering
  .goto 1424,61.55,19.14
  .turnin 499 -- Elixir of Suffering
  .level 25 -- reach it first: kill or grind on the way
  .note Grind about 4,600 experience before you go on: about 28 kills of creatures near your level (an estimate)
step
  .goto 1424,62.33,20.45
  .accept 529 -- Battle of Hillsbrad
step
  .goto 1424,79.79,39.65
  .complete 498,2 -- The Rescue
step
  .goto 1424,63.24,20.66
  .turnin 498 -- The Rescue
step
  .goto 1424,31.96,45.83
  .complete 529 -- Battle of Hillsbrad
step
  .goto 1424,62.33,20.45
  .turnin 529 -- Battle of Hillsbrad
  .accept 532 -- Battle of Hillsbrad
step
  .goto 1424,32.38,46.42
  .complete 532 -- Battle of Hillsbrad
step
  .goto 1424,62.33,20.45
  .turnin 532 -- Battle of Hillsbrad
step
  .todo "Walk from Hillsbrad Foothills to Silverpine Forest: the guide has no waypoints for this yet, so find your own way. This step is done when you arrive in Silverpine Forest."
  .zone 1421 >> Go to Silverpine Forest
step
  .goto 1421,63.5,63.2
  .complete 78127 -- The Dalaran Digest
step
  .todo "Walk from Silverpine Forest to Undercity: the guide has no waypoints for this yet, so find your own way. This step is done when you arrive in Undercity."
  .zone 1458 >> Go to Undercity
step
  .goto 1458,73.4,33.0
  .turnin 78127 -- The Dalaran Digest
step
  .todo "Get from Undercity to The Barrens: they are on different continents, so you need a boat, a zeppelin or another ride, and the guide has no dock for it yet. This step is done when you arrive in The Barrens."
  .zone 1413 >> Go to The Barrens
]]
)
