-- PLANNED: the thorough alt 1 route for Troll Hunter: tools/route_planner.py troll --preset all --install --force --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"troll-hunter-03-durotar",
	[[
#chapter 11-12 Durotar
step
  .goto 1411,53.08,9.4
  .complete 5726 -- Hidden Enemies
step
  .goto 1411,51.27,19.19
  .complete 835 -- Securing the Lines
step
  .goto 1411,46.37,22.94
  .turnin 835 -- Securing the Lines
step
  .todo "travel from Durotar to Orgrimmar: the travel graph has no route yet"
  .zone 1454 >> Go to Orgrimmar
step
  .goto 1454,31.73,37.82
  .turnin 5726 -- Hidden Enemies
  .accept 5727 -- Hidden Enemies
  .turnin 5727 -- Hidden Enemies
step
  .level 12 -- reach it first: kill or grind on the way
step
  .goto 1454,39.2,28.3
  .complete 97326 -- Rocks to Rests
step
  .goto 1454,36.82,29.06
  .turnin 97326 -- Rocks to Rests
step
  .goto 1454,66.0,28.4
  .complete 97242 -- Yelmak's Medley
]]
)
