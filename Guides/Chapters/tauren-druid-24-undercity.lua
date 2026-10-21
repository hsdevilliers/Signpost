-- PLANNED: the thorough route for Tauren Druid (HARDCORE): tools/route_planner.py tauren --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"tauren-druid-24-undercity",
	[[
#chapter 29-29 Undercity
step
  .goto 1458,48.82,69.28
  .turnin 513 -- Elixir of Agony
  .accept 515 -- Elixir of Agony
  .todo "Elixir of Agony: objective 1 has no position in the pack"
  .complete 515,1 -- Elixir of Agony
step
  .todo "travel from Undercity to Hillsbrad Foothills: the travel graph has no route yet"
  .zone 1424 >> Go to Hillsbrad Foothills
step
  .goto 1424,44.62,66.99
  .complete 515,3 -- Elixir of Agony
step
  .goto 1424,52.73,65.51
  .complete 515,2 -- Elixir of Agony
step
  .goto 1424,61.44,19.06
  .turnin 515 -- Elixir of Agony
  .accept 517 -- Elixir of Agony
step
  .goto 1424,71.62,80.15
  .complete 517 -- Elixir of Agony
step
  .goto 1424,61.44,19.06
  .turnin 517 -- Elixir of Agony
  .accept 524 -- Elixir of Agony
  .goto 1424,62.81,18.73
  .turnin 524 -- Elixir of Agony
step
  .todo "travel from Hillsbrad Foothills to Ashenvale: the travel graph has no route yet"
  .zone 1440 >> Go to Ashenvale
step
  .goto 1440,70.01,71.16
  .accept 6504 -- The Lost Pages
  .todo "The Lost Pages: objective 1 has no position in the pack"
  .complete 6504,1 -- The Lost Pages
  .todo "The Lost Pages: objective 2 has no position in the pack"
  .complete 6504,2 -- The Lost Pages
  .todo "The Lost Pages: objective 3 has no position in the pack"
  .complete 6504,3 -- The Lost Pages
  .turnin 6504 -- The Lost Pages
step
  .todo "border The Barrens/Ashenvale: no crossing coordinates yet (record them in game or in Borders.lua)"
  .zone 1413 >> Go into The Barrens
step
  .todo "border The Barrens/Thousand Needles: no crossing coordinates yet (record them in game or in Borders.lua)"
  .zone 1441 >> Go into Thousand Needles
step
  .goto 1441,53.95,41.49
  .accept 1150 -- Test of Endurance
  .todo "Test of Endurance: objective 1 has no position in the pack"
  .complete 1150,1 -- Test of Endurance
  .turnin 1150 -- Test of Endurance
step
  .goto 1441,78.14,77.12
  .accept 1105 -- Hardened Shells
  .goto 1441,80.18,75.88
  .accept 1176 -- Load Lightening
]]
)
