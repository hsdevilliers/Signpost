-- PLANNED: the thorough alt 1 route for Tauren Druid (HARDCORE): tools/route_planner.py tauren --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"tauren-druid-09-the-barrens",
	[[
#chapter 21-21 The Barrens
step
  .goto 1413,35.26,27.88
  .turnin 1062 -- Goblin Invaders
  .accept 1063 -- The Elder Crone
  .goto 1413,35.19,27.76
  .turnin 6548 -- Avenge My Village
step
  .goto 1413,52.26,31.93
  .turnin 6127 .class DRUID -- The Principal Source
  .accept 6128 .class DRUID -- Gathering the Cure
step
  .goto 1413,49.3,32.88
  .accept 78143 -- Secrets of the Dreamers
  .complete 78143,1 -- Secrets of the Dreamers
step
  .goto 1413,62.7,36.3
  .accept 79097 -- Baxtan: On Destructive Magics
  .complete 79097,1 -- Baxtan: On Destructive Magics
step
  .todo "Get from The Barrens to Undercity: they are on different continents, so you need a boat, a zeppelin or another ride, and the guide has no dock for it yet. This step is done when you arrive in Undercity."
  .zone 1458 >> Go to Undercity
]]
)
