-- PLANNED: the thorough alt 3 route for Tauren Druid (HARDCORE): tools/route_planner.py tauren --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"tauren-druid-12-moonglade",
	[[
#chapter 20-22 Moonglade
step
  .goto 1450,56.21,30.64
  .turnin 6126 .class DRUID -- Lessons Anew
  .turnin 26 .class DRUID -- A Lesson to Learn
  .turnin 98340 .class DRUID -- The Great Cat Spirit
  .accept 6127 .class DRUID -- The Principal Source
  .accept 28 .class DRUID -- Trial of the Lake
  .accept 98405 .class DRUID -- The Great Cat Spirit
  .todo "The Principal Source: objective 1 has no position in the pack"
  .complete 6127,1 .class DRUID -- The Principal Source
step
  .goto 1450,36.52,40.1
  .turnin 28 .class DRUID -- Trial of the Lake
  .accept 30 .class DRUID -- Trial of the Sea Lion
  .todo "Trial of the Sea Lion: objective 1 has no position in the pack"
  .complete 30,1 .class DRUID -- Trial of the Sea Lion
step
  .goto 1450,58.39,73.52
  .turnin 98405 .class DRUID -- The Great Cat Spirit
  .accept 98342 .class DRUID -- The Great Cat Spirit
  .note VERIFY(beta): the three relics lie in the Stormrage Barrow Dens (south-east Moonglade). Fan guides say the spirits there attack on sight and the relics are party loot: go in at full health (a statue at the door gives a stealth blessing) and leave if hurt.
step
  .goto 1450,56.21,30.64
  .turnin 30 .class DRUID -- Trial of the Sea Lion
  .accept 31 .class DRUID -- Aquatic Form
  .level 22 -- reach it first: kill or grind on the way
  .note Grind about 19,000 experience before you go on: about 130 kills of creatures near your level (an estimate)
step
  .goto 1450,72.4,66.0
  .complete 98342 .class DRUID -- The Great Cat Spirit
step
  .goto 1450,58.39,73.52
  .turnin 98342 .class DRUID -- The Great Cat Spirit
  .accept 98739 .class DRUID -- Blessings of the Great Cat Spirit
step
  .goto 1450,56.21,30.64
  .turnin 98739 .class DRUID -- Blessings of the Great Cat Spirit
  .accept 98362 .class DRUID -- To Thunder Bluff
step
  .todo "Return from Moonglade to The Barrens: use your hearthstone or a flight path if you have one (VERIFY(beta): the way back is not in the data). This step is done when you arrive in The Barrens."
  .note Do not walk it: from Classic memory (not confirmed in Forever) the road overland runs through Felwood or Winterspring, zones for levels 48 and up, so it is not safe at your level.
  .zone 1413 >> Go to The Barrens
step
  .goto 1413,35.19,27.76
  .turnin 6548 -- Avenge My Village
  .accept 6629 -- Kill Grundig Darkcloud
  .goto 1413,35.26,27.88
  .turnin 1062 -- Goblin Invaders
  .accept 1063 -- The Elder Crone
step
  .goto 1413,44.45,59.15 >> Go to the flight master
  .fly Thunder Bluff
step
  .goto 1456,76.48,27.22
  .turnin 31 .class DRUID -- Aquatic Form
  .turnin 98362 .class DRUID -- To Thunder Bluff
  .goto 1456,69.85,30.91
  .turnin 1063 -- The Elder Crone
  .accept 1064 -- Forsaken Aid
step
  .goto 1456,22.81,20.89
  .turnin 1064 -- Forsaken Aid
  .accept 1065 -- Journey to Tarren Mill
step
  .goto 1456,47.0,49.83 >> Go to the flight master
  .fly Camp Taurajo
step
  .todo "Walk from The Barrens to Stonetalon Mountains: the guide has no waypoints for this yet, so find your own way. This step is done when you arrive in Stonetalon Mountains."
  .zone 1442 >> Go to Stonetalon Mountains
]]
)
