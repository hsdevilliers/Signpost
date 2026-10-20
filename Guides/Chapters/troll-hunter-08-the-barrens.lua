-- PLANNED: the thorough alt 5 route for Troll Hunter: tools/route_planner.py troll --preset all --install --force --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"troll-hunter-08-the-barrens",
	[[
#chapter 17-18 The Barrens
step
  .goto 1413,56.3,8.8
  .complete 78145 -- Arcanic Systems Manual
step
  .goto 1413,56.52,7.45
  .accept 858 -- Ignition
step
  .goto 1413,56.27,8.58
  .complete 858 -- Ignition
step
  .goto 1413,56.52,7.45
  .turnin 858 -- Ignition
  .accept 863 -- The Escape
step
  .goto 1413,52.65,29.06
  .accept 97003 -- Chol'aruk the Ravener
step
  .goto 1413,62.37,37.62
  .accept 865 -- Raptor Horns
  .goto 1413,62.59,37.47
  .accept 92706 -- WANTED: Bruuz
  .goto 1413,62.98,37.22
  .turnin 863 -- The Escape
step
  .goto 1413,64.3,39.13
  .complete 92706 -- WANTED: Bruuz
step
  .goto 1413,63.07,36.32
  .accept 97253 -- Parts and Pieces
step
  .goto 1413,62.7,36.3
  .complete 79097 -- Baxtan: On Destructive Magics
step
  .goto 1413,62.68,36.23
  .turnin 92706 -- WANTED: Bruuz
step
  .goto 1413,62.0,45.2
  .complete 97253 -- Parts and Pieces
step
  .goto 1413,63.07,36.32
  .turnin 97253 -- Parts and Pieces
step
  .goto 1413,57.62,27.24
  .complete 97003 -- Chol'aruk the Ravener
step
  .goto 1413,52.65,29.06
  .turnin 97003 -- Chol'aruk the Ravener
step
  .goto 1413,49.3,32.88
  .complete 78143 -- Secrets of the Dreamers
step
  .goto 1413,52.15,46.62
  .complete 865 -- Raptor Horns
step
  .goto 1413,62.37,37.62
  .turnin 865 -- Raptor Horns
step
  .todo "travel from The Barrens to Undercity: the travel graph has no route yet"
  .zone 1458 >> Go to Undercity
]]
)
