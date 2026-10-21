-- PLANNED: the beam route for Skyborne Druid (HARDCORE): tools/route_planner.py windshaper --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"windshaper-druid-16-moonglade",
	[[
#chapter 24-25 Moonglade
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
  .goto 1440,74.11,60.92
  .turnin 6482 -- Freedom to Ruul
  .goto 1440,73.06,61.48
  .accept 6441 -- Satyr Horns
  .note The horns drop from the satyrs of the camps, among them the named Prince Raze (near 81.6,48.5) and Geltharis (near 78,42.4), whom the data does not rank: take the ordinary satyrs one at a time and leave the named ones if a fight looks bad.
step
  .goto 1440,67.12,56.41
  .complete 6441 -- Satyr Horns
step
  .goto 1440,73.06,61.48
  .turnin 6441 -- Satyr Horns
step
  .todo "border The Barrens/Ashenvale: no crossing coordinates yet (record them in game or in Borders.lua)"
  .zone 1413 >> Go into The Barrens
step
  .goto 1413,39.16,12.17
  .complete 876 -- Serena Bloodfeather
step
  .goto 1413,51.62,30.9
  .turnin 876 -- Serena Bloodfeather
  .accept 1060 -- Letter to Jin'Zil
step
  .goto 1413,45.1,57.68
  .accept 893 -- Weapons of Choice
  .goto 1413,44.62,59.27
  .accept 97250 -- Wrongly Blamed, Justly Corrected
  .goto 1413,44.55,59.26
  .accept 878 -- Tribes at War
]]
)
