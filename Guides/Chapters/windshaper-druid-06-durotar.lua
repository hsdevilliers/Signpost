-- PLANNED: the thorough alt 5 route for Skyborne Druid (HARDCORE): tools/route_planner.py windshaper --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"windshaper-druid-06-durotar",
	[[
#chapter 14-15 Durotar
step
  .goto 1411,41.54,18.6
  .accept 812 -- Need for a Cure
  .todo "Need for a Cure: objective 1 has no position in the pack"
  .complete 812,1 -- Need for a Cure
  .turnin 812 -- Need for a Cure
step
  .goto 1411,46.37,22.94
  .accept 834 -- Winds in the Desert
step
  .goto 1411,49.1,22.59
  .complete 834 -- Winds in the Desert
step
  .goto 1411,46.37,22.94
  .turnin 834 -- Winds in the Desert
  .accept 835 -- Securing the Lines
step
  .goto 1411,51.56,21.65
  .complete 835 -- Securing the Lines
step
  .goto 1411,46.37,22.94
  .turnin 835 -- Securing the Lines
step
  .goto 1411,42.88,26.43
  .complete 5726 -- Hidden Enemies
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
