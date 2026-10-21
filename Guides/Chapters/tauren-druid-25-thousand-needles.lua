-- PLANNED: the thorough route for Tauren Druid (HARDCORE): tools/route_planner.py tauren --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"tauren-druid-25-thousand-needles",
	[[
#chapter 29-30 Thousand Needles
step
  .goto 1441,79.89,85.72
  .complete 1105 -- Hardened Shells
step
  .goto 1441,78.14,77.12
  .turnin 1105 -- Hardened Shells
step
  .goto 1441,78.01,89.85
  .complete 1176 -- Load Lightening
step
  .goto 1441,80.18,75.88
  .turnin 1176 -- Load Lightening
step
  .todo "border The Barrens/Thousand Needles: no crossing coordinates yet (record them in game or in Borders.lua)"
  .zone 1413 >> Go into The Barrens
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
  .level 30 -- reach it first: kill or grind on the way
]]
)
