-- PLANNED: the thorough alt 5 route for Troll Hunter: tools/route_planner.py troll --preset all --install --force --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"troll-hunter-06-undercity",
	[[
#chapter 15-16 Undercity
step
  .goto 1458,73.4,33.0
  .accept 78127 -- The Dalaran Digest
  .accept 78143 -- Secrets of the Dreamers
  .accept 78145 -- Arcanic Systems Manual
  .accept 78150 -- Friend of the Library
  .accept 79097 -- Baxtan: On Destructive Magics
  .turnin 78150 -- Friend of the Library
step
  .goto 1458,48.82,69.28
  .turnin 447 -- A Recipe For Death
  .accept 450 -- A Recipe For Death
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
  .level 16 -- reach it first: kill or grind on the way
step
  .goto 1458,48.82,69.28
  .accept 97289 -- Unending Torment
  .accept 97291 -- Unending Torment
  .goto 1458,45.88,61.7
  .turnin 97289 -- Unending Torment
  .accept 97290 -- Unending Torment
  .turnin 97290 -- Unending Torment
step
  .todo "travel from Undercity to Orgrimmar: the travel graph has no route yet"
  .zone 1454 >> Go to Orgrimmar
step
  .goto 1454,31.73,37.82
  .todo "Hidden Enemies: objective 1 has no position in the pack"
  .complete 5728,1 -- Hidden Enemies
  .todo "Hidden Enemies: objective 2 has no position in the pack"
  .complete 5728,2 -- Hidden Enemies
  .turnin 5728 -- Hidden Enemies
  .accept 5729 -- Hidden Enemies
  .optional 5728 -- group quest: Hidden Enemies
step
  .goto 1454,49.47,50.59
  .turnin 5729 -- Hidden Enemies
  .accept 5730 -- Hidden Enemies
  .todo "Slaying the Beast: objective 1 has no position in the pack"
  .complete 5761,1 -- Slaying the Beast
  .turnin 5761 -- Slaying the Beast
  .optional 5761 -- group quest: Slaying the Beast
step
  .goto 1454,47.06,46.43
  .accept 65601 -- Love Hurts
]]
)
