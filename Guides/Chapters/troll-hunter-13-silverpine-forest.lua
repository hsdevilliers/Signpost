-- PLANNED: the thorough alt 4 route for Troll Hunter: tools/route_planner.py troll --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"troll-hunter-13-silverpine-forest",
	[[
#chapter 22-22 Silverpine Forest
step
  .goto 1421,63.4,64.27
  .complete 480 -- The Weaver
step
  .goto 1421,43.98,40.93
  .turnin 480 -- The Weaver
step
  .goto 1421,65.71,23.67
  .complete 442 -- Assault on Fenris Isle
  .optional 442 -- group quest: Assault on Fenris Isle
step
  .goto 1421,43.42,40.86
  .turnin 442 -- Assault on Fenris Isle
  .optional 442 -- group quest: Assault on Fenris Isle
step
  .todo "Walk from Silverpine Forest to Tirisfal Glades: the guide has no waypoints for this yet, so find your own way. This step is done when you arrive in Tirisfal Glades."
  .zone 1420 >> Go to Tirisfal Glades
step
  .goto 1420,65.25,60.2
  .accept 92422 -- The Wrath of Rath'mael
  .todo "The Wrath of Rath'mael: objective 1 has no position in the pack"
  .complete 92422,1 -- The Wrath of Rath'mael
  .turnin 92422 -- The Wrath of Rath'mael
step
  .todo "Get from Tirisfal Glades to The Barrens: they are on different continents, so you need a boat, a zeppelin or another ride, and the guide has no dock for it yet. This step is done when you arrive in The Barrens."
  .zone 1413 >> Go to The Barrens
]]
)
