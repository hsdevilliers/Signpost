-- PLANNED: the thorough alt 4 route for Tauren Druid (HARDCORE): tools/route_planner.py tauren --preset all --install --quiet (docs/PLANNER.md)
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
step
  .todo "travel from Thunder Bluff to Moonglade: the travel graph has no route yet"
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
  .todo "travel from Moonglade to Stonetalon Mountains: the travel graph has no route yet"
  .zone 1442 >> Go to Stonetalon Mountains
step
  .goto 1442,65.39,46.16
  .complete 1062 -- Goblin Invaders
step
  .goto 1442,61.11,59.38
  .complete 6461,2 -- Blood Feeders
step
  .goto 1442,58.99,62.6
  .accept 1093 -- Super Reaper 6000
]]
)
