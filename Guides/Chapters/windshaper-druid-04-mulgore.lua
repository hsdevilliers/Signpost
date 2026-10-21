-- PLANNED: the thorough alt 4 route for Skyborne Druid (HARDCORE): tools/route_planner.py windshaper --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"windshaper-druid-04-mulgore",
	[[
#chapter 13-13 Mulgore
step
  .goto 1412,58.4,47.8
  .complete 76156 -- Stalk With The Earthmother
step
  .goto 1412,54.76,64.27
  .turnin 765 -- Supervisor Fizsprocket
step
  .todo "travel from Mulgore to Thunder Bluff: the travel graph has no route yet"
  .zone 1456 >> Go to Thunder Bluff
step
  .goto 1456,61.54,80.92
  .turnin 861 -- The Hunter's Way
step
  .goto 1456,39.44,65.82
  .turnin 76156 -- Stalk With The Earthmother
  .accept 76160 -- Stalk With The Earthmother
  .todo "Stalk With The Earthmother: objective 1 has no position in the pack"
  .complete 76160,1 -- Stalk With The Earthmother
  .turnin 76160 -- Stalk With The Earthmother
  .accept 76240 -- Stalk With The Earthmother
  .todo "Stalk With The Earthmother: objective 1 has no position in the pack"
  .complete 76240,1 -- Stalk With The Earthmother
  .turnin 76240 -- Stalk With The Earthmother
step
  .goto 1456,37.75,59.57
  .turnin 744 -- Preparation for Ceremony
  .goto 1456,38.0,55.9
  .turnin 97485 -- Traditions of the Bluff
step
  .todo "travel from Thunder Bluff to The Barrens: the travel graph has no route yet"
  .zone 1413 >> Go to The Barrens
step
  .goto 1413,51.5,30.87
  .accept 871 -- Disrupt the Attacks
  .goto 1413,51.93,30.32
  .accept 869 -- Raptor Thieves
  .goto 1413,52.23,31.01
  .accept 844 -- Plainstrider Menace
  .goto 1413,52.26,31.93
  .accept 870 -- The Forgotten Pools
]]
)
