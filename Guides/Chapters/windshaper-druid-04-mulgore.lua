-- PLANNED: the thorough alt 5 route for Skyborne Druid (HARDCORE): tools/route_planner.py windshaper --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"windshaper-druid-04-mulgore",
	[[
#chapter 13-13 Mulgore
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
  .goto 1412,58.4,47.8
  .complete 76156 -- Stalk With The Earthmother
step
  .todo "travel from Mulgore to Thunder Bluff: the travel graph has no route yet"
  .zone 1456 >> Go to Thunder Bluff
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
step
  .goto 1456,61.54,80.92
  .turnin 861 -- The Hunter's Way
step
  .todo "travel from Thunder Bluff to The Barrens: the travel graph has no route yet"
  .zone 1413 >> Go to The Barrens
step
  .goto 1413,51.5,30.87
  .accept 871 -- Disrupt the Attacks
  .goto 1413,51.93,30.32
  .accept 869 -- Raptor Thieves
  .note Takk the Leaper, a rare elite raptor (near 59.6,8.3), is one of the creatures that drop the heads: take them from the ordinary raptors and keep away from him.
step
  .goto 1413,54.6,23.16
  .complete 869 -- Raptor Thieves
step
  .todo "travel from The Barrens to Orgrimmar: the travel graph has no route yet"
  .zone 1454 >> Go to Orgrimmar
]]
)
