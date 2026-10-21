-- PLANNED: the thorough alt 4 route for Skyborne Druid (HARDCORE): tools/route_planner.py windshaper --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"windshaper-druid-09-the-barrens",
	[[
#chapter 20-20 The Barrens
step
  .goto 1413,61.06,3.95
  .complete 896 -- Miner's Fortune
step
  .goto 1413,49.05,11.17
  .turnin 3921 -- Wenikee Boltbucket
  .accept 3922 -- Nugget Slugs
step
  .goto 1413,56.37,8.12
  .complete 3922 -- Nugget Slugs
step
  .goto 1413,49.05,11.17
  .turnin 3922 -- Nugget Slugs
  .accept 3923 -- Rilli Greasygob
step
  .goto 1413,39.16,12.17
  .complete 876 -- Serena Bloodfeather
step
  .goto 1413,51.62,30.9
  .turnin 876 -- Serena Bloodfeather
  .accept 1060 -- Letter to Jin'Zil
  .goto 1413,52.65,29.06
  .accept 97003 -- Chol'aruk the Ravener
step
  .todo "travel from The Barrens to Thunder Bluff: the travel graph has no route yet"
  .zone 1456 >> Go to Thunder Bluff
step
  .goto 1456,78.62,28.56
  .turnin 1489 -- Hamuul Runetotem
  .accept 1490 -- Nara Wildmane
  .goto 1456,76.48,27.22
  .level 20
  .accept 98340 .class DRUID -- The Great Cat Spirit
  .goto 1456,75.65,31.61
  .turnin 1490 -- Nara Wildmane
step
  .todo "travel from Thunder Bluff to Moonglade: the travel graph has no route yet"
  .zone 1450 >> Go to Moonglade
]]
)
