-- PLANNED: the thorough route for Tauren Druid (HARDCORE): tools/route_planner.py tauren --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"tauren-druid-23-hillsbrad-foothills",
	[[
#chapter 28-29 Hillsbrad Foothills
step
  .goto 1424,63.58,53.11
  .turnin 98094 -- Scout Support
step
  .goto 1424,66.09,57.04
  .complete 496,2 -- Elixir of Suffering
step
  .goto 1424,39.3,37.83
  .complete 501 -- Elixir of Pain
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
  .goto 1424,32.66,35.32
  .turnin 502 -- Elixir of Pain
step
  .goto 1424,30.84,45.44
  .complete 528 -- Battle of Hillsbrad
step
  .goto 1424,46.55,47.22
  .complete 496,1 -- Elixir of Suffering
step
  .goto 1424,64.56,61.25
  .complete 509 -- Elixir of Agony
step
  .goto 1424,62.33,20.45
  .turnin 528 -- Battle of Hillsbrad
  .accept 529 -- Battle of Hillsbrad
  .goto 1424,61.44,19.06
  .turnin 496 -- Elixir of Suffering
  .turnin 509 -- Elixir of Agony
  .accept 499 -- Elixir of Suffering
  .accept 513 -- Elixir of Agony
  .goto 1424,61.55,19.14
  .turnin 499 -- Elixir of Suffering
step
  .goto 1424,31.96,45.83
  .complete 529 -- Battle of Hillsbrad
step
  .goto 1424,62.33,20.45
  .turnin 529 -- Battle of Hillsbrad
  .accept 532 -- Battle of Hillsbrad
step
  .goto 1424,29.67,41.64
  .complete 532 -- Battle of Hillsbrad
step
  .goto 1424,62.33,20.45
  .turnin 532 -- Battle of Hillsbrad
  .accept 539 -- Battle of Hillsbrad
step
  .level 29 -- reach it first: kill or grind on the way
step
  .goto 1424,31.23,53.1
  .complete 539 -- Battle of Hillsbrad
step
  .goto 1424,62.33,20.45
  .turnin 539 -- Battle of Hillsbrad
step
  .goto 1424,75.36,39.7
  .complete 549 -- WANTED: Syndicate Personnel
step
  .goto 1424,62.33,20.45
  .turnin 549 -- WANTED: Syndicate Personnel
step
  .todo "travel from Hillsbrad Foothills to Undercity: the travel graph has no route yet"
  .zone 1458 >> Go to Undercity
]]
)
