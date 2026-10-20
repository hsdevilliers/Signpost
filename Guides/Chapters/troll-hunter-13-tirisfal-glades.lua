-- PLANNED: the thorough alt 5 route for Troll Hunter: tools/route_planner.py troll --preset all --install --force --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"troll-hunter-13-tirisfal-glades",
	[[
#chapter 23-25 Tirisfal Glades
step
  .goto 1420,65.25,60.2
  .accept 92422 -- The Wrath of Rath'mael
  .todo "The Wrath of Rath'mael: objective 1 has no position in the pack"
  .complete 92422,1 -- The Wrath of Rath'mael
  .turnin 92422 -- The Wrath of Rath'mael
step
  .goto 1420,61.26,50.84
  .turnin 440 -- The Engraved Ring
  .accept 441 -- Raleigh and the Undercity
step
  .todo "travel from Tirisfal Glades to Undercity: the travel graph has no route yet"
  .zone 1458 >> Go to Undercity
step
  .goto 1458,62.01,42.75
  .turnin 441 -- Raleigh and the Undercity
step
  .goto 1458,53.74,54.46
  .todo "The Book of Ur: objective 1 has no position in the pack"
  .complete 1013,1 -- The Book of Ur
  .turnin 1013 -- The Book of Ur
step
  .todo "travel from Undercity to Silverpine Forest: the travel graph has no route yet"
  .zone 1421 >> Go to Silverpine Forest
step
  .level 24 -- reach it first: kill or grind on the way
step
  .goto 1421,44.2,39.81
  .accept 1014 -- Arugal Must Die
  .todo "Arugal Must Die: objective 1 has no position in the pack"
  .complete 1014,1 -- Arugal Must Die
  .turnin 1014 -- Arugal Must Die
  .optional 1014 -- group quest: Arugal Must Die
step
  .todo "travel from Silverpine Forest to Ashenvale: the travel graph has no route yet"
  .zone 1440 >> Go to Ashenvale
step
  .level 25 -- reach it first: kill or grind on the way
step
  .goto 1440,11.69,34.91
  .accept 6442 -- Naga at the Zoram Strand
  .goto 1440,11.9,34.54
  .accept 216 -- Between a Rock and a Thistlefur
  .goto 1440,12.06,34.63
  .accept 6641 -- Vorsha the Lasher
  .goto 1440,12.22,34.22
  .turnin 6641 -- Vorsha the Lasher
step
  .goto 1440,11.56,34.29
  .accept 6921 -- Amongst the Ruins
  .todo "Amongst the Ruins: objective 1 has no position in the pack"
  .complete 6921,1 -- Amongst the Ruins
  .turnin 6921 -- Amongst the Ruins
]]
)
