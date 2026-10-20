-- PLANNED: the beam route for Troll Hunter, planned by tools/route_planner.py on 2026-10-20 (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"troll-hunter-05-durotar",
	[[
#chapter 12-13 Durotar
step
  .goto 1411,35.7,25.31
  .complete 816 -- Lost But Not Forgotten
step
  .goto 1411,43.1,30.24
  .turnin 816 -- Lost But Not Forgotten
step
  .todo "border Durotar/The Barrens: no crossing coordinates yet (record them in game or in Borders.lua)"
  .zone 1413 >> Go into The Barrens
step
  .goto 1413,62.26,19.38
  .turnin 840 -- Conscript of the Horde
  .accept 842 -- Crossroads Conscription
step
  .goto 1413,52.62,29.84
  .accept 6365 -- Meats to Orgrimmar
  .turnin 842 -- Crossroads Conscription
  .accept 844 -- Plainstrider Menace
  .accept 870 -- The Forgotten Pools
  .turnin 870 -- The Forgotten Pools
step
  .goto 1413,52.76,28.2
  .complete 844 -- Plainstrider Menace
step
  .goto 1413,52.23,31.01
  .turnin 844 -- Plainstrider Menace
  .accept 845 -- The Zhevra
step
  .goto 1413,48.96,37.55
  .complete 845 -- The Zhevra
step
  .goto 1413,52.23,31.01
  .turnin 845 -- The Zhevra
  .accept 903 -- Prowlers of the Barrens
]]
)
