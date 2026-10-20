-- PLANNED: the thorough alt 1 route for Troll Hunter: tools/route_planner.py troll --preset all --install --force --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"troll-hunter-12-silverpine-forest",
	[[
#chapter 22-23 Silverpine Forest
step
  .goto 1421,65.71,23.67
  .complete 442 -- Assault on Fenris Isle
  .optional 442 -- group quest: Assault on Fenris Isle
step
  .goto 1421,43.42,40.86
  .turnin 442 -- Assault on Fenris Isle
  .optional 442 -- group quest: Assault on Fenris Isle
step
  .todo "travel from Silverpine Forest to Tirisfal Glades: the travel graph has no route yet"
  .zone 1420 >> Go to Tirisfal Glades
step
  .goto 1420,65.25,60.2
  .accept 92422 -- The Wrath of Rath'mael
  .todo "The Wrath of Rath'mael: objective 1 has no position in the pack"
  .complete 92422,1 -- The Wrath of Rath'mael
  .turnin 92422 -- The Wrath of Rath'mael
step
  .todo "travel from Tirisfal Glades to The Barrens: the travel graph has no route yet"
  .zone 1413 >> Go to The Barrens
step
  .goto 1413,49.33,50.32
  .complete 4921 -- Lost in Battle
  .complete 899 -- Consumed by Hatred
  .complete 95774 -- Her Name Is Olgra
step
  .goto 1413,51.95,31.58
  .turnin 899 -- Consumed by Hatred
  .turnin 4921 -- Lost in Battle
  .turnin 95774 -- Her Name Is Olgra
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
  .goto 1413,62.37,37.62
  .accept 865 -- Raptor Horns
  .accept 1221 -- Blueleaf Tubers
  .todo "Blueleaf Tubers: objective 1 has no position in the pack"
  .complete 1221,1 -- Blueleaf Tubers
step
  .goto 1413,62.59,37.47
  .accept 92706 -- WANTED: Bruuz
  .goto 1413,62.98,37.22
  .turnin 863 -- The Escape
step
  .goto 1413,62.32,37.62
  .complete 1221,2 -- Blueleaf Tubers
  .complete 1221,3 -- Blueleaf Tubers
  .complete 1221,4 -- Blueleaf Tubers
step
  .goto 1413,62.37,37.62
  .turnin 1221 -- Blueleaf Tubers
]]
)
