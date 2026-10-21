-- PLANNED: the thorough route for Skyborne Druid (HARDCORE): tools/route_planner.py windshaper --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"windshaper-druid-10-thunder-bluff",
	[[
#chapter 25-25 Thunder Bluff
step
  .goto 1456,54.14,47.05
  .accept 97538 -- Pigments for Paints
step
  .goto 1456,54.97,51.41
  .accept 1195 -- The Sacred Flame
  .todo "The Sacred Flame: objective 1 has no position in the pack"
  .complete 1195,1 -- The Sacred Flame
  .turnin 1195 -- The Sacred Flame
step
  .goto 1456,76.48,27.22
  .accept 98340 .class DRUID -- The Great Cat Spirit
  .note Moonglade is a long walk from here. VERIFY(beta): the way there and back is unconfirmed (hearthstone, a flight master at Nighthaven, or Teleport: Moonglade if Forever gives it to druids).
step
  .todo "Go to Moonglade: cast Teleport: Moonglade if you have it (VERIFY(beta): where a druid learns it), else the way is not in the data. This step is done when you arrive in Moonglade."
  .note Do not walk it: from Classic memory (not confirmed in Forever) the road overland runs through Felwood or Winterspring, zones for levels 48 and up, so it is not safe at your level.
  .zone 1450 >> Go to Moonglade
]]
)
