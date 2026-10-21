-- PLANNED: the thorough alt 4 route for Troll Hunter: tools/route_planner.py troll --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"troll-hunter-10-undercity",
	[[
#chapter 19-19 Undercity
step
  .goto 1458,58.08,89.51
  .todo "Light's Justice: objective 1 has no position in the pack"
  .complete 92421,1 -- Light's Justice
  .turnin 92421 -- Light's Justice
step
  .goto 1458,46.31,71.91
  .todo "The New Plague: objective 1 has no position in the pack"
  .complete 95216,1 -- The New Plague
  .turnin 95216 -- The New Plague
step
  .goto 1458,84.07,17.45
  .turnin 444 -- Rot Hide Origins
  .accept 446 -- Thule Ravenclaw
step
  .goto 1458,67.69,13.55
  .complete 92401 -- A Frightened Request
step
  .goto 1458,63.25,48.56 >> Go to the flight master
  .fly The Sepulcher
]]
)
