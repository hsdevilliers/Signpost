-- PLANNED: the thorough alt 4 route for Tauren Druid (HARDCORE): tools/route_planner.py tauren --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"tauren-druid-02-thunder-bluff",
	[[
#chapter 10-11 Thunder Bluff
step
  .goto 1456,38.0,55.9
  .accept 97485 -- Traditions of the Bluff
  .todo "Traditions of the Bluff: objective 2 has no position in the pack"
  .complete 97485,2 -- Traditions of the Bluff
step
  .goto 1456,37.75,59.57
  .accept 744 -- Preparation for Ceremony
  .goto 1456,39.44,65.82
  .accept 76156 -- Stalk With The Earthmother
step
  .goto 1456,76.48,27.22
  .turnin 5926 .class DRUID -- Heeding the Call
  .accept 5922 .class DRUID -- Moonglade
  .goto 1456,78.62,28.56
  .turnin 98435 -- Thunderhorn's Report
step
  .goto 1456,61.54,80.92
  .turnin 861 -- The Hunter's Way
step
  .goto 1456,53.02,87.84
  .complete 97485,1 -- Traditions of the Bluff
step
  .goto 1456,38.0,55.9
  .turnin 97485 -- Traditions of the Bluff
step
  .todo "travel from Thunder Bluff to Mulgore: the travel graph has no route yet"
  .zone 1412 >> Go to Mulgore
step
  .goto 1412,34.31,43.29
  .turnin 772 -- Rite of Vision
  .accept 773 -- Rite of Wisdom
step
  .goto 1412,32.99,35.29
  .complete 744,2 -- Preparation for Ceremony
]]
)
