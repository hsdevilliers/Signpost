-- PLANNED: the beam route for Troll Hunter, planned by tools/route_planner.py on 2026-10-20 (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"troll-hunter-02-orgrimmar",
	[[
#chapter 10-10 Orgrimmar
step
  .goto 1454,56.05,34.12
  .accept 97242 -- Yelmak's Medley
  .accept 97275 -- Whuut's the Rush
  .turnin 97275 -- Whuut's the Rush
  .accept 6069 .class HUNTER -- The Hunter's Path
step
  .goto 1454,36.82,29.06
  .accept 97326 -- Rocks to Rests
  .accept 5726 -- Hidden Enemies
step
  .goto 1454,57.2,53.32
  .accept 97249 -- Favorite Food
step
  .goto 1454,36.53,29.06
  .turnin 97249 -- Favorite Food
step
  .goto 1454,55.68,72.17
  .accept 97246 -- Meal Appeal
step
  .todo "travel from Orgrimmar to Durotar: the travel graph has no route yet"
  .zone 1411 >> Go to Durotar
step
  .goto 1411,58.99,25.77
  .complete 99051 -- Threat from Below
]]
)
