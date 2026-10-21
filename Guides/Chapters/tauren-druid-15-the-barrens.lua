-- PLANNED: the thorough alt 1 route for Tauren Druid (HARDCORE): tools/route_planner.py tauren --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"tauren-druid-15-the-barrens",
	[[
#chapter 26-27 The Barrens
step
  .goto 1413,45.1,57.68
  .accept 893 -- Weapons of Choice
  .goto 1413,44.86,59.14
  .accept 913 -- Cry of the Thunderhawk
  .accept 6382 -- The Ashenvale Hunt
  .goto 1413,44.62,59.27
  .accept 97250 -- Wrongly Blamed, Justly Corrected
  .goto 1413,44.55,59.26
  .accept 878 -- Tribes at War
step
  .goto 1413,41.93,78.74
  .complete 893 -- Weapons of Choice
  .complete 913 -- Cry of the Thunderhawk
step
  .goto 1413,45.89,77.0
  .accept 843 -- Gann's Reclamation
step
  .goto 1413,48.77,77.21
  .complete 97250 -- Wrongly Blamed, Justly Corrected
step
  .goto 1413,44.62,59.27
  .turnin 97250 -- Wrongly Blamed, Justly Corrected
  .goto 1413,44.86,59.14
  .turnin 913 -- Cry of the Thunderhawk
  .accept 874 -- Mahren Skyseer
  .goto 1413,45.1,57.68
  .turnin 893 -- Weapons of Choice
step
  .goto 1413,47.61,85.33
  .complete 843 -- Gann's Reclamation
step
  .goto 1413,45.89,77.0
  .turnin 843 -- Gann's Reclamation
  .accept 846 -- Revenge of Gann
step
  .goto 1413,49.22,84.08
  .complete 846 -- Revenge of Gann
step
  .goto 1413,45.89,77.0
  .turnin 846 -- Revenge of Gann
  .accept 849 -- Revenge of Gann
step
  .goto 1413,46.97,85.63
  .complete 849 -- Revenge of Gann
step
  .todo "Walk from The Barrens to Thousand Needles: the guide has no waypoints for this yet, so find your own way. This step is done when you arrive in Thousand Needles."
  .zone 1441 >> Go to Thousand Needles
]]
)
