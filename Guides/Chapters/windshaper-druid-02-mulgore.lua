-- PLANNED: the thorough alt 4 route for Skyborne Druid (HARDCORE): tools/route_planner.py windshaper --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"windshaper-druid-02-mulgore",
	[[
#chapter 12-12 Mulgore
step
  .goto 1412,33.38,22.57
  .accept 95350 -- Welcome to Azeroth
  .goto 1412,33.41,22.59
  .accept 94911 .class DRUID -- Child of Nature
step
  .goto 1412,46.03,63.44
  .accept 861 -- The Hunter's Way
  .goto 1412,46.68,63.83
  .accept 99079 -- Longwalker Malah
step
  .goto 1412,57.62,63.18
  .turnin 99079 -- Longwalker Malah
  .accept 99081 -- Grim Tidings
  .goto 1412,54.76,64.27
  .accept 749 -- The Ravaged Caravan
step
  .goto 1412,46.68,63.83
  .turnin 99081 -- Grim Tidings
  .accept 99101 -- Our Ancient Enemy
  .goto 1412,46.67,63.38
  .turnin 99101 -- Our Ancient Enemy
step
  .goto 1412,51.87,53.37
  .turnin 749 -- The Ravaged Caravan
  .accept 751 -- The Ravaged Caravan
step
  .goto 1412,54.76,64.27
  .turnin 751 -- The Ravaged Caravan
  .accept 764 -- The Venture Co.
  .accept 765 -- Supervisor Fizsprocket
step
  .goto 1412,58.66,47.59
  .complete 764 -- The Venture Co.
step
  .goto 1412,54.76,64.27
  .turnin 764 -- The Venture Co.
step
  .goto 1412,61.19,49.32
  .complete 765 -- Supervisor Fizsprocket
step
  .goto 1412,56.98,34.55
  .accept 833 -- A Sacred Burial
step
  .todo "travel from Mulgore to Thunder Bluff: the travel graph has no route yet"
  .zone 1456 >> Go to Thunder Bluff
]]
)
