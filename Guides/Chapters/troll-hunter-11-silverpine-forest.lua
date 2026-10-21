-- PLANNED: the thorough alt 4 route for Troll Hunter: tools/route_planner.py troll --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"troll-hunter-11-silverpine-forest",
	[[
#chapter 19-20 Silverpine Forest
step
  .goto 1421,43.98,40.93
  .turnin 516 -- Beren's Peril
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
  .goto 1421,45.96,85.77
  .complete 98299 -- Stop the Spread
step
  .goto 1421,46.5,74.39
  .accept 452 -- Pyrewood Ambush
  .complete 452,1 -- Pyrewood Ambush
  .note Pyrewood Ambush: event: the quest finishes when something happens here (an ambush, a ritual); read the quest log
  .turnin 452 -- Pyrewood Ambush
step
  .goto 1421,44.2,39.81
  .turnin 98299 -- Stop the Spread
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
  .todo "Walk from Silverpine Forest to Hillsbrad Foothills: the guide has no waypoints for this yet, so find your own way. This step is done when you arrive in Hillsbrad Foothills."
  .zone 1424 >> Go to Hillsbrad Foothills
]]
)
