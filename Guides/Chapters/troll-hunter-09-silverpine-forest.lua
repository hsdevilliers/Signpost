-- PLANNED: the thorough alt 4 route for Troll Hunter: tools/route_planner.py troll --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"troll-hunter-09-silverpine-forest",
	[[
#chapter 18-19 Silverpine Forest
step
  .goto 1421,65.79,30.42
  .complete 443 -- Rot Hide Ichor
step
  .goto 1421,65.8,50.67
  .complete 95981 -- Watching the Roads
step
  .goto 1421,43.98,40.93
  .turnin 479 -- Ambermill Investigations
  .turnin 95981 -- Watching the Roads
  .accept 480 -- The Weaver
  .goto 1421,42.8,40.86
  .turnin 443 -- Rot Hide Ichor
  .accept 444 -- Rot Hide Origins
step
  .goto 1421,58.06,69.89
  .complete 516 -- Beren's Peril
step
  .goto 1421,45.62,42.6 >> Go to the flight master
  .fly Undercity
]]
)
