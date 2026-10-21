-- PLANNED: the thorough alt 4 route for Tauren Druid (HARDCORE): tools/route_planner.py tauren --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"tauren-druid-14-ashenvale",
	[[
#chapter 23-24 Ashenvale
step
  .goto 1440,68.34,75.3
  .accept 6544 -- Torek's Assault
step
  .goto 1440,71.11,68.12
  .accept 6503 -- Ashenvale Outrunners
step
  .goto 1440,72.87,70.18
  .complete 6503 -- Ashenvale Outrunners
step
  .goto 1440,71.11,68.12
  .turnin 6503 -- Ashenvale Outrunners
  .goto 1440,73.03,62.47
  .turnin 6544 -- Torek's Assault
step
  .goto 1440,73.78,61.46
  .turnin 6382 -- The Ashenvale Hunt
  .accept 6383 -- The Ashenvale Hunt
  .turnin 6383 -- The Ashenvale Hunt
step
  .goto 1440,40.43,61.48
  .accept 98251 -- Never Coming Back
  .accept 98252 -- A Void Path
  .goto 1440,38.23,58.15
  .turnin 98252 -- A Void Path
step
  .goto 1440,39.52,70.3
  .complete 98251 -- Never Coming Back
step
  .goto 1440,40.43,61.48
  .turnin 98251 -- Never Coming Back
step
  .todo "border The Barrens/Ashenvale: no crossing coordinates yet (record them in game or in Borders.lua)"
  .zone 1413 >> Go into The Barrens
step
  .todo "border The Barrens/Stonetalon Mountains: no crossing coordinates yet (record them in game or in Borders.lua)"
  .zone 1442 >> Go into Stonetalon Mountains
]]
)
