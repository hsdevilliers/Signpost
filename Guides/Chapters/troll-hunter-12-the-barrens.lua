-- PLANNED: the beam route for Troll Hunter: tools/route_planner.py troll --preset all --install --force --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"troll-hunter-12-the-barrens",
	[[
#chapter 23-25 The Barrens
step
  .goto 1413,62.37,37.62
  .accept 865 -- Raptor Horns
  .accept 1221 -- Blueleaf Tubers
  .todo "Blueleaf Tubers: objective 1 has no position in the pack"
  .complete 1221,1 -- Blueleaf Tubers
step
  .goto 1413,62.32,37.62
  .complete 1221,2 -- Blueleaf Tubers
  .complete 1221,3 -- Blueleaf Tubers
  .complete 1221,4 -- Blueleaf Tubers
step
  .goto 1413,62.37,37.62
  .turnin 1221 -- Blueleaf Tubers
  .goto 1413,62.59,37.47
  .accept 92706 -- WANTED: Bruuz
step
  .goto 1413,64.3,39.13
  .complete 92706 -- WANTED: Bruuz
step
  .goto 1413,62.68,36.23
  .turnin 92706 -- WANTED: Bruuz
step
  .goto 1413,51.95,31.58
  .accept 899 -- Consumed by Hatred
  .accept 4921 -- Lost in Battle
  .accept 95774 -- Her Name Is Olgra
  .goto 1413,51.62,30.9
  .turnin 875 -- Harpy Lieutenants
  .accept 876 -- Serena Bloodfeather
  .goto 1413,52.65,29.06
  .accept 97003 -- Chol'aruk the Ravener
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
  .goto 1413,57.62,27.24
  .complete 97003 -- Chol'aruk the Ravener
step
  .goto 1413,52.65,29.06
  .turnin 97003 -- Chol'aruk the Ravener
step
  .goto 1413,46.04,41.14
  .complete 852 -- Hezrul Bloodmark
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
  .goto 1413,45.34,28.41
  .turnin 852 -- Hezrul Bloodmark
  .accept 4021 -- Counterattack!
  .todo "Counterattack!: objective 1 has no position in the pack"
  .complete 4021,1 -- Counterattack!
  .turnin 4021 -- Counterattack!
step
  .goto 1413,44.12,14.4
  .complete 865 -- Raptor Horns
step
  .goto 1413,39.16,12.17
  .complete 876 -- Serena Bloodfeather
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
  .goto 1413,51.62,30.9
  .turnin 876 -- Serena Bloodfeather
  .accept 1060 -- Letter to Jin'Zil
step
  .goto 1413,62.37,37.62
  .turnin 865 -- Raptor Horns
step
  .goto 1413,55.61,42.75
  .complete 877 -- The Stagnant Oasis
step
  .goto 1413,52.6,46.11
  .complete 905 -- The Angry Scytheclaws
step
  .goto 1413,45.1,57.68
  .accept 893 -- Weapons of Choice
  .goto 1413,44.86,59.14
  .accept 6382 -- The Ashenvale Hunt
  .goto 1413,44.62,59.27
  .accept 97250 -- Wrongly Blamed, Justly Corrected
  .goto 1413,44.55,59.26
  .accept 878 -- Tribes at War
step
  .goto 1413,44.45,59.15 >> Go to the flight master
  .fp 1413,Camp Taurajo
step
  .goto 1413,42.87,55.25
  .complete 878,1 -- Tribes at War
step
  .goto 1413,43.27,48.0
  .complete 878,3 -- Tribes at War
step
  .goto 1413,44.78,51.51
  .complete 878,2 -- Tribes at War
step
  .goto 1413,44.55,59.26
  .turnin 878 -- Tribes at War
  .accept 5052 -- Blood Shards of Agamaggan
step
  .goto 1413,42.87,55.25
  .complete 5052 -- Blood Shards of Agamaggan
step
  .goto 1413,44.55,59.26
  .turnin 5052 -- Blood Shards of Agamaggan
  .accept 879 -- Betrayal from Within
step
  .goto 1413,46.37,73.79
  .accept 79192 -- Stepping Stones
step
  .goto 1413,48.77,77.21
  .complete 97250 -- Wrongly Blamed, Justly Corrected
step
  .goto 1413,41.16,79.14
  .complete 893 -- Weapons of Choice
  .complete 879,3 -- Betrayal from Within
step
  .goto 1413,44.62,59.27
  .turnin 97250 -- Wrongly Blamed, Justly Corrected
  .goto 1413,44.86,59.14
  .accept 1130 -- Melor Sends Word
  .goto 1413,45.1,57.68
  .turnin 893 -- Weapons of Choice
step
  .todo "Walk from The Barrens to Thunder Bluff: the guide has no waypoints for this yet, so find your own way. This step is done when you arrive in Thunder Bluff."
  .zone 1456 >> Go to Thunder Bluff
step
  .goto 1456,54.97,51.41
  .accept 1195 -- The Sacred Flame
  .todo "The Sacred Flame: objective 1 has no position in the pack"
  .complete 1195,1 -- The Sacred Flame
  .turnin 1195 -- The Sacred Flame
step
  .goto 1456,47.0,49.83 >> Go to the flight master
  .fp 1456,Thunder Bluff
step
  .goto 1456,54.14,47.05
  .accept 97538 -- Pigments for Paints
  .goto 1456,61.54,80.92
  .turnin 1130 -- Melor Sends Word
step
  .goto 1456,47.0,49.83 >> Go to the flight master
  .fly Camp Taurajo
step
  .todo "Walk from The Barrens to Stonetalon Mountains: the guide has no waypoints for this yet, so find your own way. This step is done when you arrive in Stonetalon Mountains."
  .zone 1442 >> Go to Stonetalon Mountains
]]
)
