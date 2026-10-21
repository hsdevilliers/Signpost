-- PLANNED: the thorough alt 5 route for Skyborne Druid (HARDCORE): tools/route_planner.py windshaper --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"windshaper-druid-15-ashenvale",
	[[
#chapter 24-24 Ashenvale
step
  .goto 1440,11.69,34.91
  .accept 6442 -- Naga at the Zoram Strand
  .goto 1440,11.9,34.54
  .accept 216 -- Between a Rock and a Thistlefur
  .goto 1440,12.06,34.63
  .accept 6641 -- Vorsha the Lasher
  .goto 1440,12.22,34.22
  .turnin 6641 -- Vorsha the Lasher
step
  .goto 1440,11.25,31.02
  .complete 6442 -- Naga at the Zoram Strand
step
  .goto 1440,11.69,34.91
  .turnin 6442 -- Naga at the Zoram Strand
step
  .goto 1440,31.74,38.0
  .complete 216 -- Between a Rock and a Thistlefur
step
  .goto 1440,11.9,34.54
  .turnin 216 -- Between a Rock and a Thistlefur
step
  .goto 1440,41.53,34.49
  .accept 6482 -- Freedom to Ruul
step
  .goto 1440,68.34,75.3
  .accept 6544 -- Torek's Assault
step
  .goto 1440,71.11,68.12
  .accept 6503 -- Ashenvale Outrunners
  .goto 1440,73.03,62.47
  .turnin 6544 -- Torek's Assault
step
  .goto 1440,74.11,60.92
  .turnin 6482 -- Freedom to Ruul
step
  .goto 1440,72.87,70.18
  .complete 6503 -- Ashenvale Outrunners
step
  .goto 1440,71.11,68.12
  .turnin 6503 -- Ashenvale Outrunners
step
  .todo "border The Barrens/Ashenvale: no crossing coordinates yet (record them in game or in Borders.lua)"
  .zone 1413 >> Go into The Barrens
step
  .todo "border The Barrens/Stonetalon Mountains: no crossing coordinates yet (record them in game or in Borders.lua)"
  .zone 1442 >> Go into Stonetalon Mountains
]]
)
