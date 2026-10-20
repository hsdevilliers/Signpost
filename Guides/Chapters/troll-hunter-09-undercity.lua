-- PLANNED: the thorough alt 5 route for Troll Hunter: tools/route_planner.py troll --preset all --install --force --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"troll-hunter-09-undercity",
	[[
#chapter 18-20 Undercity
step
  .goto 1458,73.4,33.0
  .turnin 78143 -- Secrets of the Dreamers
  .turnin 78145 -- Arcanic Systems Manual
  .turnin 79097 -- Baxtan: On Destructive Magics
step
  .goto 1458,54.0,49.3
  .complete 97291 -- Unending Torment
step
  .goto 1458,48.82,69.28
  .turnin 97291 -- Unending Torment
step
  .goto 1458,46.31,71.91
  .accept 95216 -- The New Plague
  .todo "The New Plague: objective 1 has no position in the pack"
  .complete 95216,1 -- The New Plague
  .turnin 95216 -- The New Plague
step
  .goto 1458,58.08,89.51
  .accept 92421 -- Light's Justice
  .todo "Light's Justice: objective 1 has no position in the pack"
  .complete 92421,1 -- Light's Justice
  .turnin 92421 -- Light's Justice
step
  .todo "travel from Undercity to Silverpine Forest: the travel graph has no route yet"
  .zone 1421 >> Go to Silverpine Forest
step
  .goto 1421,65.8,50.67
  .complete 95981 -- Watching the Roads
step
  .goto 1421,61.96,62.8
  .complete 479 -- Ambermill Investigations
step
  .goto 1421,44.52,43.02
  .accept 92401 -- A Frightened Request
  .goto 1421,43.98,40.93
  .turnin 479 -- Ambermill Investigations
  .turnin 95981 -- Watching the Roads
  .accept 480 -- The Weaver
  .accept 516 -- Beren's Peril
step
  .goto 1421,43.4,41.2
  .complete 79096 -- Ataeric: On Arcane Curiosities
]]
)
