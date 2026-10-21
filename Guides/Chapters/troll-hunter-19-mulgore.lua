-- PLANNED: the thorough alt 4 route for Troll Hunter: tools/route_planner.py troll --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"troll-hunter-19-mulgore",
	[[
#chapter 26-27 Mulgore
step
  .goto 1412,33.41,22.59
  .turnin 98823 -- Earthen Echo
  .accept 96259 -- Defending the Dead
  .accept 96261 -- The Broodmother
  .goto 1412,32.5,20.66
  .accept 96241 -- Talkin' bout Toxins, Mon
  .goto 1412,32.47,19.98
  .accept 96260 -- Stronger than Steel
step
  .goto 1412,33.33,15.39
  .complete 96259 -- Defending the Dead
  .complete 96260 -- Stronger than Steel
  .complete 96241 -- Talkin' bout Toxins, Mon
step
  .goto 1412,32.47,19.98
  .turnin 96260 -- Stronger than Steel
  .goto 1412,32.5,20.66
  .turnin 96241 -- Talkin' bout Toxins, Mon
  .goto 1412,33.41,22.59
  .turnin 96259 -- Defending the Dead
step
  .todo "Walk from Mulgore to Stonetalon Mountains: the guide has no waypoints for this yet, so find your own way. This step is done when you arrive in Stonetalon Mountains."
  .zone 1442 >> Go to Stonetalon Mountains
]]
)
