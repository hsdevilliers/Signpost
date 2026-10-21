-- PLANNED: the beam route for Skyborne Druid (HARDCORE): tools/route_planner.py windshaper --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"windshaper-druid-02-mulgore",
	[[
#chapter 11-12 Mulgore
step
  .goto 1412,33.41,22.59
  .accept 94911 .class DRUID -- Child of Nature
step
  .level 12 -- reach it first: kill or grind on the way
step
  .goto 1412,33.38,22.57
  .accept 95350 -- Welcome to Azeroth
step
  .goto 1412,46.03,63.44
  .accept 861 -- The Hunter's Way
  .goto 1412,46.68,63.83
  .accept 99079 -- Longwalker Malah
step
  .goto 1412,47.28,57.63
  .accept 99411 -- Kyle's Gone Missing!
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
  .accept 99080 -- Drive Them Out
step
  .goto 1412,46.28,62.34
  .complete 99411 -- Kyle's Gone Missing!
step
  .goto 1412,47.28,57.63
  .turnin 99411 -- Kyle's Gone Missing!
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
  .goto 1412,58.01,52.88
  .complete 764,1 -- The Venture Co.
step
  .goto 1412,53.15,32.46
  .complete 861 -- The Hunter's Way
step
  .goto 1412,56.98,34.55
  .accept 833 -- A Sacred Burial
step
  .goto 1412,57.96,30.92
  .complete 833 -- A Sacred Burial
step
  .goto 1412,56.98,34.55
  .turnin 833 -- A Sacred Burial
step
  .goto 1412,57.96,44.88
  .complete 764,2 -- The Venture Co.
step
  .goto 1412,54.76,64.27
  .turnin 764 -- The Venture Co.
step
  .goto 1412,46.54,64.94
  .accept 743 -- Dangers of the Windfury
  .goto 1412,46.13,67.4
  .accept 96605 -- The Great Outdoors
step
  .goto 1412,46.21,67.31
  .complete 96605 -- The Great Outdoors
step
  .goto 1412,46.13,67.4
  .turnin 96605 -- The Great Outdoors
  .accept 96661 -- Camping 101: Cooking
step
  .goto 1412,33.13,65.92
  .accept 98430 -- The Longwalkers
step
  .goto 1412,37.19,64.62
  .complete 98430 -- The Longwalkers
step
  .todo "travel from Mulgore to Thunder Bluff: the travel graph has no route yet"
  .zone 1456 >> Go to Thunder Bluff
]]
)
