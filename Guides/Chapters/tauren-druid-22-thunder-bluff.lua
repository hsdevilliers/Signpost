-- PLANNED: the thorough route for Tauren Druid (HARDCORE): tools/route_planner.py tauren --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"tauren-druid-22-thunder-bluff",
	[[
#chapter 27-28 Thunder Bluff
step
  .goto 1456,54.97,51.41
  .accept 1195 -- The Sacred Flame
  .todo "The Sacred Flame: objective 1 has no position in the pack"
  .complete 1195,1 -- The Sacred Flame
  .turnin 1195 -- The Sacred Flame
step
  .goto 1456,54.14,47.05
  .accept 97538 -- Pigments for Paints
step
  .todo "travel from Thunder Bluff to Stonetalon Mountains: the travel graph has no route yet"
  .zone 1442 >> Go to Stonetalon Mountains
step
  .goto 1442,58.99,62.6
  .turnin 1095 -- Further Instructions
  .accept 1096 -- Gerenzo Wrenchwhistle
step
  .goto 1442,64.49,40.25
  .complete 1096 -- Gerenzo Wrenchwhistle
step
  .goto 1442,47.5,41.0
  .complete 97538 -- Pigments for Paints
step
  .goto 1442,58.99,62.6
  .turnin 1096 -- Gerenzo Wrenchwhistle
step
  .todo "travel from Stonetalon Mountains to Thunder Bluff: the travel graph has no route yet"
  .zone 1456 >> Go to Thunder Bluff
step
  .level 28 -- reach it first: kill or grind on the way
step
  .goto 1456,54.14,47.05
  .turnin 97538 -- Pigments for Paints
step
  .todo "travel from Thunder Bluff to Undercity: the travel graph has no route yet"
  .zone 1458 >> Go to Undercity
step
  .goto 1458,53.74,54.46
  .accept 1013 -- The Book of Ur
  .todo "The Book of Ur: objective 1 has no position in the pack"
  .complete 1013,1 -- The Book of Ur
  .turnin 1013 -- The Book of Ur
step
  .todo "travel from Undercity to Hillsbrad Foothills: the travel graph has no route yet"
  .zone 1424 >> Go to Hillsbrad Foothills
step
  .goto 1424,61.44,19.06
  .accept 496 -- Elixir of Suffering
  .accept 501 -- Elixir of Pain
  .accept 509 -- Elixir of Agony
  .goto 1424,62.33,20.45
  .accept 527 -- Battle of Hillsbrad
  .accept 98094 -- Scout Support
  .goto 1424,62.58,20.65
  .accept 549 -- WANTED: Syndicate Personnel
]]
)
