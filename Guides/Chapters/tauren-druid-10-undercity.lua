-- PLANNED: the thorough alt 1 route for Tauren Druid (HARDCORE): tools/route_planner.py tauren --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"tauren-druid-10-undercity",
	[[
#chapter 21-22 Undercity
step
  .goto 1458,48.82,69.28
  .accept 97289 -- Unending Torment
  .accept 97291 -- Unending Torment
step
  .goto 1458,46.31,71.91
  .accept 95216 -- The New Plague
  .todo "The New Plague: objective 1 has no position in the pack"
  .complete 95216,1 -- The New Plague
  .turnin 95216 -- The New Plague
step
  .goto 1458,45.88,61.7
  .turnin 97289 -- Unending Torment
  .accept 97290 -- Unending Torment
step
  .goto 1458,54.0,49.3
  .complete 97291 -- Unending Torment
step
  .goto 1458,63.25,48.56 >> Go to the flight master
  .fp 1458,Undercity
step
  .goto 1458,58.61,54.68
  .accept 97891 -- Prompt Potion Runner
  .goto 1458,48.82,69.28
  .turnin 97290 -- Unending Torment
  .turnin 97291 -- Unending Torment
  .goto 1458,46.61,74.09
  .turnin 97891 -- Prompt Potion Runner
  .goto 1458,73.4,33.0
  .turnin 78143 -- Secrets of the Dreamers
  .turnin 78149 -- Fury of the Land
  .turnin 79097 -- Baxtan: On Destructive Magics
  .accept 78127 -- The Dalaran Digest
  .accept 78150 -- Friend of the Library
  .accept 79096 -- Ataeric: On Arcane Curiosities
  .turnin 78150 -- Friend of the Library
step
  .goto 1458,58.08,89.51
  .accept 92421 -- Light's Justice
  .todo "Light's Justice: objective 1 has no position in the pack"
  .complete 92421,1 -- Light's Justice
  .turnin 92421 -- Light's Justice
step
  .todo "Walk from Undercity to Silverpine Forest: the guide has no waypoints for this yet, so find your own way. This step is done when you arrive in Silverpine Forest."
  .zone 1421 >> Go to Silverpine Forest
]]
)
