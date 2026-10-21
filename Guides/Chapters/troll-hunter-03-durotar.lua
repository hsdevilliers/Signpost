-- PLANNED: the thorough alt 4 route for Troll Hunter: tools/route_planner.py troll --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"troll-hunter-03-durotar",
	[[
#chapter 11-12 Durotar
step
  .goto 1411,53.08,9.4
  .complete 5726 -- Hidden Enemies
step
  .goto 1411,59.22,17.6
  .complete 99052 -- Threat from Below
step
  .goto 1411,51.27,19.19
  .complete 835,2 -- Securing the Lines
step
  .goto 1411,46.37,22.94
  .turnin 835 -- Securing the Lines
step
  .goto 1411,42.12,26.66
  .complete 806 -- Dark Storms
step
  .goto 1411,43.1,30.24
  .accept 816 -- Lost But Not Forgotten
step
  .goto 1411,52.24,43.15
  .turnin 806 -- Dark Storms
  .turnin 99052 -- Threat from Below
  .accept 828 -- Margoz
step
  .goto 1411,35.7,25.31
  .complete 816 -- Lost But Not Forgotten
step
  .goto 1411,43.1,30.24
  .turnin 816 -- Lost But Not Forgotten
step
  .goto 1411,56.41,20.04
  .turnin 828 -- Margoz
  .accept 827 -- Skull Rock
step
  .goto 1411,52.67,25.36
  .complete 827 -- Skull Rock
step
  .goto 1411,56.41,20.04
  .turnin 827 -- Skull Rock
  .accept 829 -- Neeru Fireblade
step
  .todo "Walk from Durotar to Orgrimmar: the guide has no waypoints for this yet, so find your own way. This step is done when you arrive in Orgrimmar."
  .zone 1454 >> Go to Orgrimmar
]]
)
