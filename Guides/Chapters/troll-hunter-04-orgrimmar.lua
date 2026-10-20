-- PLANNED: the beam route for Troll Hunter, planned by tools/route_planner.py on 2026-10-20 (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"troll-hunter-04-orgrimmar",
	[[
#chapter 11-12 Orgrimmar
step
  .goto 1454,66.05,18.53
  .turnin 6081 .class HUNTER -- Training the Beast
step
  .goto 1454,31.73,37.82
  .turnin 5726 -- Hidden Enemies
  .accept 5727 -- Hidden Enemies
  .turnin 5727 -- Hidden Enemies
step
  .goto 1454,41.6,34.4
  .complete 97326 -- Rocks to Rests
step
  .goto 1454,36.82,29.06
  .turnin 97326 -- Rocks to Rests
step
  .goto 1454,66.8,28.3
  .complete 97242 -- Yelmak's Medley
step
  .goto 1454,56.05,34.12
  .turnin 97242 -- Yelmak's Medley
step
  .todo "travel from Orgrimmar to Durotar: the travel graph has no route yet"
  .zone 1411 >> Go to Durotar
step
  .goto 1411,59.22,17.6
  .complete 99052 -- Threat from Below
step
  .goto 1411,52.24,43.15
  .turnin 806 -- Dark Storms
  .turnin 99052 -- Threat from Below
  .turnin 791 -- Carry Your Weight
]]
)
