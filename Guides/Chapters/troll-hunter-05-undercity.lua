-- PLANNED: the beam route for Troll Hunter: tools/route_planner.py troll --preset all --install --force --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"troll-hunter-05-undercity",
	[[
#chapter 16-17 Undercity
step
  .goto 1458,48.82,69.28
  .level 16
  .accept 97289 -- Unending Torment
  .accept 97291 -- Unending Torment
  .goto 1458,45.88,61.7
  .turnin 97289 -- Unending Torment
  .accept 97290 -- Unending Torment
  .goto 1458,58.61,54.68
  .accept 97891 -- Prompt Potion Runner
  .turnin 97290 -- Unending Torment
  .goto 1458,46.31,71.91
  .accept 95216 -- The New Plague
  .goto 1458,46.61,74.09
  .turnin 97891 -- Prompt Potion Runner
step
  .goto 1458,63.25,48.56 >> Go to the flight master
  .fp 1458,Undercity
step
  .goto 1458,73.4,33.0
  .accept 78127 -- The Dalaran Digest
  .accept 78150 -- Friend of the Library
  .accept 79096 -- Ataeric: On Arcane Curiosities
  .turnin 78150 -- Friend of the Library
step
  .goto 1458,58.08,89.51
  .accept 92421 -- Light's Justice
step
  .goto 1458,56.25,92.2
  .accept 5725 -- The Power to Destroy...
  .todo "The Power to Destroy...: objective 1 has no position in the pack"
  .complete 5725,1 -- The Power to Destroy...
  .todo "The Power to Destroy...: objective 2 has no position in the pack"
  .complete 5725,2 -- The Power to Destroy...
  .turnin 5725 -- The Power to Destroy...
  .optional 5725 -- group quest: The Power to Destroy...
step
  .todo "Walk from Undercity to Silverpine Forest: the guide has no waypoints for this yet, so find your own way. This step is done when you arrive in Silverpine Forest."
  .zone 1421 >> Go to Silverpine Forest
]]
)
