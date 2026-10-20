-- PLANNED: the thorough alt 1 route for Troll Hunter: tools/route_planner.py troll --preset all --install --force --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"troll-hunter-10-undercity",
	[[
#chapter 19-20 Undercity
step
  .goto 1458,67.69,13.55
  .complete 92401 -- A Frightened Request
step
  .goto 1458,46.31,71.91
  .todo "The New Plague: objective 1 has no position in the pack"
  .complete 95216,1 -- The New Plague
  .turnin 95216 -- The New Plague
step
  .todo "travel from Undercity to Silverpine Forest: the travel graph has no route yet"
  .zone 1421 >> Go to Silverpine Forest
step
  .goto 1421,42.8,40.86
  .turnin 446 -- Thule Ravenclaw
  .accept 448 -- Report to Hadrec
  .goto 1421,44.52,43.02
  .turnin 92401 -- A Frightened Request
  .goto 1421,43.42,40.86
  .turnin 448 -- Report to Hadrec
  .accept 442 -- Assault on Fenris Isle
  .optional 442 -- group quest: Assault on Fenris Isle
step
  .goto 1421,58.12,69.77
  .level 20
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
  .todo "travel from Silverpine Forest to Hillsbrad Foothills: the travel graph has no route yet"
  .zone 1424 >> Go to Hillsbrad Foothills
step
  .goto 1424,20.79,47.4
  .accept 494 -- Time To Strike
]]
)
