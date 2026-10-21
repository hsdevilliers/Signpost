-- PLANNED: the thorough alt 4 route for Tauren Druid (HARDCORE): tools/route_planner.py tauren --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"tauren-druid-03-mulgore",
	[[
#chapter 11-12 Mulgore
step
  .goto 1412,32.37,34.65
  .complete 744,1 -- Preparation for Ceremony
step
  .goto 1412,58.31,30.7
  .turnin 773 -- Rite of Wisdom
  .accept 775 -- Journey into Thunder Bluff
step
  .goto 1412,61.85,45.65
  .complete 764,1 -- The Venture Co.
  .complete 76156 -- Stalk With The Earthmother
step
  .goto 1412,54.76,64.27
  .turnin 764 -- The Venture Co.
step
  .todo "travel from Mulgore to Moonglade: the travel graph has no route yet"
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
  .todo "travel from Moonglade to Thunder Bluff: the travel graph has no route yet"
  .zone 1456 >> Go to Thunder Bluff
step
  .goto 1456,76.48,27.22
  .turnin 5932 .class DRUID -- Back to Thunder Bluff
  .accept 6002 .class DRUID -- Body and Heart
  .todo "Body and Heart: the pack has no objective for it; read what it asks in the quest log"
  .note Summons Lunaclaw: be fully buffed and healed first; Entangling Roots buys distance for healing. Come back later if unsure.
  .turnin 6002 .class DRUID -- Body and Heart
step
  .goto 1456,39.44,65.82
  .turnin 76156 -- Stalk With The Earthmother
  .accept 76160 -- Stalk With The Earthmother
  .todo "Stalk With The Earthmother: objective 1 has no position in the pack"
  .complete 76160,1 -- Stalk With The Earthmother
  .turnin 76160 -- Stalk With The Earthmother
step
  .goto 1456,37.75,59.57
  .turnin 744 -- Preparation for Ceremony
  .goto 1456,60.3,51.68
  .turnin 775 -- Journey into Thunder Bluff
step
  .todo "travel from Thunder Bluff to The Barrens: the travel graph has no route yet"
  .zone 1413 >> Go to The Barrens
]]
)
