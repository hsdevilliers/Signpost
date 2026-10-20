-- PLANNED: the thorough alt 1 route for Troll Hunter: tools/route_planner.py troll --preset all --install --force --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"troll-hunter-11-hillsbrad-foothills",
	[[
#chapter 20-22 Hillsbrad Foothills
step
  .goto 1424,62.33,20.45
  .turnin 494 -- Time To Strike
  .accept 527 -- Battle of Hillsbrad
  .accept 98094 -- Scout Support
  .goto 1424,62.58,20.65
  .accept 549 -- WANTED: Syndicate Personnel
  .goto 1424,63.24,20.66
  .accept 498 -- The Rescue
  .goto 1424,61.44,19.06
  .accept 496 -- Elixir of Suffering
step
  .goto 1424,66.9,28.87
  .complete 496,1 -- Elixir of Suffering
step
  .goto 1424,63.58,53.11
  .turnin 98094 -- Scout Support
step
  .goto 1424,66.09,57.04
  .complete 496,2 -- Elixir of Suffering
step
  .goto 1424,75.33,41.5
  .complete 498 -- The Rescue
  .complete 549 -- WANTED: Syndicate Personnel
step
  .goto 1424,63.24,20.66
  .turnin 498 -- The Rescue
  .goto 1424,62.33,20.45
  .turnin 549 -- WANTED: Syndicate Personnel
  .goto 1424,61.44,19.06
  .turnin 496 -- Elixir of Suffering
  .accept 499 -- Elixir of Suffering
  .level 21
  .accept 501 -- Elixir of Pain
  .goto 1424,61.55,19.14
  .turnin 499 -- Elixir of Suffering
step
  .goto 1424,54.68,31.22
  .complete 501 -- Elixir of Pain
step
  .goto 1424,36.73,39.44
  .complete 527 -- Battle of Hillsbrad
step
  .goto 1424,62.33,20.45
  .turnin 527 -- Battle of Hillsbrad
  .accept 528 -- Battle of Hillsbrad
  .goto 1424,62.11,19.7
  .accept 546 -- Souvenirs of Death
  .goto 1424,61.44,19.06
  .turnin 501 -- Elixir of Pain
  .accept 502 -- Elixir of Pain
step
  .goto 1424,32.66,35.32
  .turnin 502 -- Elixir of Pain
step
  .level 22 -- reach it first: kill or grind on the way
step
  .goto 1424,30.84,45.44
  .complete 528 -- Battle of Hillsbrad
step
  .goto 1424,62.33,20.45
  .turnin 528 -- Battle of Hillsbrad
step
  .goto 1424,62.11,19.7
  .todo "Souvenirs of Death: objective 1 has no position in the pack"
  .complete 546,1 -- Souvenirs of Death
  .turnin 546 -- Souvenirs of Death
step
  .todo "travel from Hillsbrad Foothills to Silverpine Forest: the travel graph has no route yet"
  .zone 1421 >> Go to Silverpine Forest
]]
)
