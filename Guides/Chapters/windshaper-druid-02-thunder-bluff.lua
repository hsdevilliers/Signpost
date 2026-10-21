-- PLANNED: the thorough route for Skyborne Druid (HARDCORE): tools/route_planner.py windshaper --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"windshaper-druid-02-thunder-bluff",
	[[
#chapter 15-15 Thunder Bluff
step
  .goto 1456,38.0,55.9
  .accept 97485 -- Traditions of the Bluff
  .todo "Traditions of the Bluff: objective 2 has no position in the pack"
  .complete 97485,2 -- Traditions of the Bluff
step
  .goto 1456,47.0,49.83 >> Go to the flight master
  .fp 1456,Thunder Bluff
step
  .goto 1456,53.02,87.84
  .complete 97485,1 -- Traditions of the Bluff
step
  .goto 1456,38.0,55.9
  .turnin 97485 -- Traditions of the Bluff
step
  .goto 1456,76.48,27.22
  .turnin 94911 .class DRUID -- Child of Nature
  .accept 94913 .class DRUID -- Moonglade
  .note Moonglade is a long way from here. VERIFY(beta): cast Teleport: Moonglade (Classic's druid trainer teaches it at level 10; where Forever teaches it is unconfirmed). The way back is the hearthstone or a flight master (the client lists Horde flight nodes at Moonglade).
step
  .todo "Walk from Thunder Bluff to Orgrimmar: the guide has no waypoints for this yet, so find your own way. This step is done when you arrive in Orgrimmar."
  .zone 1454 >> Go to Orgrimmar
]]
)
