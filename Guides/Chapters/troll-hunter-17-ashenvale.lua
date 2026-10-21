-- PLANNED: the thorough alt 4 route for Troll Hunter: tools/route_planner.py troll --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"troll-hunter-17-ashenvale",
	[[
#chapter 25-26 Ashenvale
step
  .goto 1440,11.69,34.91
  .accept 6442 -- Naga at the Zoram Strand
  .goto 1440,11.9,34.54
  .accept 216 -- Between a Rock and a Thistlefur
  .goto 1440,12.06,34.63
  .accept 6641 -- Vorsha the Lasher
  .complete 6641,1 -- Vorsha the Lasher
  .note Vorsha the Lasher: escort: stay with the NPC and let it finish; the data does not say where it goes or what attacks it
  .goto 1440,12.22,34.22
  .turnin 6641 -- Vorsha the Lasher
  .goto 1440,11.56,34.29
  .turnin 6562 -- Trouble in the Deeps
  .accept 6563 -- The Essence of Aku'Mai
  .note The Essence of Aku'Mai: dungeon quest: needs a group
  .accept 6921 -- Amongst the Ruins
  .note Amongst the Ruins: dungeon quest: needs a group
  .complete 6921,1 -- Amongst the Ruins
  .turnin 6921 -- Amongst the Ruins
  .optional 6562 -- dungeon quest: Trouble in the Deeps
  .optional 6563 -- dungeon quest: The Essence of Aku'Mai
  .optional 6921 -- dungeon quest: Amongst the Ruins
step
  .goto 1440,13.66,30.9
  .complete 6442 -- Naga at the Zoram Strand
step
  .goto 1440,13.59,13.14
  .complete 6563 -- The Essence of Aku'Mai
  .optional 6563 -- dungeon quest: The Essence of Aku'Mai
step
  .goto 1440,31.74,38.0
  .complete 216 -- Between a Rock and a Thistlefur
step
  .goto 1440,11.9,34.54
  .turnin 216 -- Between a Rock and a Thistlefur
  .accept 6621 -- King of the Foulweald
  .todo "King of the Foulweald: objective 1 has no position in the pack"
  .complete 6621,1 -- King of the Foulweald
  .turnin 6621 -- King of the Foulweald
step
  .goto 1440,11.69,34.91
  .turnin 6442 -- Naga at the Zoram Strand
  .goto 1440,11.56,34.29
  .turnin 6563 -- The Essence of Aku'Mai
  .optional 6563 -- dungeon quest: The Essence of Aku'Mai
step
  .goto 1440,73.06,61.48
  .accept 6441 -- Satyr Horns
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
step
  .goto 1440,71.11,68.12
  .accept 6503 -- Ashenvale Outrunners
step
  .goto 1440,72.87,70.18
  .complete 6503 -- Ashenvale Outrunners
step
  .goto 1440,71.11,68.12
  .turnin 6503 -- Ashenvale Outrunners
step
  .goto 1440,73.18,61.59 >> Go to the flight master
  .fly Crossroads
]]
)
