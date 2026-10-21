-- PLANNED: the thorough alt 4 route for Tauren Druid (HARDCORE): tools/route_planner.py tauren --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"tauren-druid-09-moonglade",
	[[
#chapter 18-19 Moonglade
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
  .todo "travel from Moonglade to Orgrimmar: the travel graph has no route yet"
  .zone 1454 >> Go to Orgrimmar
step
  .goto 1454,76.52,24.41
  .turnin 3923 -- Rilli Greasygob
  .accept 3924 -- Samophlange Manual
  .todo "Samophlange Manual: objective 1 has no position in the pack"
  .complete 3924,1 -- Samophlange Manual
  .turnin 3924 -- Samophlange Manual
step
  .goto 1454,47.06,46.43
  .accept 65601 -- Love Hurts
  .goto 1454,63.65,49.93
  .turnin 65601 -- Love Hurts
  .goto 1454,31.73,37.82
  .turnin 5726 -- Hidden Enemies
  .accept 5727 -- Hidden Enemies
  .turnin 5727 -- Hidden Enemies
step
  .goto 1454,38.7,78.4
  .accept 79094 -- The Lessons of Ta'zo
  .complete 79094,1 -- The Lessons of Ta'zo
step
  .todo "travel from Orgrimmar to The Barrens: the travel graph has no route yet"
  .zone 1413 >> Go to The Barrens
step
  .goto 1413,56.3,8.8
  .accept 78145 -- Arcanic Systems Manual
  .complete 78145,1 -- Arcanic Systems Manual
step
  .goto 1413,51.95,31.58
  .accept 899 -- Consumed by Hatred
  .accept 4921 -- Lost in Battle
  .accept 95774 -- Her Name Is Olgra
  .goto 1413,52.26,31.93
  .turnin 6127 .class DRUID -- The Principal Source
  .accept 6128 .class DRUID -- Gathering the Cure
]]
)
