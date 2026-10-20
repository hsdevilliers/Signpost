-- PLANNED: the beam route for Troll Hunter, planned by tools/route_planner.py on 2026-10-20 (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"troll-hunter-10-silverpine-forest",
	[[
#chapter 20-21 Silverpine Forest
step
  .goto 1421,63.51,58.13
  .complete 95981 -- Watching the Roads
step
  .goto 1421,46.08,85.63
  .complete 98299 -- Stop the Spread
step
  .goto 1421,43.98,40.93
  .turnin 479 -- Ambermill Investigations
  .turnin 95981 -- Watching the Roads
  .turnin 516 -- Beren's Peril
  .accept 1098 -- Deathstalkers in Shadowfang
  .turnin 1098 -- Deathstalkers in Shadowfang
  .turnin 446 -- Thule Ravenclaw
  .accept 448 -- Report to Hadrec
  .turnin 422 -- Arugal's Folly
  .turnin 98299 -- Stop the Spread
  .turnin 448 -- Report to Hadrec
  .accept 442 -- Assault on Fenris Isle
  .optional 442 -- group quest: Assault on Fenris Isle
step
  .goto 1421,65.71,23.67
  .complete 442 -- Assault on Fenris Isle
  .optional 442 -- group quest: Assault on Fenris Isle
step
  .goto 1421,43.42,40.86
  .turnin 442 -- Assault on Fenris Isle
  .optional 442 -- group quest: Assault on Fenris Isle
step
  .todo "travel from Silverpine Forest to Ashenvale: the travel graph has no route yet"
  .zone 1440 >> Go to Ashenvale
]]
)
