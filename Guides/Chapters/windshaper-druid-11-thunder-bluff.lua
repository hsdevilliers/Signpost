-- PLANNED: the thorough alt 5 route for Skyborne Druid (HARDCORE): tools/route_planner.py windshaper --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"windshaper-druid-11-thunder-bluff",
	[[
#chapter 21-22 Thunder Bluff
step
  .goto 1456,76.48,27.22
  .turnin 98362 .class DRUID -- To Thunder Bluff
step
  .todo "travel from Thunder Bluff to The Barrens: the travel graph has no route yet"
  .zone 1413 >> Go to The Barrens
step
  .goto 1413,35.19,27.76
  .turnin 6523 -- Protect Kaya
step
  .goto 1413,51.07,29.63
  .accept 868 -- Egg Hunt
  .goto 1413,51.95,31.58
  .accept 899 -- Consumed by Hatred
  .accept 4921 -- Lost in Battle
  .accept 95774 -- Her Name Is Olgra
  .goto 1413,52.65,29.06
  .accept 97003 -- Chol'aruk the Ravener
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
  .goto 1413,49.33,50.32
  .complete 4921 -- Lost in Battle
  .complete 899 -- Consumed by Hatred
  .complete 95774 -- Her Name Is Olgra
]]
)
