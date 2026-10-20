-- PLANNED: the thorough alt 5 route for Troll Hunter: tools/route_planner.py troll --preset all --install --force --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"troll-hunter-11-undercity",
	[[
#chapter 21-22 Undercity
step
  .goto 1458,48.82,69.28
  .turnin 451 -- A Recipe For Death
  .goto 1458,53.74,54.46
  .accept 1013 -- The Book of Ur
step
  .todo "travel from Undercity to Hillsbrad Foothills: the travel graph has no route yet"
  .zone 1424 >> Go to Hillsbrad Foothills
step
  .goto 1424,61.44,19.06
  .accept 496 -- Elixir of Suffering
  .level 21
  .accept 501 -- Elixir of Pain
  .goto 1424,62.33,20.45
  .accept 527 -- Battle of Hillsbrad
  .accept 98094 -- Scout Support
  .goto 1424,62.58,20.65
  .accept 549 -- WANTED: Syndicate Personnel
  .goto 1424,63.24,20.66
  .accept 498 -- The Rescue
step
  .goto 1424,63.58,53.11
  .turnin 98094 -- Scout Support
step
  .goto 1424,66.09,57.04
  .complete 496,2 -- Elixir of Suffering
step
  .goto 1424,75.33,41.5
  .complete 498,1 -- The Rescue
  .complete 549 -- WANTED: Syndicate Personnel
]]
)
