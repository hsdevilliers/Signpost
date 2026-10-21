local ADDON_NAME, ns = ...

-- Cooking route track (docs/GUIDE-FORMAT.md "Profession tracks"), first cut for the Troll Hunter's default plan. It is
-- merged into a guide whose character's profession plan holds cooking (PLAN section 3.8).
-- Anchors are @zone only, because the planner writes no .hub lines into the chapters: a step lands before the first route
-- step in that map (a capital the route visits).
-- Every step is gated .race Troll: its .goto and its anchor belong to this route, so another race's guide (Tauren,
-- Skyborne) gets none of them instead of an unmatched anchor. Their own steps join this file later.
-- The skill goal that rides beside the route (150) is Version 1's, which stops at level 30.
-- EVERY NUMBER HERE IS CLASSIC'S until the Forever client or recorded play says otherwise: the rank levels (Journeyman
-- 10, Expert 20), the skill a rank is trained from (50, 125) and the caps (75, 150, 225). VERIFY(launch): all of them
-- (docs/FOREVER-API-NOTES.md, Open probes, "Profession tracks"). The data names no trainer or book for Expert Cooking,
-- so no step points at it and a .todo says so.
-- The shipped route already holds Forever's new "Camping 101: Cooking" quest (Cook Torka, Razor Hill); what it gives
-- is not in the data. If it teaches Cooking, the learn step below passes by itself while the skill is more than 25
-- below its cap, and asks for the next rank when it is not, so either way it is safe.
-- Trainers come from the data pack's NPC titles (a QuestieDB Classic baseline plus Forever's layers; names and positions,
-- not walked in game yet): Zamja 3399 (Orgrimmar), Eunice Burch 4552 (Undercity) and Aska Mistrunner 3026 (Thunder
-- Bluff), all "Cooking Trainer", Horde. The pack has no profession records yet (no trainer lists, no recipes), so
-- .trainprof pins nothing by itself: each step carries its own .goto, and no recipe or spell ID is used.
ns.Professions:RegisterTrack(
	"cooking",
	[[
#track cooking

-- The first visit to Orgrimmar (level 10 on the shipped route). The first .trainprof of a track is the step whose skip
-- declines the profession (Engine/Progress.lua), so no rank step may come before it.
step @zone 1454
  .race Troll
  .goto 1454,57.4,53.96 -- Zamja, Cooking Trainer (npc 3399)
  .trainprof cooking >> Learn Cooking from Zamja
  .sticky .skill cooking 150
  .note Cook the meat and fish you loot: the recipes shown in orange or yellow raise Cooking. Classic's ranks, unverified in Forever: Apprentice to 75, Journeyman to 150.
  .note Not for you? Skip this step and the other Cooking steps leave the guide.

-- Undercity: the next rank once Cooking is within 25 of its cap (the step passes by itself while it is lower).
step @zone 1458
  .race Troll
  .goto 1458,62.14,44.91 -- Eunice Burch, Cooking Trainer (npc 4552)
  .trainprof cooking >> Train your next Cooking rank from Eunice Burch
  .note Classic, unverified in Forever: Journeyman needs level 10 and Cooking 50, and lifts the cap from 75 to 150.
  .todo "Expert Cooking (Classic: level 20, Cooking 125): where it is taught is not in the data yet, so no step points at it"

-- Thunder Bluff, for the rank missed on the way.
step @zone 1456
  .race Troll
  .goto 1456,50.72,53.11 -- Aska Mistrunner, Cooking Trainer (npc 3026)
  .trainprof cooking >> Train your next Cooking rank from Aska Mistrunner
  .note Only for a rank you missed (Classic, unverified in Forever: Journeyman needs level 10 and Cooking 50).
]]
)
