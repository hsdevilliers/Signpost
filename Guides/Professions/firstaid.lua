local ADDON_NAME, ns = ...

-- First Aid route track (docs/GUIDE-FORMAT.md "Profession tracks"), first cut for the Troll Hunter's default plan. It is
-- merged into a guide whose character's profession plan holds firstaid (PLAN section 3.8).
-- Anchors are @zone only, because the planner writes no .hub lines into the chapters: a step lands before the first route
-- step in that map (a capital the route visits).
-- Every step is gated .race Troll: its .goto and its anchor belong to this route, so another race's guide (Tauren,
-- Skyborne) gets none of them instead of an unmatched anchor. Their own steps join this file later.
-- The skill goal that rides beside the route (150) is Version 1's, which stops at level 30.
-- EVERY NUMBER HERE IS CLASSIC'S until the Forever client or recorded play says otherwise: the rank levels (Journeyman
-- 10, Expert 20), the skill a rank is trained from (50, 125) and the caps (75, 150, 225). VERIFY(launch): all of them
-- (docs/FOREVER-API-NOTES.md, Open probes, "Profession tracks"). The data names no trainer or book for Expert First Aid,
-- so no step points at it and a .todo says so.
-- Trainers come from the data pack's NPC titles (a QuestieDB Classic baseline plus Forever's layers; names and positions,
-- not walked in game yet): Arnok 3373 (Orgrimmar), Mary Edras 4591 (Undercity) and Pand Stonebinder 2798 (Thunder
-- Bluff), all "First Aid Trainer", Horde. Rawrk 5943, also a First Aid Trainer, stands in Razor Hill: the shipped route
-- passes it at levels 4 to 10, but no step can anchor there without .hub lines. The pack has no profession records yet
-- (no trainer lists, no recipes), so .trainprof pins nothing by itself: each step carries its own .goto, and no recipe
-- or spell ID is used.
ns.Professions:RegisterTrack(
	"firstaid",
	[[
#track firstaid

-- The first visit to Orgrimmar (level 10 on the shipped route). The first .trainprof of a track is the step whose skip
-- declines the profession (Engine/Progress.lua), so no rank step may come before it.
step @zone 1454
  .race Troll
  .goto 1454,34.18,84.58 -- Arnok, First Aid Trainer (npc 3373)
  .trainprof firstaid >> Learn First Aid from Arnok
  .sticky .skill firstaid 150
  .note Bandage yourself after fights: the recipes shown in orange or yellow raise First Aid, and bandages need cloth. Classic's ranks, unverified in Forever: Apprentice to 75, Journeyman to 150.
  .note Not for you? Skip this step and the other First Aid steps leave the guide.

-- Undercity: the next rank once First Aid is within 25 of its cap (the step passes by itself while it is lower).
step @zone 1458
  .race Troll
  .goto 1458,73.16,55.15 -- Mary Edras, First Aid Trainer (npc 4591)
  .trainprof firstaid >> Train your next First Aid rank from Mary Edras
  .note Classic, unverified in Forever: Journeyman needs level 10 and First Aid 50, and lifts the cap from 75 to 150.
  .todo "Expert First Aid (Classic: level 20, First Aid 125): where it is taught is not in the data yet, so no step points at it"

-- Thunder Bluff, for the rank missed on the way.
step @zone 1456
  .race Troll
  .goto 1456,29.69,21.18 -- Pand Stonebinder, First Aid Trainer (npc 2798)
  .trainprof firstaid >> Train your next First Aid rank from Pand Stonebinder
  .note Only for a rank you missed (Classic, unverified in Forever: Journeyman needs level 10 and First Aid 50).
]]
)
