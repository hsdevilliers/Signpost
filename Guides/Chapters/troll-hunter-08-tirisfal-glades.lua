-- PLANNED: the beam route for Troll Hunter: tools/route_planner.py troll --preset all --install --force --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"troll-hunter-08-tirisfal-glades",
	[[
#chapter 18-19 Tirisfal Glades
step
  .goto 1420,61.5,53.5
  .accept 96895 -- The Argent Emissary
  .goto 1420,61.26,50.84
  .turnin 440 -- The Engraved Ring
  .accept 441 -- Raleigh and the Undercity
step
  .goto 1420,65.25,60.2
  .accept 92422 -- The Wrath of Rath'mael
  .goto 1420,65.93,61.13
  .turnin 96895 -- The Argent Emissary
  .accept 96897 -- The Cult of the Damned
  .accept 96898 -- Remnants of War
step
  .goto 1420,67.15,62.59
  .complete 96897 -- The Cult of the Damned
  .complete 96898 -- Remnants of War
step
  .goto 1420,65.93,61.13
  .turnin 96897 -- The Cult of the Damned
  .turnin 96898 -- Remnants of War
step
  .goto 1420,65.25,60.2
  .todo "The Wrath of Rath'mael: objective 1 has no position in the pack"
  .complete 92422,1 -- The Wrath of Rath'mael
  .turnin 92422 -- The Wrath of Rath'mael
step
  .todo "Walk from Tirisfal Glades to Undercity: the guide has no waypoints for this yet, so find your own way. This step is done when you arrive in Undercity."
  .zone 1458 >> Go to Undercity
]]
)
