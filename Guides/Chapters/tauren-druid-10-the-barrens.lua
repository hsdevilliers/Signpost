-- PLANNED: the thorough route for Tauren Druid (HARDCORE): tools/route_planner.py tauren --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"tauren-druid-10-the-barrens",
	[[
#chapter 19-20 The Barrens
step
  .goto 1413,44.86,59.14
  .turnin 3261 -- Jorn Skyseer
  .accept 882 -- Ishamuhale
  .todo "Ishamuhale: objective 1 has no position in the pack"
  .complete 882,1 -- Ishamuhale
  .turnin 882 -- Ishamuhale
  .accept 907 -- Enraged Thunder Lizards
step
  .goto 1413,51.95,31.58
  .turnin 899 -- Consumed by Hatred
  .turnin 4921 -- Lost in Battle
  .turnin 95774 -- Her Name Is Olgra
step
  .goto 1413,62.37,37.62
  .turnin 1491 -- Smart Drinks
  .goto 1413,62.7,36.3
  .accept 79097 -- Baxtan: On Destructive Magics
  .complete 79097,1 -- Baxtan: On Destructive Magics
step
  .goto 1413,63.28,32.08
  .complete 6128,1 .class DRUID -- Gathering the Cure
step
  .goto 1413,54.82,40.13
  .complete 6128,2 .class DRUID -- Gathering the Cure
step
  .goto 1413,52.26,31.93
  .turnin 6128 .class DRUID -- Gathering the Cure
  .accept 6129 .class DRUID -- Curing the Sick
  .todo "Curing the Sick: objective 1 has no position in the pack"
  .complete 6129,1 .class DRUID -- Curing the Sick
step
  .goto 1413,51.62,30.9
  .accept 876 -- Serena Bloodfeather
step
  .goto 1413,49.3,32.88
  .accept 78143 -- Secrets of the Dreamers
  .complete 78143,1 -- Secrets of the Dreamers
step
  .goto 1413,35.19,27.76
  .turnin 6629 -- Kill Grundig Darkcloud
step
  .todo "travel from The Barrens to Thunder Bluff: the travel graph has no route yet"
  .zone 1456 >> Go to Thunder Bluff
]]
)
