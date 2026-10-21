-- PLANNED: the thorough alt 4 route for Skyborne Druid (HARDCORE): tools/route_planner.py windshaper --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"windshaper-druid-03-thunder-bluff",
	[[
#chapter 12-13 Thunder Bluff
step
  .goto 1456,39.44,65.82
  .accept 76156 -- Stalk With The Earthmother
  .goto 1456,37.75,59.57
  .accept 744 -- Preparation for Ceremony
step
  .goto 1456,38.0,55.9
  .accept 97485 -- Traditions of the Bluff
  .todo "Traditions of the Bluff: objective 2 has no position in the pack"
  .complete 97485,2 -- Traditions of the Bluff
step
  .goto 1456,53.02,87.84
  .complete 97485,1 -- Traditions of the Bluff
step
  .goto 1456,76.48,27.22
  .turnin 94911 .class DRUID -- Child of Nature
  .accept 94913 .class DRUID -- Moonglade
step
  .todo "travel from Thunder Bluff to Mulgore: the travel graph has no route yet"
  .zone 1412 >> Go to Mulgore
step
  .goto 1412,40.53,19.08
  .complete 744 -- Preparation for Ceremony
step
  .goto 1412,44.09,23.54
  .complete 861 -- The Hunter's Way
step
  .goto 1412,57.96,30.92
  .complete 833 -- A Sacred Burial
step
  .goto 1412,56.98,34.55
  .turnin 833 -- A Sacred Burial
]]
)
