-- PLANNED: the thorough alt 5 route for Troll Hunter: tools/route_planner.py troll --preset all --install --force --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"troll-hunter-05-silverpine-forest",
	[[
#chapter 13-15 Silverpine Forest
step
  .goto 1421,55.8,19.87
  .complete 421 -- Prove Your Worth
  .complete 91920 -- Wild Eyes
step
  .goto 1421,58.44,34.9
  .turnin 438 -- The Decrepit Ferry
  .accept 439 -- Rot Hide Clues
step
  .goto 1421,59.58,40.99
  .complete 98298 -- Arugal's Folly
step
  .goto 1421,43.42,40.86
  .turnin 439 -- Rot Hide Clues
  .accept 440 -- The Engraved Ring
  .accept 443 -- Rot Hide Ichor
  .goto 1421,42.8,40.86
  .turnin 91920 -- Wild Eyes
  .goto 1421,44.2,39.81
  .turnin 98298 -- Arugal's Folly
  .turnin 421 -- Prove Your Worth
  .accept 422 -- Arugal's Folly
step
  .goto 1421,46.4,25.62
  .complete 429 -- Wild Hearts
step
  .goto 1421,52.83,28.58
  .complete 422 -- Arugal's Folly
step
  .goto 1421,50.78,44.9
  .complete 447,1 -- A Recipe For Death
step
  .goto 1421,49.89,60.33
  .turnin 477 -- Border Crossings
  .accept 478 -- Maps and Runes
step
  .goto 1421,43.98,40.93
  .turnin 478 -- Maps and Runes
  .accept 481 -- Dalar's Analysis
  .goto 1421,42.8,40.86
  .turnin 429 -- Wild Hearts
  .accept 430 -- Return to Quinn
  .goto 1421,44.2,39.81
  .turnin 422 -- Arugal's Folly
  .turnin 481 -- Dalar's Analysis
  .accept 423 -- Arugal's Folly
  .accept 482 -- Dalaran's Intentions
  .turnin 482 -- Dalaran's Intentions
  .accept 479 -- Ambermill Investigations
step
  .goto 1421,43.26,31.68
  .complete 423 -- Arugal's Folly
step
  .goto 1421,53.43,12.59
  .turnin 430 -- Return to Quinn
  .goto 1421,53.46,13.43
  .accept 425 -- Ivar the Foul
step
  .goto 1421,51.52,13.9
  .complete 425 -- Ivar the Foul
step
  .goto 1421,53.46,13.43
  .turnin 425 -- Ivar the Foul
step
  .goto 1421,64.67,23.05
  .complete 443 -- Rot Hide Ichor
step
  .goto 1421,44.2,39.81
  .turnin 423 -- Arugal's Folly
  .accept 424 -- Arugal's Folly
  .goto 1421,42.8,40.86
  .turnin 443 -- Rot Hide Ichor
  .accept 444 -- Rot Hide Origins
  .accept 98299 -- Stop the Spread
  .goto 1421,43.98,40.93
  .accept 95981 -- Watching the Roads
  .goto 1421,43.4,41.2
  .accept 79096 -- Ataeric: On Arcane Curiosities
step
  .goto 1421,58.58,44.86
  .complete 424 -- Arugal's Folly
step
  .goto 1421,44.2,39.81
  .turnin 424 -- Arugal's Folly
  .accept 99 -- Arugal's Folly
  .optional 99 -- group quest: Arugal's Folly
step
  .goto 1421,36.44,14.95
  .complete 447,2 -- A Recipe For Death
step
  .todo "travel from Silverpine Forest to Undercity: the travel graph has no route yet"
  .zone 1458 >> Go to Undercity
]]
)
