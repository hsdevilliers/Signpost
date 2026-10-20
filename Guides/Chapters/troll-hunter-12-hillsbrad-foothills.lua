-- PLANNED: the thorough alt 5 route for Troll Hunter: tools/route_planner.py troll --preset all --install --force --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"troll-hunter-12-hillsbrad-foothills",
	[[
#chapter 22-23 Hillsbrad Foothills
step
  .goto 1424,79.79,39.65
  .complete 498,2 -- The Rescue
  .complete 496,1 -- Elixir of Suffering
step
  .goto 1424,63.24,20.66
  .turnin 498 -- The Rescue
  .goto 1424,62.33,20.45
  .turnin 549 -- WANTED: Syndicate Personnel
  .goto 1424,61.44,19.06
  .turnin 496 -- Elixir of Suffering
  .accept 499 -- Elixir of Suffering
  .goto 1424,61.55,19.14
  .turnin 499 -- Elixir of Suffering
step
  .goto 1424,54.68,31.22
  .complete 501 -- Elixir of Pain
step
  .goto 1424,31.4,38.59
  .complete 527 -- Battle of Hillsbrad
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
  .goto 1424,61.44,19.06
  .turnin 501 -- Elixir of Pain
  .accept 502 -- Elixir of Pain
step
  .goto 1424,34.76,46.11
  .complete 528 -- Battle of Hillsbrad
step
  .goto 1424,62.33,20.45
  .turnin 528 -- Battle of Hillsbrad
  .accept 529 -- Battle of Hillsbrad
step
  .goto 1424,31.96,45.83
  .complete 529 -- Battle of Hillsbrad
step
  .goto 1424,62.33,20.45
  .turnin 529 -- Battle of Hillsbrad
  .accept 532 -- Battle of Hillsbrad
step
  .goto 1424,32.66,35.32
  .turnin 502 -- Elixir of Pain
step
  .goto 1424,29.67,41.64
  .complete 532 -- Battle of Hillsbrad
step
  .goto 1424,62.33,20.45
  .turnin 532 -- Battle of Hillsbrad
step
  .todo "travel from Hillsbrad Foothills to Tirisfal Glades: the travel graph has no route yet"
  .zone 1420 >> Go to Tirisfal Glades
]]
)
