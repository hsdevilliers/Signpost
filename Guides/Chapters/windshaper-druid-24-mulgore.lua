-- PLANNED: the thorough alt 5 route for Skyborne Druid (HARDCORE): tools/route_planner.py windshaper --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"windshaper-druid-24-mulgore",
	[[
#chapter 29-30 Mulgore
step
  .goto 1412,32.47,19.98
  .turnin 96260 -- Stronger than Steel
  .goto 1412,32.5,20.66
  .turnin 96241 -- Talkin' bout Toxins, Mon
  .goto 1412,33.41,22.59
  .turnin 96259 -- Defending the Dead
step
  .todo "travel from Mulgore to Thousand Needles: the travel graph has no route yet"
  .zone 1441 >> Go to Thousand Needles
step
  .goto 1441,78.14,77.12
  .accept 1105 -- Hardened Shells
  .goto 1441,80.18,75.88
  .accept 1176 -- Load Lightening
step
  .goto 1441,79.89,85.72
  .complete 1105 -- Hardened Shells
  .complete 1176 -- Load Lightening
step
  .goto 1441,78.14,77.12
  .turnin 1105 -- Hardened Shells
  .goto 1441,80.18,75.88
  .turnin 1176 -- Load Lightening
step
  .level 30 -- reach it first: kill or grind on the way
]]
)
