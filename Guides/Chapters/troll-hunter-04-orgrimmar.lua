-- PLANNED: the beam route for Troll Hunter: tools/route_planner.py troll --preset all --install --force --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"troll-hunter-04-orgrimmar",
	[[
#chapter 16-16 Orgrimmar
step
  .goto 1454,54.1,68.41
  .turnin 6384 -- Ride to Orgrimmar
  .accept 6385 -- Doras the Wind Rider Master
step
  .goto 1454,49.47,50.59
  .todo "Slaying the Beast: objective 1 has no position in the pack"
  .complete 5761,1 -- Slaying the Beast
  .turnin 5761 -- Slaying the Beast
  .optional 5761 -- group quest: Slaying the Beast
step
  .goto 1454,45.12,63.89
  .turnin 6385 -- Doras the Wind Rider Master
step
  .goto 1454,43.9,40.2
  .complete 97326 -- Rocks to Rests
step
  .goto 1454,36.82,29.06
  .turnin 97326 -- Rocks to Rests
step
  .goto 1454,66.0,28.4
  .complete 97242 -- Yelmak's Medley
step
  .goto 1454,56.05,34.12
  .turnin 97242 -- Yelmak's Medley
step
  .todo "Get from Orgrimmar to Undercity: they are on different continents, so you need a boat, a zeppelin or another ride, and the guide has no dock for it yet. This step is done when you arrive in Undercity."
  .zone 1458 >> Go to Undercity
]]
)
