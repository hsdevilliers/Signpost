-- PLANNED: the thorough alt 3 route for Tauren Druid (HARDCORE): tools/route_planner.py tauren --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"tauren-druid-04-thunder-bluff",
	[[
#chapter 11-12 Thunder Bluff
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
  .turnin 98430 -- The Longwalkers
step
  .todo "Walk from Thunder Bluff to The Barrens: the guide has no waypoints for this yet, so find your own way. This step is done when you arrive in The Barrens."
  .zone 1413 >> Go to The Barrens
]]
)
