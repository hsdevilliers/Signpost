-- PLANNED: the thorough alt 1 route for Troll Hunter: tools/route_planner.py troll --preset all --install --force --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"troll-hunter-09-silverpine-forest",
	[[
#chapter 18-19 Silverpine Forest
step
  .goto 1421,58.06,69.89
  .complete 516 -- Beren's Peril
step
  .goto 1421,43.98,40.93
  .turnin 95981 -- Watching the Roads
  .turnin 516 -- Beren's Peril
step
  .goto 1421,45.96,85.77
  .complete 98299 -- Stop the Spread
step
  .goto 1421,63.4,64.27
  .complete 480 -- The Weaver
step
  .goto 1421,43.98,40.93
  .turnin 480 -- The Weaver
  .goto 1421,44.2,39.81
  .turnin 98299 -- Stop the Spread
step
  .todo "travel from Silverpine Forest to Undercity: the travel graph has no route yet"
  .zone 1458 >> Go to Undercity
step
  .goto 1458,58.08,89.51
  .todo "Light's Justice: objective 1 has no position in the pack"
  .complete 92421,1 -- Light's Justice
  .turnin 92421 -- Light's Justice
step
  .goto 1458,84.07,17.45
  .turnin 444 -- Rot Hide Origins
  .accept 446 -- Thule Ravenclaw
]]
)
