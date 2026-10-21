-- PLANNED: the beam route for Skyborne Druid (HARDCORE): tools/route_planner.py windshaper --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"windshaper-druid-07-durotar",
	[[
#chapter 15-15 Durotar
step
  .goto 1411,52.24,43.15
  .accept 99048 -- A Missing Hand
step
  .goto 1411,58.6,45.6
  .turnin 99048 -- A Missing Hand
  .accept 99049 -- Threat from Below
step
  .goto 1411,58.85,44.35
  .complete 99049 -- Threat from Below
step
  .goto 1411,52.24,43.15
  .turnin 99049 -- Threat from Below
  .accept 99051 -- Threat from Below
step
  .goto 1411,58.58,28.56
  .complete 99051 -- Threat from Below
step
  .goto 1411,52.24,43.15
  .turnin 99051 -- Threat from Below
  .goto 1411,50.84,43.59
  .accept 840 -- Conscript of the Horde
step
  .goto 1411,43.1,30.24
  .accept 816 -- Lost But Not Forgotten
step
  .goto 1411,35.7,25.31
  .complete 816 -- Lost But Not Forgotten
step
  .goto 1411,43.1,30.24
  .turnin 816 -- Lost But Not Forgotten
step
  .todo "border Durotar/The Barrens: no crossing coordinates yet (record them in game or in Borders.lua)"
  .zone 1413 >> Go into The Barrens
]]
)
