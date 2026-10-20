-- PLANNED: the thorough alt 5 route for Troll Hunter: tools/route_planner.py troll --preset all --install --force --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"troll-hunter-16-ashenvale",
	[[
#chapter 26-27 Ashenvale
step
  .goto 1440,40.43,61.48
  .accept 98251 -- Never Coming Back
  .accept 98252 -- A Void Path
  .goto 1440,38.23,58.15
  .turnin 98252 -- A Void Path
step
  .goto 1440,39.52,70.3
  .complete 98251 -- Never Coming Back
step
  .goto 1440,40.43,61.48
  .turnin 98251 -- Never Coming Back
step
  .goto 1440,41.53,34.49
  .accept 6482 -- Freedom to Ruul
step
  .goto 1440,73.06,61.48
  .accept 6441 -- Satyr Horns
  .goto 1440,74.11,60.92
  .turnin 6482 -- Freedom to Ruul
step
  .goto 1440,67.12,56.41
  .complete 6441 -- Satyr Horns
step
  .goto 1440,73.06,61.48
  .turnin 6441 -- Satyr Horns
step
  .goto 1440,71.11,68.12
  .accept 6503 -- Ashenvale Outrunners
  .goto 1440,70.01,71.16
  .accept 6504 -- The Lost Pages
step
  .goto 1440,72.87,70.18
  .complete 6503 -- Ashenvale Outrunners
step
  .goto 1440,71.11,68.12
  .turnin 6503 -- Ashenvale Outrunners
step
  .goto 1440,70.01,71.16
  .todo "The Lost Pages: objective 1 has no position in the pack"
  .complete 6504,1 -- The Lost Pages
  .todo "The Lost Pages: objective 2 has no position in the pack"
  .complete 6504,2 -- The Lost Pages
  .todo "The Lost Pages: objective 3 has no position in the pack"
  .complete 6504,3 -- The Lost Pages
  .turnin 6504 -- The Lost Pages
step
  .goto 1440,68.34,75.3
  .accept 6544 -- Torek's Assault
step
  .goto 1440,73.03,62.47
  .turnin 6544 -- Torek's Assault
step
  .todo "travel from Ashenvale to Thunder Bluff: the travel graph has no route yet"
  .zone 1456 >> Go to Thunder Bluff
]]
)
