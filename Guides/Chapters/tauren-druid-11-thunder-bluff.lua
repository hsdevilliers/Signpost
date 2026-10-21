-- PLANNED: the thorough route for Tauren Druid (HARDCORE): tools/route_planner.py tauren --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"tauren-druid-11-thunder-bluff",
	[[
#chapter 20-20 Thunder Bluff
step
  .goto 1456,76.48,27.22
  .turnin 31 .class DRUID -- Aquatic Form
  .level 20
  .accept 98340 .class DRUID -- The Great Cat Spirit
  .note Moonglade is a long walk from here. VERIFY(beta): the way there and back is unconfirmed (hearthstone, a flight master at Nighthaven, or Teleport: Moonglade if Forever gives it to druids).
step
  .todo "travel from Thunder Bluff to Stonetalon Mountains: the travel graph has no route yet"
  .zone 1442 >> Go to Stonetalon Mountains
step
  .goto 1442,74.4,85.7
  .accept 78149 -- Fury of the Land
  .complete 78149,1 -- Fury of the Land
step
  .todo "travel from Stonetalon Mountains to Moonglade: the travel graph has no route yet"
  .zone 1450 >> Go to Moonglade
step
  .goto 1450,56.21,30.64
  .turnin 6129 .class DRUID -- Curing the Sick
  .turnin 98340 .class DRUID -- The Great Cat Spirit
  .accept 6130 .class DRUID -- Power over Poison
  .accept 98405 .class DRUID -- The Great Cat Spirit
step
  .goto 1450,58.39,73.52
  .turnin 98405 .class DRUID -- The Great Cat Spirit
  .accept 98342 .class DRUID -- The Great Cat Spirit
  .note VERIFY(beta): the three relics lie in the Stormrage Barrow Dens (south-east Moonglade). Fan guides say the spirits there attack on sight and the relics are party loot: go in at full health (a statue at the door gives a stealth blessing) and leave if hurt.
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
  .todo "travel from Moonglade to Undercity: the travel graph has no route yet"
  .zone 1458 >> Go to Undercity
step
  .goto 1458,73.4,33.0
  .turnin 78143 -- Secrets of the Dreamers
  .turnin 78149 -- Fury of the Land
  .turnin 79097 -- Baxtan: On Destructive Magics
  .accept 78127 -- The Dalaran Digest
  .accept 78150 -- Friend of the Library
  .accept 79096 -- Ataeric: On Arcane Curiosities
  .turnin 78150 -- Friend of the Library
]]
)
