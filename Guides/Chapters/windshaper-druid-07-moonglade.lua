-- PLANNED: the thorough alt 2 route for Skyborne Druid (HARDCORE): tools/route_planner.py windshaper --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"windshaper-druid-07-moonglade",
	[[
#chapter 24-25 Moonglade
step
  .goto 1450,56.21,30.64
  .turnin 94913 .class DRUID -- Moonglade
  .turnin 98340 .class DRUID -- The Great Cat Spirit
  .accept 98341 .class DRUID -- The Great Windborne Cat Spirit
step
  .goto 1450,43.92,73.44
  .turnin 98341 .class DRUID -- The Great Windborne Cat Spirit
  .accept 98404 .class DRUID -- The Great Windborne Cat Spirit
  .note VERIFY(beta): the three relics lie in the Stormrage Barrow Dens, east Moonglade (the data puts Fang near 72,66, Claw near 75,67 and Silent Shadow near 74,65). Fan guides say the spirits there attack on sight and the relics are party loot; a statue at the door gives a stealth blessing. Go in at full health and leave if hurt.
  .todo "The Great Windborne Cat Spirit: objective 1 is only in places this guide does not go"
  .complete 98404,1 .class DRUID -- The Great Windborne Cat Spirit
  .todo "The Great Windborne Cat Spirit: objective 2 is only in places this guide does not go"
  .complete 98404,2 .class DRUID -- The Great Windborne Cat Spirit
  .todo "The Great Windborne Cat Spirit: objective 3 is only in places this guide does not go"
  .complete 98404,3 .class DRUID -- The Great Windborne Cat Spirit
  .turnin 98404 .class DRUID -- The Great Windborne Cat Spirit
  .accept 98738 .class DRUID -- Blessings of the Great Windborne Cat Spirit
step
  .goto 1450,56.21,30.64
  .turnin 98738 .class DRUID -- Blessings of the Great Windborne Cat Spirit
  .accept 98362 .class DRUID -- To Thunder Bluff
  .level 25 -- reach it first: kill or grind on the way
  .note Grind about 2,300 experience before you go on: about 14 kills of creatures near your level (an estimate)
step
  .todo "Walk from Moonglade to Stonetalon Mountains: the guide has no waypoints for this yet, so find your own way. This step is done when you arrive in Stonetalon Mountains."
  .zone 1442 >> Go to Stonetalon Mountains
]]
)
