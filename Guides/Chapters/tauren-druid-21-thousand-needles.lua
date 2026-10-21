-- PLANNED: the thorough alt 1 route for Tauren Druid (HARDCORE): tools/route_planner.py tauren --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"tauren-druid-21-thousand-needles",
	[[
#chapter 29-30 Thousand Needles
step
  .goto 1441,78.06,77.13
  .accept 1104 -- Salt Flat Venom
  .note Vile Sting, a rare elite scorpid (near 70.6,72.9), drops the venom too: take it from the ordinary scorpids and keep away from him.
  .goto 1441,78.14,77.12
  .accept 1105 -- Hardened Shells
  .goto 1441,80.18,75.88
  .accept 1176 -- Load Lightening
step
  .goto 1441,84.2,70.73
  .complete 1176 -- Load Lightening
  .complete 1105 -- Hardened Shells
  .complete 1104 -- Salt Flat Venom
step
  .goto 1441,80.18,75.88
  .turnin 1176 -- Load Lightening
  .goto 1441,78.14,77.12
  .turnin 1105 -- Hardened Shells
  .goto 1441,78.06,77.13
  .turnin 1104 -- Salt Flat Venom
step
  .goto 1441,45.14,49.11 >> Go to the flight master
  .fly Thunder Bluff
step
  .goto 1456,61.54,80.92
  .turnin 1130 -- Melor Sends Word
step
  .goto 1456,47.0,49.83 >> Go to the flight master
  .fly Sun Rock Retreat
step
  .goto 1442,40.76,52.57
  .turnin 79192 -- Stepping Stones
  .level 30 -- reach it first: kill or grind on the way
  .note Grind about 5,800 experience before you go on: about 30 kills of creatures near your level (an estimate)
step
  .goto 1442,45.12,59.84 >> Go to the flight master
  .fly Crossroads
]]
)
