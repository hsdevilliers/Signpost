-- PLANNED: the thorough alt 4 route for Tauren Druid (HARDCORE): tools/route_planner.py tauren --preset all --install --quiet (docs/PLANNER.md)
-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.
-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md.
local ADDON_NAME, ns = ...

ns.Chapters:Register(
	"tauren-druid-16-ashenvale",
	[[
#chapter 24-24 Ashenvale
step
  .goto 1440,11.69,34.91
  .accept 6442 -- Naga at the Zoram Strand
  .goto 1440,11.9,34.54
  .level 21
  .accept 216 -- Between a Rock and a Thistlefur
  .goto 1440,12.06,34.63
  .accept 6641 -- Vorsha the Lasher
  .goto 1440,12.22,34.22
  .turnin 6641 -- Vorsha the Lasher
  .goto 1440,11.56,34.29
  .turnin 6562 -- Trouble in the Deeps
  .accept 6563 -- The Essence of Aku'Mai
step
  .goto 1440,11.25,31.02
  .complete 6442 -- Naga at the Zoram Strand
step
  .goto 1440,11.69,34.91
  .turnin 6442 -- Naga at the Zoram Strand
step
  .goto 1440,37.42,34.27
  .complete 216 -- Between a Rock and a Thistlefur
step
  .goto 1440,41.53,34.49
  .accept 6482 -- Freedom to Ruul
step
  .goto 1440,74.11,60.92
  .turnin 6482 -- Freedom to Ruul
step
  .todo "travel from Ashenvale to Undercity: the travel graph has no route yet"
  .zone 1458 >> Go to Undercity
]]
)
