-- PLANNED: the thorough alt 3 route for Tauren Druid (HARDCORE): tools/route_planner.py tauren --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"tauren-druid-03-mulgore",
	[[
#chapter 11-11 Mulgore
step
  .goto 1412,32.37,34.65
  .complete 744 -- Preparation for Ceremony
step
  .goto 1412,33.99,48.29
  .complete 743 -- Dangers of the Windfury
step
  .goto 1412,46.54,64.94
  .turnin 743 -- Dangers of the Windfury
step
  .goto 1412,58.01,52.88
  .complete 764,1 -- The Venture Co.
  .complete 76156 -- Stalk With The Earthmother
step
  .goto 1412,54.76,64.27
  .turnin 764 -- The Venture Co.
step
  .goto 1412,52.06,77.39
  .complete 780 -- The Battleboars
step
  .goto 1412,44.47,77.5
  .turnin 780 -- The Battleboars
step
  .goto 1412,37.19,64.62
  .complete 98430 -- The Longwalkers
step
  .todo "Go to Moonglade: cast Teleport: Moonglade if you have it (VERIFY(beta): where a druid learns it), else the way is not in the data. This step is done when you arrive in Moonglade."
  .note Do not walk it: from Classic memory (not confirmed in Forever) the road overland runs through Felwood or Winterspring, zones for levels 48 and up, so it is not safe at your level.
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
  .todo "Return from Moonglade to Thunder Bluff: use your hearthstone or a flight path if you have one (VERIFY(beta): the way back is not in the data). This step is done when you arrive in Thunder Bluff."
  .note Do not walk it: from Classic memory (not confirmed in Forever) the road overland runs through Felwood or Winterspring, zones for levels 48 and up, so it is not safe at your level.
  .zone 1456 >> Go to Thunder Bluff
]]
)
