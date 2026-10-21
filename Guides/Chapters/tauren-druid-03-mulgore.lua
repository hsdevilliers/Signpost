-- PLANNED: the thorough route for Tauren Druid (HARDCORE): tools/route_planner.py tauren --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"tauren-druid-03-mulgore",
	[[
#chapter 11-12 Mulgore
step
  .goto 1412,37.19,64.62
  .complete 98430 -- The Longwalkers
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
  .goto 1456,60.3,51.68
  .turnin 98430 -- The Longwalkers
step
  .todo "travel from Thunder Bluff to The Barrens: the travel graph has no route yet"
  .zone 1413 >> Go to The Barrens
step
  .goto 1413,51.21,29.05
  .accept 6361 -- A Bundle of Hides
  .goto 1413,51.5,30.34
  .turnin 6361 -- A Bundle of Hides
  .accept 6362 -- Ride to Thunder Bluff
  .goto 1413,51.5,30.87
  .accept 871 -- Disrupt the Attacks
  .goto 1413,51.93,30.32
  .accept 869 -- Raptor Thieves
  .goto 1413,52.23,31.01
  .accept 844 -- Plainstrider Menace
  .goto 1413,52.26,31.93
  .accept 870 -- The Forgotten Pools
]]
)
