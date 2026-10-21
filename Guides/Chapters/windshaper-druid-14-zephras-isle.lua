-- PLANNED: the thorough alt 2 route for Skyborne Druid (HARDCORE): tools/route_planner.py windshaper --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"windshaper-druid-14-zephras-isle",
	[[
#chapter 30-30 Zephras Isle
step
  .goto 2521,69.81,61.71
  .turnin 94006 .class DRUID -- The Great Ursera Spirit
  .accept 94638 .class DRUID -- Strength and Mercy
  .note VERIFY(beta): the Bear Form trial; the data only says to kill Ur'endra (near 54,65). Go in at full health with your buffs up and leave if it goes badly: the Tauren Bear Form test (Lunaclaw) kills careless players.
step
  .goto 2521,53.66,65.02
  .complete 94638 .class DRUID -- Strength and Mercy
step
  .goto 2521,69.81,61.71
  .turnin 94638 .class DRUID -- Strength and Mercy
]]
)
