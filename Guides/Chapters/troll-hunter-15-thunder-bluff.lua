-- PLANNED: the beam route for Troll Hunter, planned by tools/route_planner.py on 2026-10-20 (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"troll-hunter-15-thunder-bluff",
	[[
#chapter 25-25 Thunder Bluff
step
  .goto 1456,61.54,80.92
  .turnin 1130 -- Melor Sends Word
step
  .goto 1456,54.97,51.41
  .accept 1195 -- The Sacred Flame
  .todo "The Sacred Flame: objective 1 has no position in the pack"
  .complete 1195,1 -- The Sacred Flame
  .turnin 1195 -- The Sacred Flame
  .accept 1196 -- The Sacred Flame
step
  .goto 1456,54.14,47.05
  .accept 97538 -- Pigments for Paints
step
  .todo "travel from Thunder Bluff to The Barrens: the travel graph has no route yet"
  .zone 1413 >> Go to The Barrens
step
  .goto 1413,41.75,81.3
  .complete 893 -- Weapons of Choice
step
  .goto 1413,48.77,77.21
  .complete 97250 -- Wrongly Blamed, Justly Corrected
step
  .goto 1413,44.62,59.27
  .turnin 97250 -- Wrongly Blamed, Justly Corrected
  .turnin 893 -- Weapons of Choice
  .level 25
  .accept 1153 -- A New Ore Sample
]]
)
