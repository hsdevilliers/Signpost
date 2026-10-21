-- PLANNED: the thorough route for Skyborne Druid (HARDCORE): tools/route_planner.py windshaper --preset all --install --force --quiet --completeness 0.6 --completeness-trip 45 (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"windshaper-druid-16-ashenvale",
	[[
#chapter 27-29 Ashenvale
step
  .goto 1440,73.06,61.48
  .accept 6441 -- Satyr Horns
  .note The horns drop from the satyrs of the camps, among them the named Prince Raze (near 81.6,48.5) and Geltharis (near 78,42.4), whom the data does not rank: take the ordinary satyrs one at a time and leave the named ones if a fight looks bad.
  .goto 1440,73.78,61.46
  .turnin 6382 -- The Ashenvale Hunt
  .accept 6383 -- The Ashenvale Hunt
  .turnin 6383 -- The Ashenvale Hunt
step
  .goto 1440,73.18,61.59 >> Go to the flight master
  .fp 1440,Splintertree Post
step
  .goto 1440,67.12,56.41
  .complete 6441 -- Satyr Horns
step
  .goto 1440,73.06,61.48
  .turnin 6441 -- Satyr Horns
  .level 29 -- reach it first: kill or grind on the way
  .note Grind about 41,000 experience before you go on: about 220 kills of creatures near your level (an estimate)
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
step
  .goto 1440,73.18,61.59 >> Go to the flight master
  .fly Camp Taurajo
step
  .goto 1413,44.86,59.14
  .accept 1130 -- Melor Sends Word
step
  .goto 1413,44.45,59.15 >> Go to the flight master
  .fly Thunder Bluff
step
  .goto 1456,61.54,80.92
  .turnin 1130 -- Melor Sends Word
step
  .todo "Walk from Thunder Bluff to Mulgore: the guide has no waypoints for this yet, so find your own way. This step is done when you arrive in Mulgore."
  .zone 1412 >> Go to Mulgore
]]
)
