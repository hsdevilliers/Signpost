-- PLANNED: the thorough alt 2 route for Skyborne Druid (HARDCORE): tools/route_planner.py windshaper --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"windshaper-druid-06-hillsbrad-foothills",
	[[
#chapter 23-24 Hillsbrad Foothills
step
  .goto 1424,61.44,19.06
  .accept 496 -- Elixir of Suffering
  .level 21
  .accept 501 -- Elixir of Pain
  .goto 1424,62.33,20.45
  .accept 527 -- Battle of Hillsbrad
  .goto 1424,62.58,20.65
  .accept 549 -- WANTED: Syndicate Personnel
  .goto 1424,63.24,20.66
  .accept 498 -- The Rescue
step
  .goto 1424,54.68,31.22
  .complete 501 -- Elixir of Pain
  .complete 496,1 -- Elixir of Suffering
step
  .goto 1424,62.16,39.81
  .complete 496,2 -- Elixir of Suffering
step
  .goto 1424,61.44,19.06
  .turnin 496 -- Elixir of Suffering
  .turnin 501 -- Elixir of Pain
  .accept 499 -- Elixir of Suffering
  .accept 502 -- Elixir of Pain
  .goto 1424,61.55,19.14
  .turnin 499 -- Elixir of Suffering
step
  .goto 1424,33.22,34.76
  .complete 527,3 -- Battle of Hillsbrad
step
  .goto 1424,32.66,35.32
  .turnin 502 -- Elixir of Pain
step
  .goto 1424,31.7,34.93
  .complete 527,1 -- Battle of Hillsbrad
  .complete 527,2 -- Battle of Hillsbrad
  .complete 527,4 -- Battle of Hillsbrad
step
  .goto 1424,62.33,20.45
  .turnin 527 -- Battle of Hillsbrad
  .accept 528 -- Battle of Hillsbrad
  .accept 98094 -- Scout Support
step
  .goto 1424,62.11,19.7
  .accept 546 -- Souvenirs of Death
  .todo "Souvenirs of Death: objective 1 has no position in the pack"
  .complete 546,1 -- Souvenirs of Death
  .turnin 546 -- Souvenirs of Death
step
  .goto 1424,79.79,39.65
  .complete 498 -- The Rescue
  .complete 549 -- WANTED: Syndicate Personnel
step
  .goto 1424,63.58,53.11
  .turnin 98094 -- Scout Support
step
  .goto 1424,34.76,46.11
  .complete 528 -- Battle of Hillsbrad
step
  .goto 1424,62.33,20.45
  .turnin 549 -- WANTED: Syndicate Personnel
  .turnin 528 -- Battle of Hillsbrad
  .goto 1424,63.24,20.66
  .turnin 498 -- The Rescue
step
  .todo "Get from Hillsbrad Foothills to Thunder Bluff: they are on different continents, so you need a boat, a zeppelin or another ride, and the guide has no dock for it yet. This step is done when you arrive in Thunder Bluff."
  .zone 1456 >> Go to Thunder Bluff
step
  .goto 1456,76.48,27.22
  .turnin 94911 .class DRUID -- Child of Nature
  .accept 94913 .class DRUID -- Moonglade
  .note Moonglade is a long way from here. VERIFY(beta): cast Teleport: Moonglade (Classic's druid trainer teaches it at level 10; where Forever teaches it is unconfirmed). The way back is the hearthstone or a flight master (the client lists Horde flight nodes at Moonglade).
  .accept 98340 .class DRUID -- The Great Cat Spirit
  .note Moonglade is a long walk from here. VERIFY(beta): the way there and back is unconfirmed (hearthstone, a flight master at Nighthaven, or Teleport: Moonglade if Forever gives it to druids).
  .goto 1456,78.62,28.56
  .turnin 1489 -- Hamuul Runetotem
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
  .todo "Walk from Thunder Bluff to Moonglade: the guide has no waypoints for this yet, so find your own way. This step is done when you arrive in Moonglade."
  .zone 1450 >> Go to Moonglade
]]
)
