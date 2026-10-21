-- PLANNED: the thorough alt 4 route for Troll Hunter: tools/route_planner.py troll --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"troll-hunter-18-the-barrens",
	[[
#chapter 26-26 The Barrens
step
  .goto 1413,48.12,5.42
  .accept 6543 -- The Warsong Reports
  .todo "The Warsong Reports: objective 1 has no position in the pack"
  .complete 6543,1 -- The Warsong Reports
  .todo "The Warsong Reports: objective 2 has no position in the pack"
  .complete 6543,2 -- The Warsong Reports
  .todo "The Warsong Reports: objective 3 has no position in the pack"
  .complete 6543,3 -- The Warsong Reports
  .turnin 6543 -- The Warsong Reports
step
  .goto 1413,62.37,37.62
  .accept 1221 -- Blueleaf Tubers
  .todo "Blueleaf Tubers: objective 1 has no position in the pack"
  .complete 1221,1 -- Blueleaf Tubers
step
  .goto 1413,62.59,37.47
  .accept 92706 -- WANTED: Bruuz
  .goto 1413,62.98,37.22
  .turnin 1094 -- Further Instructions
  .accept 1095 -- Further Instructions
step
  .goto 1413,62.34,37.6
  .complete 1221,4 -- Blueleaf Tubers
  .complete 1221,3 -- Blueleaf Tubers
  .complete 1221,2 -- Blueleaf Tubers
step
  .goto 1413,62.37,37.62
  .turnin 1221 -- Blueleaf Tubers
step
  .goto 1413,64.3,39.13
  .complete 92706 -- WANTED: Bruuz
step
  .goto 1413,62.68,36.23
  .turnin 92706 -- WANTED: Bruuz
step
  .goto 1413,65.84,43.86
  .turnin 874 -- Mahren Skyseer
  .accept 873 -- Isha Awak
step
  .goto 1413,63.53,53.85
  .complete 873 -- Isha Awak
step
  .goto 1413,65.84,43.86
  .turnin 873 -- Isha Awak
step
  .goto 1413,44.86,59.14
  .accept 1130 -- Melor Sends Word
step
  .goto 1413,44.45,59.15 >> Go to the flight master
  .fly Thunder Bluff
step
  .goto 1456,61.54,80.92
  .turnin 1130 -- Melor Sends Word
step
  .goto 1456,71.06,34.19
  .level 24
  .accept 98823 -- Earthen Echo
step
  .todo "Walk from Thunder Bluff to Mulgore: the guide has no waypoints for this yet, so find your own way. This step is done when you arrive in Mulgore."
  .zone 1412 >> Go to Mulgore
]]
)
