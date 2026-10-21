-- PLANNED: the beam route for Skyborne Druid (HARDCORE): tools/route_planner.py windshaper --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"windshaper-druid-24-mulgore",
	[[
#chapter 29-29 Mulgore
step
  .goto 1412,32.47,19.98
  .turnin 96260 -- Stronger than Steel
  .goto 1412,32.5,20.66
  .turnin 96241 -- Talkin' bout Toxins, Mon
  .goto 1412,33.41,22.59
  .turnin 96259 -- Defending the Dead
step
  .todo "travel from Mulgore to The Barrens: the travel graph has no route yet"
  .zone 1413 >> Go to The Barrens
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
  .todo "border The Barrens/Thousand Needles: no crossing coordinates yet (record them in game or in Borders.lua)"
  .zone 1441 >> Go into Thousand Needles
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
]]
)
