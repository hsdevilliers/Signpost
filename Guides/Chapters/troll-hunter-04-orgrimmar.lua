-- PLANNED: the thorough alt 1 route for Troll Hunter: tools/route_planner.py troll --preset all --install --force --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"troll-hunter-04-orgrimmar",
	[[
#chapter 12-12 Orgrimmar
step
  .goto 1454,56.05,34.12
  .turnin 97242 -- Yelmak's Medley
step
  .todo "travel from Orgrimmar to The Barrens: the travel graph has no route yet"
  .zone 1413 >> Go to The Barrens
step
  .goto 1413,62.26,19.38
  .turnin 840 -- Conscript of the Horde
  .accept 842 -- Crossroads Conscription
step
  .goto 1413,52.62,29.84
  .accept 6365 -- Meats to Orgrimmar
  .goto 1413,52.23,31.01
  .turnin 842 -- Crossroads Conscription
  .accept 844 -- Plainstrider Menace
  .goto 1413,52.26,31.93
  .accept 870 -- The Forgotten Pools
step
  .goto 1413,52.76,28.2
  .complete 844 -- Plainstrider Menace
step
  .goto 1413,51.93,30.32
  .accept 869 -- Raptor Thieves
  .goto 1413,51.5,30.34
  .turnin 6365 -- Meats to Orgrimmar
  .goto 1413,51.44,30.15
  .accept 848 -- Fungal Spores
  .goto 1413,51.5,30.87
  .accept 871 -- Disrupt the Attacks
  .goto 1413,51.62,30.9
  .accept 867 -- Harpy Raiders
]]
)
