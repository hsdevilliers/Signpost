-- PLANNED: the thorough alt 5 route for Troll Hunter: tools/route_planner.py troll --preset all --install --force --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"troll-hunter-17-thunder-bluff",
	[[
#chapter 27-28 Thunder Bluff
step
  .goto 1456,54.97,51.41
  .accept 1195 -- The Sacred Flame
  .todo "The Sacred Flame: objective 1 has no position in the pack"
  .complete 1195,1 -- The Sacred Flame
  .turnin 1195 -- The Sacred Flame
step
  .goto 1456,71.06,34.19
  .accept 98823 -- Earthen Echo
step
  .todo "travel from Thunder Bluff to Mulgore: the travel graph has no route yet"
  .zone 1412 >> Go to Mulgore
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
  .level 28 -- reach it first: kill or grind on the way
]]
)
