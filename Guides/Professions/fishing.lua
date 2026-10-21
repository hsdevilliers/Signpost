local ADDON_NAME, ns = ...

-- Fishing route track (docs/GUIDE-FORMAT.md "Profession tracks"), first cut for the Troll Hunter's default plan. It is
-- merged into a guide whose character's profession plan holds fishing (PLAN section 3.8).
-- Anchors are @zone only, because the planner writes no .hub lines into the chapters: a step lands before the first route
-- step in that map (a capital the route visits).
-- Every step is gated .race Troll: its .goto and its anchor belong to this route, so another race's guide (Tauren,
-- Skyborne) gets none of them instead of an unmatched anchor. Their own steps join this file later.
-- The skill goal that rides beside the route (75, the Apprentice cap: fishing is slow) is Version 1's, which stops at
-- level 30.
-- EVERY NUMBER HERE IS CLASSIC'S until the Forever client or recorded play says otherwise: the rank levels (Journeyman
-- 10, Expert 20), the skill a rank is trained from (50, 125) and the caps (75, 150, 225). VERIFY(launch): all of them
-- (docs/FOREVER-API-NOTES.md, Open probes, "Profession tracks"). The data names no trainer or book for Expert Fishing,
-- so no step points at it and a .todo says so.
-- Fishing spots (.fish needs a position) are not in the data: a .todo says so until play records them. The fishing
-- pole is a note, not a .buy: the pack's item records name no pole.
-- Trainers come from the data pack's NPC titles (a QuestieDB Classic baseline plus Forever's layers; names and positions,
-- not walked in game yet): Lumak 3332 (Orgrimmar), Armand Cromwell 4573 (Undercity) and Kah Mistrunner 3028 (Thunder
-- Bluff), all "Fishing Trainer", Horde; Shankys 3333, the "Fishing Supplies" vendor, stands next to Lumak. Lau'Tiki
-- 5941 (title "Fisherman", with the trainer flag) stands in Durotar, south of Sen'jin Village: the shipped route passes
-- Sen'jin at levels 7 to 9, but no step can anchor there without .hub lines. The pack has no profession records yet (no
-- trainer lists, no recipes), so .trainprof pins nothing by itself: each step carries its own .goto, and no recipe or
-- spell ID is used.
ns.Professions:RegisterTrack(
	"fishing",
	[[
#track fishing

-- The first visit to Orgrimmar (level 10 on the shipped route). The first .trainprof of a track is the step whose skip
-- declines the profession (Engine/Progress.lua), so no rank step may come before it.
step @zone 1454
  .race Troll
  .goto 1454,69.8,29.21 -- Lumak, Fishing Trainer (npc 3332)
  .trainprof fishing >> Learn Fishing from Lumak
  .sticky .skill fishing 75
  .note You need a fishing pole: Shankys, the fishing supplier next to Lumak, sells them in Classic (unverified in Forever). Classic's ranks, unverified in Forever: Apprentice to 75, Journeyman to 150.
  .note Not for you? Skip this step and the other Fishing steps leave the guide.
  .todo "Where to fish: no fishing spots are in the data yet, so no step can point at water. Fish in any water you pass while you wait or travel."

-- Undercity: the next rank once Fishing is within 25 of its cap (the step passes by itself while it is lower).
step @zone 1458
  .race Troll
  .goto 1458,80.7,31.26 -- Armand Cromwell, Fishing Trainer (npc 4573)
  .trainprof fishing >> Train your next Fishing rank from Armand Cromwell
  .note Classic, unverified in Forever: Journeyman needs level 10 and Fishing 50, and lifts the cap from 75 to 150.
  .todo "Expert Fishing (Classic: level 20, Fishing 125): where it is taught is not in the data yet, so no step points at it"

-- Thunder Bluff, for the rank missed on the way.
step @zone 1456
  .race Troll
  .goto 1456,56.13,46.38 -- Kah Mistrunner, Fishing Trainer (npc 3028)
  .trainprof fishing >> Train your next Fishing rank from Kah Mistrunner
  .note Only for a rank you missed (Classic, unverified in Forever: Journeyman needs level 10 and Fishing 50).
]]
)
