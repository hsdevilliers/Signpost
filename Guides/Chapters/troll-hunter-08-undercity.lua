-- PLANNED: the thorough alt 1 route for Troll Hunter: tools/route_planner.py troll --preset all --install --force --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"troll-hunter-08-undercity",
	[[
#chapter 17-18 Undercity
step
  .goto 1458,73.4,33.0
  .turnin 78127 -- The Dalaran Digest
  .turnin 79096 -- Ataeric: On Arcane Curiosities
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
  .goto 1458,46.31,71.91
  .accept 95216 -- The New Plague
step
  .goto 1458,54.0,49.3
  .complete 97291 -- Unending Torment
step
  .goto 1458,48.82,69.28
  .turnin 97291 -- Unending Torment
step
  .todo "travel from Undercity to Silverpine Forest: the travel graph has no route yet"
  .zone 1421 >> Go to Silverpine Forest
step
  .goto 1421,65.89,23.86
  .complete 443 -- Rot Hide Ichor
step
  .goto 1421,43.98,40.93
  .turnin 479 -- Ambermill Investigations
  .accept 480 -- The Weaver
  .goto 1421,42.8,40.86
  .turnin 443 -- Rot Hide Ichor
  .accept 444 -- Rot Hide Origins
step
  .goto 1421,63.51,58.13
  .complete 95981 -- Watching the Roads
]]
)
