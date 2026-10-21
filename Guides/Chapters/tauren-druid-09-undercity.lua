-- PLANNED: the thorough alt 3 route for Tauren Druid (HARDCORE): tools/route_planner.py tauren --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"tauren-druid-09-undercity",
	[[
#chapter 19-20 Undercity
step
  .goto 1458,73.4,33.0
  .turnin 78143 -- Secrets of the Dreamers
  .turnin 78145 -- Arcanic Systems Manual
  .turnin 79097 -- Baxtan: On Destructive Magics
  .accept 78127 -- The Dalaran Digest
  .accept 78149 -- Fury of the Land
  .accept 78150 -- Friend of the Library
  .turnin 78150 -- Friend of the Library
  .goto 1458,58.61,54.68
  .accept 97891 -- Prompt Potion Runner
step
  .goto 1458,46.61,74.09
  .turnin 97891 -- Prompt Potion Runner
  .goto 1458,45.88,61.7
  .accept 97290 -- Unending Torment
  .goto 1458,48.82,69.28
  .turnin 97290 -- Unending Torment
  .accept 97289 -- Unending Torment
  .accept 97291 -- Unending Torment
step
  .goto 1458,54.0,49.3
  .complete 97291 -- Unending Torment
step
  .goto 1458,45.88,61.7
  .turnin 97289 -- Unending Torment
  .goto 1458,48.82,69.28
  .turnin 97291 -- Unending Torment
step
  .todo "Get from Undercity to The Barrens: they are on different continents, so you need a boat, a zeppelin or another ride, and the guide has no dock for it yet. This step is done when you arrive in The Barrens."
  .zone 1413 >> Go to The Barrens
]]
)
