-- PLANNED: the thorough route for Skyborne Druid (HARDCORE): tools/route_planner.py windshaper --preset all --install --force --quiet --completeness 0.6 --completeness-trip 45 (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"windshaper-druid-11-moonglade",
	[[
#chapter 25-26 Moonglade
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
  .todo "Return from Moonglade to Thunder Bluff: use your hearthstone or a flight path if you have one (VERIFY(beta): the way back is not in the data). This step is done when you arrive in Thunder Bluff."
  .note Do not walk it: from Classic memory (not confirmed in Forever) the road overland runs through Felwood or Winterspring, zones for levels 48 and up, so it is not safe at your level.
  .zone 1456 >> Go to Thunder Bluff
step
  .goto 1456,76.48,27.22
  .turnin 98362 .class DRUID -- To Thunder Bluff
  .level 26 -- reach it first: kill or grind on the way
  .note Grind about 3,400 experience before you go on: about 20 kills of creatures near your level (an estimate)
step
  .goto 1456,47.0,49.83 >> Go to the flight master
  .fly Camp Taurajo
]]
)
