-- PLANNED: the thorough alt 1 route for Tauren Druid (HARDCORE): tools/route_planner.py tauren --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"tauren-druid-02-thunder-bluff",
	[[
#chapter 11-12 Thunder Bluff
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
  .todo "Walk from Thunder Bluff to Moonglade: the guide has no waypoints for this yet, so find your own way. This step is done when you arrive in Moonglade."
  .zone 1450 >> Go to Moonglade
step
  .goto 1450,56.21,30.64
  .turnin 5922 .class DRUID -- Moonglade
  .accept 5930 .class DRUID -- Great Bear Spirit
  .todo "Great Bear Spirit: the pack has no objective for it; read what it asks in the quest log"
  .note VERIFY(beta): the real quest has you meet the Great Bear Spirit in Moonglade (west of Nighthaven); the pack has no objective for it.
  .turnin 5930 .class DRUID -- Great Bear Spirit
  .accept 5932 .class DRUID -- Back to Thunder Bluff
step
  .todo "Walk from Moonglade to Mulgore: the guide has no waypoints for this yet, so find your own way. This step is done when you arrive in Mulgore."
  .zone 1412 >> Go to Mulgore
step
  .goto 1412,40.53,19.08
  .complete 744 -- Preparation for Ceremony
step
  .todo "Walk from Mulgore to Thunder Bluff: the guide has no waypoints for this yet, so find your own way. This step is done when you arrive in Thunder Bluff."
  .zone 1456 >> Go to Thunder Bluff
step
  .goto 1456,37.75,59.57
  .turnin 744 -- Preparation for Ceremony
  .goto 1456,38.0,55.9
  .turnin 97485 -- Traditions of the Bluff
step
  .goto 1456,76.48,27.22
  .turnin 5932 .class DRUID -- Back to Thunder Bluff
  .accept 6002 .class DRUID -- Body and Heart
  .todo "Body and Heart: the pack has no objective for it; read what it asks in the quest log"
  .note Summons Lunaclaw: be fully buffed and healed first; Entangling Roots buys distance for healing. Come back later if unsure.
  .turnin 6002 .class DRUID -- Body and Heart
step
  .goto 1456,78.62,28.56
  .turnin 98435 -- Thunderhorn's Report
step
  .todo "Walk from Thunder Bluff to The Barrens: the guide has no waypoints for this yet, so find your own way. This step is done when you arrive in The Barrens."
  .zone 1413 >> Go to The Barrens
]]
)
