-- PLANNED: the beam route for Troll Hunter, planned by tools/route_planner.py on 2026-10-20 (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"troll-hunter-03-durotar",
	[[
#chapter 10-11 Durotar
step
  .goto 1411,50.84,43.59
  .accept 840 -- Conscript of the Horde
step
  .goto 1411,43.73,53.79
  .complete 6394 -- Thazz'ril's Pick
step
  .goto 1411,44.63,68.65
  .turnin 6394 -- Thazz'ril's Pick
step
  .goto 1411,47.64,78.1
  .complete 791 -- Carry Your Weight
step
  .goto 1411,51.85,43.49
  .turnin 6069 .class HUNTER -- The Hunter's Path
  .accept 6062 .class HUNTER -- Taming the Beast
  .turnin 6062 .class HUNTER -- Taming the Beast
  .accept 6083 .class HUNTER -- Taming the Beast
  .turnin 6083 .class HUNTER -- Taming the Beast
  .accept 6082 .class HUNTER -- Taming the Beast
  .turnin 6082 .class HUNTER -- Taming the Beast
  .accept 6081 .class HUNTER -- Training the Beast
  .turnin 99051 -- Threat from Below
  .accept 99052 -- Threat from Below
step
  .goto 1411,43.1,30.24
  .accept 816 -- Lost But Not Forgotten
step
  .goto 1411,42.29,26.9
  .complete 5726 -- Hidden Enemies
  .complete 806 -- Dark Storms
step
  .todo "travel from Durotar to Orgrimmar: the travel graph has no route yet"
  .zone 1454 >> Go to Orgrimmar
step
  .goto 1454,57.2,53.32
  .turnin 97246 -- Meal Appeal
]]
)
