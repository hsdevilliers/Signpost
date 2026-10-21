-- PLANNED: the thorough alt 4 route for Skyborne Druid (HARDCORE): tools/route_planner.py windshaper --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"windshaper-druid-15-silverpine-forest",
	[[
#chapter 24-25 Silverpine Forest
step
  .goto 1421,63.5,63.2
  .complete 78127 -- The Dalaran Digest
step
  .todo "travel from Silverpine Forest to Hillsbrad Foothills: the travel graph has no route yet"
  .zone 1424 >> Go to Hillsbrad Foothills
step
  .goto 1424,61.44,19.06
  .accept 496 -- Elixir of Suffering
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
  .goto 1424,66.47,34.25
  .complete 496,1 -- Elixir of Suffering
step
  .goto 1424,61.44,19.06
  .turnin 496 -- Elixir of Suffering
  .accept 499 -- Elixir of Suffering
  .goto 1424,61.55,19.14
  .turnin 499 -- Elixir of Suffering
]]
)
