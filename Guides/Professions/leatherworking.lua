local ADDON_NAME, ns = ...

-- Leatherworking route track (docs/GUIDE-FORMAT.md "Profession tracks"), first cut for the Troll Hunter's default plan. It
-- is merged into a guide whose character's profession plan holds leatherworking (PLAN section 3.8).
-- Anchors are @zone and @level only, because the planner writes no .hub lines into the chapters: a step lands before the
-- first route step in that map (a capital the route visits), or at the first chapter of that level.
-- Every step with a position is gated .race Troll: its .goto and its anchor belong to this route, so another race's
-- guide (Tauren, Skyborne) gets none of them instead of an unmatched anchor. Their own steps join this file later. The
-- specialization step at the end has no position and is for every race.
-- The skill goal that rides beside the route (150) is Version 1's, which stops at level 30.
-- EVERY NUMBER HERE IS CLASSIC'S until the Forever client or recorded play says otherwise: the rank levels (Journeyman
-- 10, Expert 20), the skill a rank is trained from (50, 125), the caps (75, 150, 225), which trainer teaches which rank
-- (read from the trainers' titles) and the specialization (a level 40 quest at Leatherworking 225). VERIFY(launch): all
-- of them (docs/FOREVER-API-NOTES.md, Open probes, "Profession tracks").
-- Trainers come from the data pack's NPC titles (a QuestieDB Classic baseline plus Forever's layers; names and positions,
-- not walked in game yet), all Horde: Kamari 5811 (Journeyman Leatherworker) and Karolek 3365 (Expert Leatherworker) in
-- Orgrimmar; Dan Golthas 223 (Journeyman) and Arthur Moore 4588 (Expert) in Undercity; Mak 3008 (Journeyman), Tarn 11084
-- (Expert) and Una 3007 (Artisan) in Thunder Bluff. The pack has no profession records yet (no trainer lists, no
-- recipes), so .trainprof pins nothing by itself: each step carries its own .goto, and no recipe or spell ID is used.
ns.Professions:RegisterTrack(
	"leatherworking",
	[[
#track leatherworking

-- The first visit to Orgrimmar (level 10 on the shipped route). The first .trainprof of a track is the step whose skip
-- declines the profession (Engine/Progress.lua), so no rank step may come before it.
step @zone 1454
  .race Troll
  .goto 1454,63.28,44.75 -- Kamari, Journeyman Leatherworker (npc 5811)
  .trainprof leatherworking >> Learn Leatherworking from Kamari
  .sticky .skill leatherworking 150
  .note Leatherworking turns the leather you skin into armor: craft the recipes shown in orange or yellow. Classic's ranks, unverified in Forever: Apprentice to 75, Journeyman to 150.
  .note Karolek, the Expert Leatherworker, stands next to Kamari. Not for you? Skip this step and the other Leatherworking steps leave the guide.

-- Undercity: the next rank once Leatherworking is within 25 of its cap (the step passes by itself while it is lower).
step @zone 1458
  .race Troll
  .goto 1458,70.93,58.41 -- Dan Golthas, Journeyman Leatherworker (npc 223)
  .trainprof leatherworking >> Train your next Leatherworking rank from Dan Golthas
  .note Classic, unverified in Forever: Journeyman needs level 10 and Leatherworking 50, and lifts the cap from 75 to 150. Arthur Moore, next to Dan Golthas, is the Expert Leatherworker.

-- Thunder Bluff.
step @zone 1456
  .race Troll
  .goto 1456,42.32,42.61 -- Tarn, Expert Leatherworker (npc 11084)
  .trainprof leatherworking >> Train your next Leatherworking rank from Tarn
  .note Classic, unverified in Forever: Expert needs level 20 and Leatherworking 125, and lifts the cap from 150 to 225. Mak, the Journeyman Leatherworker, and Una, the Artisan Leatherworker (level 35 in Classic), are close by.

-- Back in Orgrimmar near level 30, for a rank missed on the way.
step @zone 1454
  .race Troll
  .goto 1454,62.81,44.15 -- Karolek, Expert Leatherworker (npc 3365)
  .trainprof leatherworking >> Train your next Leatherworking rank from Karolek
  .note Only for a rank you missed (Classic, unverified in Forever: Expert needs level 20 and Leatherworking 125). Kamari, the Journeyman Leatherworker, is next door.

-- The decided behavior (PLAN section 7): the specialization is a .todo at level 40; every step before it is neutral. No
-- chapter of a Version 1 guide (it stops at level 30) reaches level 40, so the lint notes the step and the engine drops it.
step @level 40
  .todo "Choose a Leatherworking specialization: Dragonscale, Elemental or Tribal. In Classic each is a quest at level 40 with Leatherworking 225 (Thorkaf Dragoneye in the Badlands, Brumn Winterhoof in the Arathi Highlands, Se'Jib in Stranglethorn Vale); unverified in Forever."
]]
)
