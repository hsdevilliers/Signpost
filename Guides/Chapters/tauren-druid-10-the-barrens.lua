-- PLANNED: the thorough alt 4 route for Tauren Druid (HARDCORE): tools/route_planner.py tauren --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"tauren-druid-10-the-barrens",
	[[
#chapter 19-20 The Barrens
step
  .goto 1413,49.3,32.88
  .accept 78143 -- Secrets of the Dreamers
  .complete 78143,1 -- Secrets of the Dreamers
step
  .goto 1413,54.82,40.13
  .complete 6128,2 .class DRUID -- Gathering the Cure
step
  .goto 1413,62.59,37.47
  .accept 92706 -- WANTED: Bruuz
  .goto 1413,62.7,36.3
  .accept 79097 -- Baxtan: On Destructive Magics
  .complete 79097,1 -- Baxtan: On Destructive Magics
step
  .goto 1413,63.28,32.08
  .complete 6128,1 .class DRUID -- Gathering the Cure
step
  .goto 1413,52.26,31.93
  .turnin 6128 .class DRUID -- Gathering the Cure
  .accept 6129 .class DRUID -- Curing the Sick
  .todo "Curing the Sick: objective 1 has no position in the pack"
  .complete 6129,1 .class DRUID -- Curing the Sick
step
  .todo "travel from The Barrens to Undercity: the travel graph has no route yet"
  .zone 1458 >> Go to Undercity
step
  .goto 1458,73.4,33.0
  .turnin 78143 -- Secrets of the Dreamers
  .turnin 78145 -- Arcanic Systems Manual
  .turnin 79094 -- The Lessons of Ta'zo
  .turnin 79097 -- Baxtan: On Destructive Magics
  .accept 78127 -- The Dalaran Digest
  .accept 78150 -- Friend of the Library
  .turnin 78150 -- Friend of the Library
  .goto 1458,58.61,54.68
  .accept 97891 -- Prompt Potion Runner
step
  .goto 1458,45.88,61.7
  .accept 97290 -- Unending Torment
  .goto 1458,48.82,69.28
  .turnin 97290 -- Unending Torment
  .accept 97289 -- Unending Torment
  .accept 97291 -- Unending Torment
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
  .todo "travel from Undercity to Thunder Bluff: the travel graph has no route yet"
  .zone 1456 >> Go to Thunder Bluff
]]
)
