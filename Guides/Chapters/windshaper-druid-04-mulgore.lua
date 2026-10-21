-- PLANNED: the beam route for Skyborne Druid (HARDCORE): tools/route_planner.py windshaper --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"windshaper-druid-04-mulgore",
	[[
#chapter 13-13 Mulgore
step
  .goto 1412,33.99,48.29
  .complete 743 -- Dangers of the Windfury
step
  .goto 1412,46.54,64.94
  .turnin 743 -- Dangers of the Windfury
step
  .goto 1412,61.19,49.32
  .complete 765 -- Supervisor Fizsprocket
step
  .goto 1412,54.76,64.27
  .turnin 765 -- Supervisor Fizsprocket
step
  .goto 1412,60.44,60.36
  .complete 99080 -- Drive Them Out
step
  .goto 1412,46.67,63.38
  .turnin 99080 -- Drive Them Out
  .accept 99082 -- The High Chieftain
  .goto 1412,44.92,61.67
  .complete 96661,1 -- Camping 101: Cooking
  .turnin 96661 -- Camping 101: Cooking
step
  .goto 1412,58.4,47.8
  .complete 76156 -- Stalk With The Earthmother
step
  .todo "travel from Mulgore to Thunder Bluff: the travel graph has no route yet"
  .zone 1456 >> Go to Thunder Bluff
step
  .goto 1456,60.3,51.68
  .turnin 99082 -- The High Chieftain
]]
)
