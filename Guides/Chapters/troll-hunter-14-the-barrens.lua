-- PLANNED: the beam route for Troll Hunter, planned by tools/route_planner.py on 2026-10-20 (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"troll-hunter-14-the-barrens",
	[[
#chapter 24-25 The Barrens
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
  .goto 1413,46.71,8.68
  .accept 8370 -- Conquering Arathi Basin
  .accept 8426 -- Battle of Warsong Gulch
step
  .goto 1413,45.34,28.41
  .todo "Verog the Dervish: objective 1 has no position in the pack"
  .complete 851,1 -- Verog the Dervish
  .turnin 851 -- Verog the Dervish
  .accept 852 -- Hezrul Bloodmark
step
  .goto 1413,46.01,35.74
  .accept 1487 -- Deviate Eradication
  .todo "Deviate Eradication: objective 1 has no position in the pack"
  .complete 1487,1 -- Deviate Eradication
  .todo "Deviate Eradication: objective 2 has no position in the pack"
  .complete 1487,2 -- Deviate Eradication
  .todo "Deviate Eradication: objective 3 has no position in the pack"
  .complete 1487,3 -- Deviate Eradication
  .todo "Deviate Eradication: objective 4 has no position in the pack"
  .complete 1487,4 -- Deviate Eradication
  .turnin 1487 -- Deviate Eradication
  .optional 1487 -- group quest: Deviate Eradication
step
  .goto 1413,46.04,41.14
  .complete 852 -- Hezrul Bloodmark
step
  .goto 1413,45.34,28.41
  .turnin 852 -- Hezrul Bloodmark
  .accept 4021 -- Counterattack!
  .todo "Counterattack!: objective 1 has no position in the pack"
  .complete 4021,1 -- Counterattack!
  .turnin 4021 -- Counterattack!
step
  .goto 1413,62.37,37.62
  .accept 1221 -- Blueleaf Tubers
  .todo "Blueleaf Tubers: objective 1 has no position in the pack"
  .complete 1221,1 -- Blueleaf Tubers
step
  .goto 1413,62.59,37.47
  .accept 92706 -- WANTED: Bruuz
  .turnin 863 -- The Escape
  .turnin 1094 -- Further Instructions
  .accept 1095 -- Further Instructions
step
  .goto 1413,62.32,37.62
  .complete 1221,2 -- Blueleaf Tubers
  .complete 1221,3 -- Blueleaf Tubers
  .complete 1221,4 -- Blueleaf Tubers
step
  .goto 1413,62.37,37.62
  .turnin 1221 -- Blueleaf Tubers
step
  .goto 1413,64.3,39.13
  .complete 92706 -- WANTED: Bruuz
step
  .goto 1413,62.68,36.23
  .turnin 92706 -- WANTED: Bruuz
step
  .goto 1413,45.1,57.68
  .accept 893 -- Weapons of Choice
  .accept 1130 -- Melor Sends Word
  .accept 6382 -- The Ashenvale Hunt
  .accept 97250 -- Wrongly Blamed, Justly Corrected
  .accept 878 -- Tribes at War
step
  .todo "travel from The Barrens to Thunder Bluff: the travel graph has no route yet"
  .zone 1456 >> Go to Thunder Bluff
]]
)
