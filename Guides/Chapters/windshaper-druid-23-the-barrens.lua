-- PLANNED: the thorough alt 5 route for Skyborne Druid (HARDCORE): tools/route_planner.py windshaper --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"windshaper-druid-23-the-barrens",
	[[
#chapter 29-29 The Barrens
step
  .goto 1413,48.97,86.31
  .accept 857 -- The Tear of the Moons
step
  .goto 1413,49.13,84.25
  .complete 857 -- The Tear of the Moons
step
  .goto 1413,48.97,86.31
  .turnin 857 -- The Tear of the Moons
step
  .goto 1413,44.86,59.14
  .accept 1130 -- Melor Sends Word
  .goto 1413,45.1,57.68
  .turnin 1153 -- A New Ore Sample
step
  .todo "travel from The Barrens to Thunder Bluff: the travel graph has no route yet"
  .zone 1456 >> Go to Thunder Bluff
step
  .goto 1456,61.54,80.92
  .turnin 1130 -- Melor Sends Word
step
  .todo "travel from Thunder Bluff to Mulgore: the travel graph has no route yet"
  .zone 1412 >> Go to Mulgore
step
  .goto 1412,33.41,22.59
  .accept 96259 -- Defending the Dead
  .goto 1412,32.5,20.66
  .accept 96241 -- Talkin' bout Toxins, Mon
  .goto 1412,32.47,19.98
  .accept 96260 -- Stronger than Steel
step
  .goto 1412,33.35,13.48
  .complete 96260 -- Stronger than Steel
  .complete 96259 -- Defending the Dead
  .complete 96241 -- Talkin' bout Toxins, Mon
]]
)
