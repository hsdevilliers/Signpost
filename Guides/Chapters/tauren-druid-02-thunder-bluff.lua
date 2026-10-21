-- PLANNED: the thorough route for Tauren Druid (HARDCORE): tools/route_planner.py tauren --preset all --install --quiet (docs/PLANNER.md)
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
step
  .goto 1456,53.02,87.84
  .complete 97485,1 -- Traditions of the Bluff
step
  .goto 1456,76.48,27.22
  .turnin 5926 .class DRUID -- Heeding the Call
  .accept 5922 .class DRUID -- Moonglade
  .note Moonglade is a long walk from here. VERIFY(beta): Classic's druid learns Teleport: Moonglade at level 10, and this guide does not assume that Forever does; the way back (hearthstone, or a flight master at Nighthaven) is unconfirmed too.
  .goto 1456,78.62,28.56
  .turnin 98435 -- Thunderhorn's Report
step
  .todo "travel from Thunder Bluff to Mulgore: the travel graph has no route yet"
  .zone 1412 >> Go to Mulgore
step
  .goto 1412,43.26,27.7
  .complete 861 -- The Hunter's Way
step
  .goto 1412,40.53,19.08
  .complete 744 -- Preparation for Ceremony
step
  .todo "travel from Mulgore to Thunder Bluff: the travel graph has no route yet"
  .zone 1456 >> Go to Thunder Bluff
step
  .goto 1456,37.75,59.57
  .turnin 744 -- Preparation for Ceremony
  .goto 1456,38.0,55.9
  .turnin 97485 -- Traditions of the Bluff
step
  .goto 1456,61.54,80.92
  .turnin 861 -- The Hunter's Way
step
  .todo "travel from Thunder Bluff to Mulgore: the travel graph has no route yet"
  .zone 1412 >> Go to Mulgore
]]
)
