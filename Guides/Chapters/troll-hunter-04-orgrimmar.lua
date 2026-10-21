-- PLANNED: the thorough alt 4 route for Troll Hunter: tools/route_planner.py troll --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"troll-hunter-04-orgrimmar",
	[[
#chapter 12-14 Orgrimmar
step
  .goto 1454,70.4,34.1
  .complete 97242 -- Yelmak's Medley
step
  .goto 1454,56.05,34.12
  .turnin 97242 -- Yelmak's Medley
step
  .goto 1454,44.5,38.3
  .complete 97326 -- Rocks to Rests
step
  .goto 1454,36.82,29.06
  .turnin 97326 -- Rocks to Rests
step
  .goto 1454,31.73,37.82
  .turnin 5726 -- Hidden Enemies
  .accept 5727 -- Hidden Enemies
  .complete 5727,1 -- Hidden Enemies
  .note Hidden Enemies: event: the quest finishes when something happens here (an ambush, a ritual); read the quest log
  .turnin 5727 -- Hidden Enemies
  .accept 5728 -- Hidden Enemies
  .todo "Hidden Enemies: objective 1 has no position in the pack"
  .complete 5728,1 -- Hidden Enemies
  .todo "Hidden Enemies: objective 2 has no position in the pack"
  .complete 5728,2 -- Hidden Enemies
  .turnin 5728 -- Hidden Enemies
  .accept 5729 -- Hidden Enemies
  .optional 5728 -- group quest: Hidden Enemies
step
  .goto 1454,49.47,50.59
  .turnin 829 -- Neeru Fireblade
  .turnin 5729 -- Hidden Enemies
  .accept 809 -- Ak'Zeloth
  .accept 5730 -- Hidden Enemies
  .accept 5761 -- Slaying the Beast
  .todo "Slaying the Beast: objective 1 has no position in the pack"
  .complete 5761,1 -- Slaying the Beast
  .turnin 5761 -- Slaying the Beast
  .optional 5761 -- group quest: Slaying the Beast
step
  .goto 1454,31.73,37.82
  .turnin 5730 -- Hidden Enemies
step
  .todo "Walk from Orgrimmar to The Barrens: the guide has no waypoints for this yet, so find your own way. This step is done when you arrive in The Barrens."
  .zone 1413 >> Go to The Barrens
]]
)
