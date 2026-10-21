-- PLANNED: the thorough alt 1 route for Tauren Druid (HARDCORE): tools/route_planner.py tauren --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"tauren-druid-07-stonetalon-mountains",
	[[
#chapter 19-20 Stonetalon Mountains
step
  .goto 1442,80.76,89.41
  .complete 6548 -- Avenge My Village
step
  .goto 1442,74.54,97.94
  .turnin 1060 -- Letter to Jin'Zil
  .goto 1442,71.25,95.02
  .accept 6461 -- Blood Feeders
step
  .goto 1442,65.36,92.28
  .complete 6461,1 -- Blood Feeders
step
  .goto 1442,66.32,56.51
  .complete 1062 -- Goblin Invaders
  .level 20 -- reach it first: kill or grind on the way
  .note Grind about 150 experience before you go on: about 1 kill of creatures near your level (an estimate)
step
  .goto 1442,62.1,62.82
  .complete 6461,2 -- Blood Feeders
step
  .goto 1442,58.99,62.6
  .accept 1093 -- Super Reaper 6000
step
  .goto 1442,74.4,85.7
  .accept 78149 -- Fury of the Land
  .complete 78149,1 -- Fury of the Land
step
  .goto 1442,71.25,95.02
  .turnin 6461 -- Blood Feeders
step
  .todo "Walk from Stonetalon Mountains to Mulgore: the guide has no waypoints for this yet, so find your own way. This step is done when you arrive in Mulgore."
  .zone 1412 >> Go to Mulgore
step
  .goto 1412,33.39,22.09
  .accept 6126 .class DRUID -- Lessons Anew
  .note Moonglade again: this chain goes back and forth between Thunder Bluff, Moonglade and the Crossroads. VERIFY(beta): the way there and back is unconfirmed (see the note on the first Moonglade quest).
step
  .todo "Walk from Mulgore to Thunder Bluff: the guide has no waypoints for this yet, so find your own way. This step is done when you arrive in Thunder Bluff."
  .zone 1456 >> Go to Thunder Bluff
step
  .goto 1456,76.48,27.22
  .accept 26 .class DRUID -- A Lesson to Learn
  .accept 98340 .class DRUID -- The Great Cat Spirit
  .note Moonglade is a long walk from here. VERIFY(beta): the way there and back is unconfirmed (hearthstone, a flight master at Nighthaven, or Teleport: Moonglade if Forever gives it to druids).
  .goto 1456,78.62,28.56
  .turnin 1489 -- Hamuul Runetotem
  .accept 1490 -- Nara Wildmane
  .goto 1456,75.65,31.61
  .turnin 1490 -- Nara Wildmane
step
  .todo "Walk from Thunder Bluff to Moonglade: the guide has no waypoints for this yet, so find your own way. This step is done when you arrive in Moonglade."
  .zone 1450 >> Go to Moonglade
]]
)
