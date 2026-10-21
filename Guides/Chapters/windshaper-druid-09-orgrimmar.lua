-- PLANNED: the thorough alt 5 route for Skyborne Druid (HARDCORE): tools/route_planner.py windshaper --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"windshaper-druid-09-orgrimmar",
	[[
#chapter 20-21 Orgrimmar
step
  .goto 1454,31.73,37.82
  .turnin 5726 -- Hidden Enemies
  .accept 5727 -- Hidden Enemies
  .turnin 5727 -- Hidden Enemies
step
  .todo "travel from Orgrimmar to The Barrens: the travel graph has no route yet"
  .zone 1413 >> Go to The Barrens
step
  .goto 1413,48.12,5.42
  .accept 6543 -- The Warsong Reports
  .todo "The Warsong Reports: objective 1 has no position in the pack"
  .complete 6543,1 -- The Warsong Reports
  .todo "The Warsong Reports: objective 2 has no position in the pack"
  .complete 6543,2 -- The Warsong Reports
  .todo "The Warsong Reports: objective 3 has no position in the pack"
  .complete 6543,3 -- The Warsong Reports
  .turnin 6543 -- The Warsong Reports
step
  .goto 1413,49.05,11.17
  .turnin 3921 -- Wenikee Boltbucket
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
step
  .todo "travel from Moonglade to Ashenvale: the travel graph has no route yet"
  .zone 1440 >> Go to Ashenvale
step
  .level 21 -- reach it first: kill or grind on the way
]]
)
