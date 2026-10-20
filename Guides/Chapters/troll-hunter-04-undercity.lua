-- PLANNED: the thorough alt 5 route for Troll Hunter: tools/route_planner.py troll --preset all --install --force --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"troll-hunter-04-undercity",
	[[
#chapter 12-13 Undercity
step
  .goto 1458,58.61,54.68
  .accept 97891 -- Prompt Potion Runner
  .goto 1458,46.61,74.09
  .turnin 97891 -- Prompt Potion Runner
step
  .todo "travel from Undercity to Silverpine Forest: the travel graph has no route yet"
  .zone 1421 >> Go to Silverpine Forest
step
  .goto 1421,56.18,9.18
  .accept 435 -- Escorting Erland
  .goto 1421,53.43,12.59
  .accept 91920 -- Wild Eyes
  .goto 1421,53.46,13.43
  .turnin 435 -- Escorting Erland
  .accept 449 -- The Deathstalkers' Report
step
  .goto 1421,44.2,39.81
  .accept 98298 -- Arugal's Folly
  .accept 421 -- Prove Your Worth
  .goto 1421,43.98,40.93
  .accept 477 -- Border Crossings
step
  .goto 1421,43.42,40.86
  .turnin 449 -- The Deathstalkers' Report
  .accept 428 -- Lost Deathstalkers
  .accept 437 -- The Dead Fields
  .accept 3221 -- Speak with Renferrel
  .todo "The Dead Fields: objective 1 has no position in the pack"
  .complete 437,1 -- The Dead Fields
  .turnin 437 -- The Dead Fields
  .accept 438 -- The Decrepit Ferry
step
  .goto 1421,42.8,40.86
  .turnin 3221 -- Speak with Renferrel
  .accept 447 -- A Recipe For Death
  .accept 91921 -- Return to Quinn (Again)
step
  .goto 1421,53.46,13.43
  .turnin 428 -- Lost Deathstalkers
  .accept 429 -- Wild Hearts
  .goto 1421,53.43,12.59
  .turnin 91921 -- Return to Quinn (Again)
]]
)
