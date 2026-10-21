-- PLANNED: the thorough route for Tauren Druid (HARDCORE): tools/route_planner.py tauren --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"tauren-druid-12-undercity",
	[[
#chapter 20-21 Undercity
step
  .goto 1458,58.61,54.68
  .accept 97891 -- Prompt Potion Runner
  .goto 1458,45.88,61.7
  .accept 97290 -- Unending Torment
  .goto 1458,48.82,69.28
  .turnin 97290 -- Unending Torment
  .accept 97289 -- Unending Torment
  .accept 97291 -- Unending Torment
step
  .goto 1458,46.31,71.91
  .accept 95216 -- The New Plague
  .todo "The New Plague: objective 1 has no position in the pack"
  .complete 95216,1 -- The New Plague
  .turnin 95216 -- The New Plague
step
  .goto 1458,46.61,74.09
  .turnin 97891 -- Prompt Potion Runner
step
  .goto 1458,54.0,49.3
  .complete 97291 -- Unending Torment
step
  .goto 1458,45.88,61.7
  .turnin 97289 -- Unending Torment
  .goto 1458,48.82,69.28
  .turnin 97291 -- Unending Torment
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
  .goto 1421,44.2,39.81
  .accept 98298 -- Arugal's Folly
  .accept 98299 -- Stop the Spread
  .goto 1421,43.98,40.93
  .accept 95981 -- Watching the Roads
  .accept 516 -- Beren's Peril
step
  .goto 1421,43.42,40.86
  .accept 437 -- The Dead Fields
  .todo "The Dead Fields: objective 1 has no position in the pack"
  .complete 437,1 -- The Dead Fields
  .turnin 437 -- The Dead Fields
  .accept 438 -- The Decrepit Ferry
step
  .goto 1421,43.4,41.2
  .complete 79096 -- Ataeric: On Arcane Curiosities
step
  .goto 1421,44.52,43.02
  .accept 92401 -- A Frightened Request
]]
)
