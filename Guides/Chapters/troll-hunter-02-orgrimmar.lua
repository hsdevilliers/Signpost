-- PLANNED: the beam route for Troll Hunter: tools/route_planner.py troll --preset all --install --force --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"troll-hunter-02-orgrimmar",
	[[
#chapter 10-11 Orgrimmar
step
  .goto 1454,57.2,53.32
  .accept 97249 -- Favorite Food
  .goto 1454,56.05,34.12
  .accept 97242 -- Yelmak's Medley
  .goto 1454,56.84,33.03
  .accept 97275 -- Whuut's the Rush
  .goto 1454,55.79,32.9
  .turnin 97275 -- Whuut's the Rush
step
  .goto 1454,66.05,18.53
  .turnin 6081 .class HUNTER -- Training the Beast
step
  .goto 1454,36.82,29.06
  .accept 97326 -- Rocks to Rests
  .goto 1454,36.53,29.06
  .turnin 97249 -- Favorite Food
step
  .goto 1454,49.47,50.59
  .accept 5761 -- Slaying the Beast
  .optional 5761 -- group quest: Slaying the Beast
  .goto 1454,55.68,72.17
  .accept 97246 -- Meal Appeal
  .goto 1454,57.2,53.32
  .turnin 97246 -- Meal Appeal
step
  .goto 1454,45.12,63.89 >> Go to the flight master
  .fp 1454,Orgrimmar
step
  .todo "Walk from Orgrimmar to Durotar: the guide has no waypoints for this yet, so find your own way. This step is done when you arrive in Durotar."
  .zone 1411 >> Go to Durotar
step
  .goto 1411,59.22,17.6
  .complete 99052 -- Threat from Below
step
  .goto 1411,52.24,43.15
  .turnin 99052 -- Threat from Below
step
  .todo "Walk from Durotar to The Barrens: the guide has no waypoints for this yet, so find your own way. This step is done when you arrive in The Barrens."
  .zone 1413 >> Go to The Barrens
]]
)
