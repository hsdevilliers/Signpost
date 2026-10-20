-- PLANNED: the beam route for Troll Hunter, planned by tools/route_planner.py on 2026-10-20 (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"troll-hunter-21-thousand-needles",
	[[
#chapter 29-30 Thousand Needles
step
  .goto 1441,21.54,32.35
  .turnin 5088 -- Arikara
  .optional 5088 -- group quest: Arikara
step
  .goto 1441,22.76,24.62
  .complete 5151 -- Hypercapacitor Gizmo
  .optional 5151 -- group quest: Hypercapacitor Gizmo
step
  .goto 1441,21.43,32.55
  .turnin 5151 -- Hypercapacitor Gizmo
  .optional 5151 -- group quest: Hypercapacitor Gizmo
step
  .goto 1441,25.81,42.11
  .complete 1151 -- Test of Strength
  .optional 1151 -- group quest: Test of Strength
step
  .goto 1441,27.84,50.23
  .complete 98070 -- Stop the Screeching
step
  .goto 1441,46.21,51.51
  .turnin 98070 -- Stop the Screeching
step
  .goto 1441,53.95,41.49
  .turnin 1151 -- Test of Strength
  .optional 1151 -- group quest: Test of Strength
step
  .goto 1441,77.79,77.27
  .level 28
  .accept 1110 -- Rocket Car Parts
  .accept 1104 -- Salt Flat Venom
  .accept 1105 -- Hardened Shells
  .level 29
  .accept 1176 -- Load Lightening
step
  .goto 1441,84.25,84.48
  .complete 1105 -- Hardened Shells
step
  .goto 1441,78.14,77.12
  .turnin 1105 -- Hardened Shells
step
  .goto 1441,77.96,85.39
  .complete 1110 -- Rocket Car Parts
step
  .goto 1441,77.79,77.27
  .turnin 1110 -- Rocket Car Parts
step
  .goto 1441,70.99,75.35
  .complete 1176 -- Load Lightening
  .complete 1104 -- Salt Flat Venom
step
  .goto 1441,78.06,77.13
  .turnin 1104 -- Salt Flat Venom
  .turnin 1176 -- Load Lightening
]]
)
