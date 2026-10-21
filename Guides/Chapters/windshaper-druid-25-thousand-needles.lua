-- PLANNED: the beam route for Skyborne Druid (HARDCORE): tools/route_planner.py windshaper --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"windshaper-druid-25-thousand-needles",
	[[
#chapter 29-30 Thousand Needles
step
  .goto 1441,80.18,75.88
  .turnin 1176 -- Load Lightening
  .goto 1441,78.14,77.12
  .turnin 1105 -- Hardened Shells
  .goto 1441,78.06,77.13
  .turnin 1104 -- Salt Flat Venom
step
  .level 30 -- reach it first: kill or grind on the way
]]
)
