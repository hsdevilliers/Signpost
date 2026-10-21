-- PLANNED: the thorough route for Tauren Druid (HARDCORE): tools/route_planner.py tauren --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"tauren-druid-09-thunder-bluff",
	[[
#chapter 18-19 Thunder Bluff
step
  .goto 1456,76.48,27.22
  .accept 26 .class DRUID -- A Lesson to Learn
  .goto 1456,78.62,28.56
  .turnin 1489 -- Hamuul Runetotem
  .accept 1490 -- Nara Wildmane
  .goto 1456,75.65,31.61
  .turnin 1490 -- Nara Wildmane
step
  .todo "travel from Thunder Bluff to Moonglade: the travel graph has no route yet"
  .zone 1450 >> Go to Moonglade
step
  .goto 1450,56.21,30.64
  .turnin 6126 .class DRUID -- Lessons Anew
  .turnin 26 .class DRUID -- A Lesson to Learn
  .accept 6127 .class DRUID -- The Principal Source
  .accept 28 .class DRUID -- Trial of the Lake
  .todo "The Principal Source: objective 1 has no position in the pack"
  .complete 6127,1 .class DRUID -- The Principal Source
step
  .goto 1450,36.52,40.1
  .turnin 28 .class DRUID -- Trial of the Lake
  .accept 30 .class DRUID -- Trial of the Sea Lion
  .todo "Trial of the Sea Lion: objective 1 has no position in the pack"
  .complete 30,1 .class DRUID -- Trial of the Sea Lion
step
  .goto 1450,56.21,30.64
  .turnin 30 .class DRUID -- Trial of the Sea Lion
  .accept 31 .class DRUID -- Aquatic Form
step
  .todo "travel from Moonglade to The Barrens: the travel graph has no route yet"
  .zone 1413 >> Go to The Barrens
step
  .goto 1413,51.95,31.58
  .accept 899 -- Consumed by Hatred
  .accept 4921 -- Lost in Battle
  .accept 95774 -- Her Name Is Olgra
  .goto 1413,52.26,31.93
  .turnin 6127 .class DRUID -- The Principal Source
  .accept 6128 .class DRUID -- Gathering the Cure
step
  .goto 1413,49.33,50.32
  .complete 4921 -- Lost in Battle
  .complete 899 -- Consumed by Hatred
  .complete 95774 -- Her Name Is Olgra
]]
)
