-- PLANNED: the thorough alt 1 route for Tauren Druid (HARDCORE): tools/route_planner.py tauren --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"tauren-druid-22-the-barrens",
	[[
#chapter 30-30 The Barrens
step
  .goto 1413,40.85,29.59
  .complete 6128,1 .class DRUID -- Gathering the Cure
step
  .goto 1413,45.77,43.34
  .complete 6128,2 .class DRUID -- Gathering the Cure
step
  .goto 1413,52.26,31.93
  .turnin 6128 .class DRUID -- Gathering the Cure
  .accept 6129 .class DRUID -- Curing the Sick
  .todo "Curing the Sick: objective 1 has no position in the pack"
  .complete 6129,1 .class DRUID -- Curing the Sick
step
  .todo "Walk from The Barrens to Moonglade: the guide has no waypoints for this yet, so find your own way. This step is done when you arrive in Moonglade."
  .zone 1450 >> Go to Moonglade
step
  .goto 1450,56.21,30.64
  .turnin 6129 .class DRUID -- Curing the Sick
  .accept 6130 .class DRUID -- Power over Poison
step
  .todo "Walk from Moonglade to Thunder Bluff: the guide has no waypoints for this yet, so find your own way. This step is done when you arrive in Thunder Bluff."
  .zone 1456 >> Go to Thunder Bluff
step
  .goto 1456,76.48,27.22
  .turnin 6130 .class DRUID -- Power over Poison
]]
)
