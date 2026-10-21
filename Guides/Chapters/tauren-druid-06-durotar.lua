-- PLANNED: the thorough route for Tauren Druid (HARDCORE): tools/route_planner.py tauren --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"tauren-druid-06-durotar",
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
  .goto 1411,50.84,43.59
  .accept 840 -- Conscript of the Horde
step
  .todo "border Durotar/The Barrens: no crossing coordinates yet (record them in game or in Borders.lua)"
  .zone 1413 >> Go into The Barrens
step
  .goto 1413,62.26,19.38
  .turnin 840 -- Conscript of the Horde
  .accept 842 -- Crossroads Conscription
step
  .goto 1413,51.44,30.15
  .accept 848 -- Fungal Spores
  .goto 1413,51.5,30.87
  .accept 872 -- The Disruption Ends
  .goto 1413,51.62,30.9
  .level 12
  .accept 867 -- Harpy Raiders
]]
)
