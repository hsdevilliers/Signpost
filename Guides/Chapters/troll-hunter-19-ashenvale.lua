-- PLANNED: the beam route for Troll Hunter, planned by tools/route_planner.py on 2026-10-20 (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"troll-hunter-19-ashenvale",
	[[
#chapter 27-28 Ashenvale
step
  .goto 1440,70.01,71.16
  .accept 6504 -- The Lost Pages
  .todo "The Lost Pages: objective 1 has no position in the pack"
  .complete 6504,1 -- The Lost Pages
  .todo "The Lost Pages: objective 2 has no position in the pack"
  .complete 6504,2 -- The Lost Pages
  .todo "The Lost Pages: objective 3 has no position in the pack"
  .complete 6504,3 -- The Lost Pages
  .turnin 6504 -- The Lost Pages
step
  .goto 1440,73.78,61.46
  .turnin 6382 -- The Ashenvale Hunt
  .accept 6383 -- The Ashenvale Hunt
  .turnin 6383 -- The Ashenvale Hunt
step
  .todo "border The Barrens/Ashenvale: no crossing coordinates yet (record them in game or in Borders.lua)"
  .zone 1413 >> Go into The Barrens
step
  .todo "border The Barrens/Stonetalon Mountains: no crossing coordinates yet (record them in game or in Borders.lua)"
  .zone 1442 >> Go into Stonetalon Mountains
step
  .goto 1442,40.76,52.57
  .turnin 79192 -- Stepping Stones
step
  .goto 1442,47.5,41.0
  .complete 97538 -- Pigments for Paints
step
  .goto 1442,58.99,62.6
  .turnin 1095 -- Further Instructions
step
  .todo "travel from Stonetalon Mountains to Thunder Bluff: the travel graph has no route yet"
  .zone 1456 >> Go to Thunder Bluff
step
  .goto 1456,54.14,47.05
  .turnin 97538 -- Pigments for Paints
  .accept 98823 -- Earthen Echo
step
  .goto 1456,69.85,30.91
  .turnin 5062 -- Sacred Fire
  .accept 5088 -- Arikara
  .todo "Arikara: objective 1 has no position in the pack"
  .complete 5088,1 -- Arikara
  .optional 5088 -- group quest: Arikara
step
  .todo "travel from Thunder Bluff to Mulgore: the travel graph has no route yet"
  .zone 1412 >> Go to Mulgore
step
  .goto 1412,33.41,22.59
  .turnin 98823 -- Earthen Echo
  .accept 96259 -- Defending the Dead
  .accept 96261 -- The Broodmother
  .accept 96241 -- Talkin' bout Toxins, Mon
  .accept 96260 -- Stronger than Steel
]]
)
