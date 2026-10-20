-- PLANNED: the thorough alt 5 route for Troll Hunter: tools/route_planner.py troll --preset all --install --force --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"troll-hunter-10-silverpine-forest",
	[[
#chapter 20-21 Silverpine Forest
step
  .goto 1421,58.12,69.77
  .level 20
  .accept 95883 -- The Tortured Soul
  .accept 95885 -- The Offering of Blood
step
  .goto 1421,58.06,69.89
  .complete 516 -- Beren's Peril
  .complete 95883 -- The Tortured Soul
  .complete 95885 -- The Offering of Blood
step
  .goto 1421,58.12,69.77
  .turnin 95883 -- The Tortured Soul
  .turnin 95885 -- The Offering of Blood
step
  .goto 1421,63.4,64.27
  .complete 480 -- The Weaver
  .complete 78127 -- The Dalaran Digest
step
  .todo "travel from Silverpine Forest to Undercity: the travel graph has no route yet"
  .zone 1458 >> Go to Undercity
step
  .goto 1458,73.4,33.0
  .turnin 78127 -- The Dalaran Digest
  .turnin 79096 -- Ataeric: On Arcane Curiosities
  .goto 1458,84.07,17.45
  .turnin 444 -- Rot Hide Origins
  .accept 446 -- Thule Ravenclaw
step
  .goto 1458,67.69,13.55
  .complete 92401 -- A Frightened Request
step
  .todo "travel from Undercity to Silverpine Forest: the travel graph has no route yet"
  .zone 1421 >> Go to Silverpine Forest
step
  .goto 1421,43.98,40.93
  .turnin 480 -- The Weaver
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
  .goto 1421,45.34,71.29
  .complete 99 -- Arugal's Folly
  .optional 99 -- group quest: Arugal's Folly
  .complete 450 -- A Recipe For Death
step
  .goto 1421,45.96,85.77
  .complete 98299 -- Stop the Spread
step
  .goto 1421,42.8,40.86
  .turnin 450 -- A Recipe For Death
  .accept 451 -- A Recipe For Death
  .goto 1421,44.2,39.81
  .turnin 99 -- Arugal's Folly
  .turnin 98299 -- Stop the Spread
  .optional 99 -- group quest: Arugal's Folly
step
  .goto 1421,56.76,25.31
  .complete 451,3 -- A Recipe For Death
step
  .goto 1421,65.71,23.67
  .complete 442 -- Assault on Fenris Isle
  .optional 442 -- group quest: Assault on Fenris Isle
step
  .goto 1421,43.42,40.86
  .turnin 442 -- Assault on Fenris Isle
  .optional 442 -- group quest: Assault on Fenris Isle
step
  .goto 1421,69.74,38.3
  .complete 451,1 -- A Recipe For Death
step
  .goto 1421,75.19,20.67
  .complete 451,2 -- A Recipe For Death
step
  .todo "travel from Silverpine Forest to Undercity: the travel graph has no route yet"
  .zone 1458 >> Go to Undercity
]]
)
