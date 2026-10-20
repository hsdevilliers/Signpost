-- PLANNED: the beam route for Troll Hunter, planned by tools/route_planner.py on 2026-10-20 (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"troll-hunter-18-the-barrens",
	[[
#chapter 27-27 The Barrens
step
  .goto 1413,48.97,86.31
  .accept 857 -- The Tear of the Moons
step
  .goto 1413,49.13,84.25
  .complete 857 -- The Tear of the Moons
step
  .goto 1413,48.97,86.31
  .turnin 857 -- The Tear of the Moons
step
  .goto 1413,44.55,59.26
  .turnin 879 -- Betrayal from Within
  .accept 906 -- Betrayal from Within
  .turnin 1153 -- A New Ore Sample
step
  .goto 1413,51.5,30.87
  .turnin 906 -- Betrayal from Within
  .turnin 6365 -- Meats to Orgrimmar
  .accept 97003 -- Chol'aruk the Ravener
step
  .goto 1413,57.62,27.24
  .complete 97003 -- Chol'aruk the Ravener
step
  .goto 1413,52.65,29.06
  .turnin 97003 -- Chol'aruk the Ravener
step
  .goto 1413,46.71,8.68
  .todo "Conquering Arathi Basin: objective 1 has no position in the pack"
  .complete 8370,1 -- Conquering Arathi Basin
  .todo "Battle of Warsong Gulch: objective 1 has no position in the pack"
  .complete 8426,1 -- Battle of Warsong Gulch
  .turnin 8370 -- Conquering Arathi Basin
  .turnin 8426 -- Battle of Warsong Gulch
step
  .todo "border The Barrens/Ashenvale: no crossing coordinates yet (record them in game or in Borders.lua)"
  .zone 1440 >> Go into Ashenvale
]]
)
