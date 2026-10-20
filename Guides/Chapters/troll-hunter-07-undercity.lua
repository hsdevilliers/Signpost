-- PLANNED: the beam route for Troll Hunter, planned by tools/route_planner.py on 2026-10-20 (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"troll-hunter-07-undercity",
	[[
#chapter 16-18 Undercity
step
  .goto 1458,48.82,69.28
  .accept 97289 -- Unending Torment
  .accept 97291 -- Unending Torment
  .accept 97292 -- Unending Torment
  .turnin 97292 -- Unending Torment
  .turnin 97289 -- Unending Torment
  .accept 97290 -- Unending Torment
  .accept 97891 -- Prompt Potion Runner
  .turnin 97290 -- Unending Torment
  .turnin 97891 -- Prompt Potion Runner
step
  .goto 1458,56.25,92.2
  .accept 5725 -- The Power to Destroy...
  .todo "The Power to Destroy...: objective 1 has no position in the pack"
  .complete 5725,1 -- The Power to Destroy...
  .todo "The Power to Destroy...: objective 2 has no position in the pack"
  .complete 5725,2 -- The Power to Destroy...
  .turnin 5725 -- The Power to Destroy...
  .optional 5725 -- group quest: The Power to Destroy...
step
  .goto 1458,58.3,97.88
  .accept 8368 -- Battle of Warsong Gulch
  .todo "Battle of Warsong Gulch: objective 1 has no position in the pack"
  .complete 8368,1 -- Battle of Warsong Gulch
  .turnin 8368 -- Battle of Warsong Gulch
step
  .goto 1458,73.4,33.0
  .accept 78124 -- Nar'thalas Almanac
  .accept 78142 -- Bewitchments and Glamours
  .accept 78146 -- Goaz Scrolls
  .accept 78147 -- Crimes Against Anatomy
  .accept 78150 -- Friend of the Library
  .accept 79091 -- Archmage Antonidas: The Unabridged Autobiography
  .accept 79093 -- Rumi of Gnomeregan: The Collected Works
  .accept 79096 -- Ataeric: On Arcane Curiosities
  .turnin 78150 -- Friend of the Library
  .todo "Nar'thalas Almanac: objective 1 has no position in the pack"
  .complete 78124,1 -- Nar'thalas Almanac
  .todo "Bewitchments and Glamours: objective 1 has no position in the pack"
  .complete 78142,1 -- Bewitchments and Glamours
  .todo "Goaz Scrolls: objective 1 has no position in the pack"
  .complete 78146,1 -- Goaz Scrolls
  .todo "Crimes Against Anatomy: objective 1 has no position in the pack"
  .complete 78147,1 -- Crimes Against Anatomy
  .todo "Archmage Antonidas: The Unabridged Autobiography: objective 1 has no position in the pack"
  .complete 79091,1 -- Archmage Antonidas: The Unabridged Autobiography
  .todo "Rumi of Gnomeregan: The Collected Works: objective 1 has no position in the pack"
  .complete 79093,1 -- Rumi of Gnomeregan: The Collected Works
  .turnin 78124 -- Nar'thalas Almanac
  .turnin 78142 -- Bewitchments and Glamours
  .turnin 78146 -- Goaz Scrolls
  .turnin 78147 -- Crimes Against Anatomy
  .turnin 79091 -- Archmage Antonidas: The Unabridged Autobiography
  .turnin 79093 -- Rumi of Gnomeregan: The Collected Works
step
  .goto 1458,85.06,25.99
  .accept 65597 -- The Binding
step
  .goto 1458,86.53,26.57
  .complete 65597 -- The Binding
step
  .goto 1458,85.06,25.99
  .turnin 65597 -- The Binding
step
  .goto 1458,54.0,49.3
  .complete 97291 -- Unending Torment
step
  .goto 1458,48.82,69.28
  .turnin 97291 -- Unending Torment
  .accept 95216 -- The New Plague
step
  .todo "travel from Undercity to Silverpine Forest: the travel graph has no route yet"
  .zone 1421 >> Go to Silverpine Forest
]]
)
