-- PLANNED: the thorough alt 3 route for Tauren Druid (HARDCORE): tools/route_planner.py tauren --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"tauren-druid-22-thousand-needles",
	[[
#chapter 27-29 Thousand Needles
step
  .goto 1441,32.24,22.17
  .accept 4542 -- Message to Freewind Post
step
  .goto 1441,44.64,50.29
  .accept 4821 -- Alien Egg
  .goto 1441,45.67,50.74
  .turnin 4542 -- Message to Freewind Post
  .accept 4841 -- Pacify the Centaur
step
  .goto 1441,45.14,49.11 >> Go to the flight master
  .fp 1441,Freewind Post
step
  .goto 1441,52.34,55.25
  .complete 4821 -- Alien Egg
step
  .goto 1441,47.68,41.38
  .complete 4841 -- Pacify the Centaur
step
  .goto 1441,44.93,48.92
  .accept 4767 -- Wind Rider
  .goto 1441,44.64,50.29
  .turnin 4821 -- Alien Egg
  .accept 4865 -- Serpent Wild
  .goto 1441,45.67,50.74
  .turnin 4841 -- Pacify the Centaur
  .accept 5064 -- Grimtotem Spying
step
  .goto 1441,33.76,39.99
  .complete 5064 -- Grimtotem Spying
step
  .goto 1441,21.54,32.35
  .turnin 4865 -- Serpent Wild
step
  .goto 1441,18.02,41.68
  .complete 4767 -- Wind Rider
step
  .goto 1441,44.93,48.92
  .turnin 4767 -- Wind Rider
  .goto 1441,45.67,50.74
  .turnin 5064 -- Grimtotem Spying
  .level 29 -- reach it first: kill or grind on the way
  .note Grind about 30,000 experience before you go on: about 160 kills of creatures near your level (an estimate)
step
  .goto 1441,78.06,77.13
  .accept 1104 -- Salt Flat Venom
  .note Vile Sting, a rare elite scorpid (near 70.6,72.9), drops the venom too: take it from the ordinary scorpids and keep away from him.
  .goto 1441,78.14,77.12
  .accept 1105 -- Hardened Shells
  .goto 1441,80.18,75.88
  .accept 1176 -- Load Lightening
step
  .goto 1441,84.2,70.73
  .complete 1176 -- Load Lightening
  .complete 1105 -- Hardened Shells
  .complete 1104 -- Salt Flat Venom
step
  .goto 1441,80.18,75.88
  .turnin 1176 -- Load Lightening
  .goto 1441,78.14,77.12
  .turnin 1105 -- Hardened Shells
  .goto 1441,78.06,77.13
  .turnin 1104 -- Salt Flat Venom
step
  .goto 1441,45.14,49.11 >> Go to the flight master
  .fly Camp Taurajo
]]
)
