-- PLANNED: the beam route for Troll Hunter, planned by tools/route_planner.py on 2026-10-20 (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"troll-hunter-13-ashenvale",
	[[
#chapter 23-24 Ashenvale
step
  .goto 1440,11.69,34.91
  .accept 6442 -- Naga at the Zoram Strand
  .accept 216 -- Between a Rock and a Thistlefur
  .accept 6641 -- Vorsha the Lasher
  .turnin 6641 -- Vorsha the Lasher
  .turnin 6562 -- Trouble in the Deeps
step
  .goto 1440,11.25,31.02
  .complete 6442 -- Naga at the Zoram Strand
step
  .goto 1440,11.69,34.91
  .turnin 6442 -- Naga at the Zoram Strand
step
  .goto 1440,31.74,38.0
  .complete 216 -- Between a Rock and a Thistlefur
step
  .goto 1440,11.9,34.54
  .turnin 216 -- Between a Rock and a Thistlefur
  .accept 6621 -- King of the Foulweald
  .todo "King of the Foulweald: objective 1 has no position in the pack"
  .complete 6621,1 -- King of the Foulweald
  .turnin 6621 -- King of the Foulweald
step
  .goto 1440,41.53,34.49
  .accept 6482 -- Freedom to Ruul
step
  .goto 1440,73.06,61.48
  .accept 6441 -- Satyr Horns
  .turnin 6482 -- Freedom to Ruul
step
  .goto 1440,71.4,67.63
  .accept 6571 -- Warsong Supplies
  .accept 6503 -- Ashenvale Outrunners
step
  .goto 1440,72.87,70.18
  .complete 6503 -- Ashenvale Outrunners
step
  .goto 1440,71.11,68.12
  .turnin 6503 -- Ashenvale Outrunners
step
  .goto 1440,68.34,75.3
  .accept 6544 -- Torek's Assault
step
  .goto 1440,73.03,62.47
  .turnin 6544 -- Torek's Assault
step
  .goto 1440,67.12,56.41
  .complete 6441 -- Satyr Horns
  .complete 6571,3 -- Warsong Supplies
step
  .goto 1440,73.06,61.48
  .turnin 6441 -- Satyr Horns
step
  .goto 1440,57.59,63.99
  .complete 6571,4 -- Warsong Supplies
step
  .goto 1440,71.4,67.63
  .todo "Warsong Supplies: objective 1 has no position in the pack"
  .complete 6571,1 -- Warsong Supplies
  .todo "Warsong Supplies: objective 2 has no position in the pack"
  .complete 6571,2 -- Warsong Supplies
  .turnin 6571 -- Warsong Supplies
step
  .todo "border The Barrens/Ashenvale: no crossing coordinates yet (record them in game or in Borders.lua)"
  .zone 1413 >> Go into The Barrens
]]
)
