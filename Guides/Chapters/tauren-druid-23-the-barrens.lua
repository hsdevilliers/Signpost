-- PLANNED: the thorough alt 3 route for Tauren Druid (HARDCORE): tools/route_planner.py tauren --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"tauren-druid-23-the-barrens",
	[[
#chapter 29-30 The Barrens
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
  .goto 1413,45.8,67.81
  .complete 6128,2 .class DRUID -- Gathering the Cure
step
  .goto 1413,44.86,59.14
  .accept 1130 -- Melor Sends Word
step
  .goto 1413,44.45,59.15 >> Go to the flight master
  .fly Thunder Bluff
step
  .goto 1456,61.54,80.92
  .turnin 1130 -- Melor Sends Word
step
  .goto 1456,47.0,49.83 >> Go to the flight master
  .fly Splintertree Post
step
  .goto 1440,70.01,71.16
  .accept 6504 -- The Lost Pages
  .todo "The Lost Pages: objective 1 has no position in the pack"
  .complete 6504,1 -- The Lost Pages
  .todo "The Lost Pages: objective 2 has no position in the pack"
  .complete 6504,2 -- The Lost Pages
  .todo "The Lost Pages: objective 3 has no position in the pack"
  .complete 6504,3 -- The Lost Pages
  .turnin 6504 -- The Lost Pages
  .level 30 -- reach it first: kill or grind on the way
  .note Grind about 18,000 experience before you go on: about 95 kills of creatures near your level (an estimate)
step
  .goto 1440,73.18,61.59 >> Go to the flight master
  .fly Crossroads
step
  .goto 1413,61.49,17.58
  .complete 6128,1 .class DRUID -- Gathering the Cure
step
  .goto 1413,52.26,31.93
  .turnin 6128 .class DRUID -- Gathering the Cure
  .accept 6129 .class DRUID -- Curing the Sick
  .todo "Curing the Sick: objective 1 has no position in the pack"
  .complete 6129,1 .class DRUID -- Curing the Sick
step
  .todo "Go to Moonglade: cast Teleport: Moonglade if you have it (VERIFY(beta): where a druid learns it), else the way is not in the data. This step is done when you arrive in Moonglade."
  .note Do not walk it: from Classic memory (not confirmed in Forever) the road overland runs through Felwood or Winterspring, zones for levels 48 and up, so it is not safe at your level.
  .zone 1450 >> Go to Moonglade
step
  .goto 1450,56.21,30.64
  .turnin 6129 .class DRUID -- Curing the Sick
  .accept 6130 .class DRUID -- Power over Poison
step
  .todo "Return from Moonglade to Thunder Bluff: use your hearthstone or a flight path if you have one (VERIFY(beta): the way back is not in the data). This step is done when you arrive in Thunder Bluff."
  .note Do not walk it: from Classic memory (not confirmed in Forever) the road overland runs through Felwood or Winterspring, zones for levels 48 and up, so it is not safe at your level.
  .zone 1456 >> Go to Thunder Bluff
step
  .goto 1456,76.48,27.22
  .turnin 6130 .class DRUID -- Power over Poison
]]
)
