-- PLANNED: the thorough alt 3 route for Tauren Druid (HARDCORE): tools/route_planner.py tauren --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"tauren-druid-18-thunder-bluff",
	[[
#chapter 25-26 Thunder Bluff
step
  .goto 1456,54.97,51.41
  .accept 1195 -- The Sacred Flame
  .todo "The Sacred Flame: objective 1 has no position in the pack"
  .complete 1195,1 -- The Sacred Flame
  .turnin 1195 -- The Sacred Flame
step
  .goto 1456,54.14,47.05
  .accept 97538 -- Pigments for Paints
step
  .goto 1456,22.81,20.89
  .turnin 1067 -- Return to Thunder Bluff
  .accept 1086 -- The Flying Machine Airport
  .complete 1086,1 -- The Flying Machine Airport
  .note The Flying Machine Airport: HARDCORE event: enemies may come at you here; be healed and buffed first, and come back later if unsure
  .turnin 1086 -- The Flying Machine Airport
step
  .goto 1456,47.0,49.83 >> Go to the flight master
  .fly Sun Rock Retreat
]]
)
