-- PLANNED: the beam route for Troll Hunter: tools/route_planner.py troll --preset all --install --force --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"troll-hunter-07-undercity",
	[[
#chapter 18-18 Undercity
step
  .goto 1458,73.4,33.0
  .turnin 78127 -- The Dalaran Digest
  .turnin 79096 -- Ataeric: On Arcane Curiosities
step
  .goto 1458,54.0,49.3
  .complete 97291 -- Unending Torment
step
  .goto 1458,48.82,69.28
  .turnin 97291 -- Unending Torment
step
  .todo "Walk from Undercity to Tirisfal Glades: the guide has no waypoints for this yet, so find your own way. This step is done when you arrive in Tirisfal Glades."
  .zone 1420 >> Go to Tirisfal Glades
]]
)
