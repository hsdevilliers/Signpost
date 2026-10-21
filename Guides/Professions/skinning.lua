local ADDON_NAME, ns = ...

-- Skinning route track (docs/GUIDE-FORMAT.md "Profession tracks"), first cut for the Troll Hunter's default plan. It is
-- merged into a guide whose character's profession plan holds skinning (PLAN section 3.8).
-- Anchors are @zone only, because the planner writes no .hub lines into the chapters: a step lands before the first route
-- step in that map (a capital the route visits).
-- Every step is gated .race Troll: its .goto and its anchor belong to this route, so another race's guide (Tauren,
-- Skyborne) gets none of them instead of an unmatched anchor. Their own steps join this file later.
-- The skill goal that rides beside the route (150) is Version 1's, which stops at level 30.
-- EVERY NUMBER HERE IS CLASSIC'S until the Forever client or recorded play says otherwise: the rank levels (Journeyman
-- 10, Expert 20), the skill a rank is trained from (50, 125), the caps (75, 150, 225) and which trainer teaches which
-- rank. VERIFY(launch): all of them (docs/FOREVER-API-NOTES.md, Open probes, "Profession tracks").
-- Trainers come from the data pack's NPC titles (a QuestieDB Classic baseline plus Forever's layers; names and positions,
-- not walked in game yet): Thuwd 7088 (Orgrimmar), Killian Hagey 7087 (Undercity) and Mooranta 7089 (Thunder Bluff), all
-- "Skinning Trainer", Horde. Kagil 267327, a "Junior Skinning Trainer" that only Forever's layer has, stands in the
-- Valley of Trials: what he teaches is not known, and no step can anchor there without .hub lines. The pack has no
-- profession records yet (no trainer lists, no recipes), so .trainprof pins nothing by itself: each step carries its
-- own .goto, and no recipe or spell ID is used.
ns.Professions:RegisterTrack(
	"skinning",
	[[
#track skinning

-- The first visit to Orgrimmar (level 10 on the shipped route). The first .trainprof of a track is the step whose skip
-- declines the profession (Engine/Progress.lua), so no rank step may come before it.
step @zone 1454
  .race Troll
  .goto 1454,63.36,45.42 -- Thuwd, Skinning Trainer (npc 7088)
  .trainprof skinning >> Learn Skinning from Thuwd
  .sticky .skill skinning 150
  .note Skin every beast you kill: each new skin raises Skinning. Classic's ranks, unverified in Forever: Apprentice to 75, Journeyman to 150.
  .note Not for you? Skip this step and the other Skinning steps leave the guide.

-- Undercity: the next rank once Skinning is within 25 of its cap (the step passes by itself while it is lower).
step @zone 1458
  .race Troll
  .goto 1458,70.16,59.18 -- Killian Hagey, Skinning Trainer (npc 7087)
  .trainprof skinning >> Train your next Skinning rank from Killian Hagey
  .note Classic, unverified in Forever: Journeyman needs level 10 and Skinning 50, and lifts the cap from 75 to 150.

-- Thunder Bluff.
step @zone 1456
  .race Troll
  .goto 1456,44.44,43.15 -- Mooranta, Skinning Trainer (npc 7089)
  .trainprof skinning >> Train your next Skinning rank from Mooranta
  .note Classic, unverified in Forever: Expert needs level 20 and Skinning 125, and lifts the cap from 150 to 225.

-- Back in Orgrimmar near level 30, for a rank missed on the way.
step @zone 1454
  .race Troll
  .goto 1454,63.36,45.42 -- Thuwd, Skinning Trainer (npc 7088)
  .trainprof skinning >> Train your next Skinning rank from Thuwd
  .note Only for a rank you missed (Classic, unverified in Forever: Expert needs level 20 and Skinning 125).
]]
)
