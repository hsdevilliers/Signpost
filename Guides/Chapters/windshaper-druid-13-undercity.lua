-- PLANNED: the beam route for Skyborne Druid (HARDCORE): tools/route_planner.py windshaper --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"windshaper-druid-13-undercity",
	[[
#chapter 23-24 Undercity
step
  .goto 1458,73.4,33.0
  .turnin 78149 -- Fury of the Land
step
  .todo "travel from Undercity to Tirisfal Glades: the travel graph has no route yet"
  .zone 1420 >> Go to Tirisfal Glades
step
  .goto 1420,65.25,60.2
  .accept 92422 -- The Wrath of Rath'mael
  .todo "The Wrath of Rath'mael: objective 1 has no position in the pack"
  .complete 92422,1 -- The Wrath of Rath'mael
  .turnin 92422 -- The Wrath of Rath'mael
step
  .todo "travel from Tirisfal Glades to Ashenvale: the travel graph has no route yet"
  .zone 1440 >> Go to Ashenvale
step
  .level 24 -- reach it first: kill or grind on the way
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
  .goto 1440,41.53,34.49
  .accept 6482 -- Freedom to Ruul
step
  .goto 1440,11.9,34.54
  .accept 216 -- Between a Rock and a Thistlefur
  .goto 1440,11.56,34.29
  .turnin 6562 -- Trouble in the Deeps
  .accept 6563 -- The Essence of Aku'Mai
]]
)
