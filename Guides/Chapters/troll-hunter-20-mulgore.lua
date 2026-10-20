-- PLANNED: the beam route for Troll Hunter, planned by tools/route_planner.py on 2026-10-20 (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"troll-hunter-20-mulgore",
	[[
#chapter 28-29 Mulgore
step
  .goto 1412,33.33,15.39
  .complete 96259 -- Defending the Dead
  .complete 96260 -- Stronger than Steel
  .complete 96241 -- Talkin' bout Toxins, Mon
step
  .goto 1412,32.47,19.98
  .turnin 96260 -- Stronger than Steel
  .turnin 96241 -- Talkin' bout Toxins, Mon
  .turnin 96259 -- Defending the Dead
step
  .goto 1412,33.42,7.46
  .complete 96261 -- The Broodmother
step
  .goto 1412,33.41,22.59
  .turnin 96261 -- The Broodmother
step
  .todo "travel from Mulgore to Thousand Needles: the travel graph has no route yet"
  .zone 1441 >> Go to Thousand Needles
step
  .goto 1441,46.21,51.51
  .accept 98069 -- Stolen Freewind Supplies
  .accept 98070 -- Stop the Screeching
  .todo "Stolen Freewind Supplies: objective 1 has no position in the pack"
  .complete 98069,1 -- Stolen Freewind Supplies
  .turnin 98069 -- Stolen Freewind Supplies
]]
)
