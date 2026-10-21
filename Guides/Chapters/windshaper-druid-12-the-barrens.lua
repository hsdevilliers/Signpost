-- PLANNED: the beam route for Skyborne Druid (HARDCORE): tools/route_planner.py windshaper --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"windshaper-druid-12-the-barrens",
	[[
#chapter 22-23 The Barrens
step
  .goto 1413,35.19,27.76
  .turnin 6523 -- Protect Kaya
  .goto 1413,35.26,27.88
  .accept 1062 -- Goblin Invaders
step
  .goto 1413,39.18,15.68
  .complete 875 -- Harpy Lieutenants
step
  .goto 1413,49.05,11.17
  .turnin 3922 -- Nugget Slugs
step
  .goto 1413,51.62,30.9
  .turnin 875 -- Harpy Lieutenants
  .accept 876 -- Serena Bloodfeather
step
  .goto 1413,62.37,37.62
  .turnin 865 -- Raptor Horns
  .goto 1413,62.98,37.22
  .turnin 1094 -- Further Instructions
step
  .todo "travel from The Barrens to Silverpine Forest: the travel graph has no route yet"
  .zone 1421 >> Go to Silverpine Forest
step
  .goto 1421,58.12,69.77
  .accept 95883 -- The Tortured Soul
  .accept 95885 -- The Offering of Blood
step
  .goto 1421,58.06,69.89
  .complete 95883 -- The Tortured Soul
  .complete 95885 -- The Offering of Blood
step
  .goto 1421,58.12,69.77
  .turnin 95883 -- The Tortured Soul
  .turnin 95885 -- The Offering of Blood
step
  .todo "travel from Silverpine Forest to Undercity: the travel graph has no route yet"
  .zone 1458 >> Go to Undercity
]]
)
