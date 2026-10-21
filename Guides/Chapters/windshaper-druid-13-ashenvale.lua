-- PLANNED: the thorough alt 2 route for Skyborne Druid (HARDCORE): tools/route_planner.py windshaper --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"windshaper-druid-13-ashenvale",
	[[
#chapter 27-30 Ashenvale
step
  .goto 1440,71.11,68.12
  .accept 6503 -- Ashenvale Outrunners
step
  .goto 1440,72.87,70.18
  .complete 6503 -- Ashenvale Outrunners
step
  .goto 1440,73.06,61.48
  .accept 6441 -- Satyr Horns
  .note The horns drop from the satyrs of the camps, among them the named Prince Raze (near 81.6,48.5) and Geltharis (near 78,42.4), whom the data does not rank: take the ordinary satyrs one at a time and leave the named ones if a fight looks bad.
step
  .goto 1440,67.12,56.41
  .complete 6441 -- Satyr Horns
step
  .goto 1440,73.06,61.48
  .turnin 6441 -- Satyr Horns
step
  .goto 1440,71.11,68.12
  .turnin 6503 -- Ashenvale Outrunners
  .level 29 -- reach it first: kill or grind on the way
  .note Grind about 44,000 experience before you go on: about 240 kills of creatures near your level (an estimate)
step
  .goto 1440,70.01,71.16
  .accept 6504 -- The Lost Pages
  .todo "The Lost Pages: objective 1 has no position in the pack"
  .complete 6504,1 -- The Lost Pages
  .todo "The Lost Pages: objective 2 has no position in the pack"
  .complete 6504,2 -- The Lost Pages
  .todo "The Lost Pages: objective 3 has no position in the pack"
  .complete 6504,3 -- The Lost Pages
  .turnin 6504 -- The Lost Pages
  .level 30 -- reach it first: kill or grind on the way
  .note Grind about 41,000 experience before you go on: about 210 kills of creatures near your level (an estimate)
step
  .todo "Get from Ashenvale to Zephras Isle: they are on different continents, so you need a boat, a zeppelin or another ride, and the guide has no dock for it yet. This step is done when you arrive in Zephras Isle."
  .zone 2521 >> Go to Zephras Isle
]]
)
