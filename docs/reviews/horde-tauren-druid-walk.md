# Tauren Druid (HARDCORE): a player's walk through the planner's route

Reviewer: worker A2 of batch 1, 2026-10-21. Subject: the guide on feat/batch-1 at 807be15, the Route Planner's "thorough alt 3" install: 23 chapters, 317 steps (44 of them travel), 190 quests,
47 `.todo` lines in 43 steps, 27h43 planned, 27h36 simulated. It replaces two generations I reviewed before (1a2ac40: 23h42 planned; 61901c9: 25 chapters, 72 `.todo`, 25h18); their chapter names are gone.
Source: the private pack of 2026-10-21 (QuestieDB's Classic baseline plus its Forever layers), the planner's report, the simulator and a step-by-step walk script. NOTHING was seen in the game;
Classic facts quoted from memory say so. Backlog items written for this review are named in quotes.

## Verdict
Playable on paper for a careful player, still not safe to hand to a hardcore one. Four things decide it: (1) 26 of the 47 `.todo` lines are zone-change placeholders (22 "find your own way" or "cast
Teleport", 4 "different continents") while travel is 11h15 of the 27h43 (41%): three Moonglade round trips (6 placeholders, 20 to 26 minutes each way in the planner's price) and two trips to the Eastern
Kingdoms (8); (2) the data ranks no creature that is new in Forever and gives no creature a level, so HARDCORE safety rests on hand-made lists (62 rules: 42 skips, 20 notes); (3) 51 of 190 quests (38% of
their experience) are not in the Classic XP seed and get 10% of the level, among them five Undercity library quests; (4) 5h03 (18% of the play time) is grinding at `.level` gates, 67,000 of its 71,766
experience in three gates (levels 22, 29, 30), and no gate says where. Lint and `guide_sim --check` are clean: they cannot see any of it. The quest log peaks at 10 (the game holds 40), empty at the end.

## The first 60 steps (tauren-druid-01 to -05)
- 1-36 Mulgore, 2h53, level 1 to 10. Step 1 accepts A Humble Task and The Hunt Begins at 43.9,76.7; 2 is level 3 after 14 minutes of plainstriders; 5 is the first hand-in round and the druid's first class
  quest, Verdant Note (3094), taken and handed in on the spot (44.5,77.5); 11-14 The Adventurer, The Great Outdoors, Camping 101: Cooking; 15-25 the Bloodhoof loop (Poison Water, Swoop Hunting, Thunderhorn
  Totem, Kyle's Gone Missing!, Mazzranache, Longwalker Malah, The Ravaged Caravan); 26-28 Sharing the Land (745, which generation 1 missed) and, at level 10, The Hunter's Way and Heeding the Call (5926,
  the Bear Form chain); 29-35 Wildmane Totem, A Sacred Burial, The Venture Co.; 36 `.todo "Walk from Mulgore to Thunder Bluff: the guide has no waypoints for this yet"` + `.zone 1456`.
- 37-44 Thunder Bluff (0h09): Traditions of the Bluff (97485; objective 2 has no position: `.todo`), the flight path, Heeding the Call handed in, Moonglade (5922) accepted with a note that Teleport: Moonglade
  is not assumed; 44 walks back to Mulgore (placeholder). 45-52 Mulgore (0h41): Preparation for Ceremony, Dangers of the Windfury, The Venture Co., The Battleboars, The Longwalkers.
- 53-55 the Moonglade round trip (26 minutes there, 22 back, 630 experience at the far end): 53 is `.todo "Go to Moonglade: cast Teleport: Moonglade if you have it ... else the way is not in the data"` plus the new
  note "Do not walk it: from Classic memory the road overland runs through Felwood or Winterspring, zones for levels 48 and up"; 54 hands in Moonglade (5922), takes and hands in Great Bear Spirit (5930, `.todo`:
  no objective); 55 is the return placeholder. 56-59 Thunder Bluff: Back to Thunder Bluff (5932), Body and Heart (6002: `.todo`, no objective; a note says it summons Lunaclaw, be buffed and healed),
  Stalk With The Earthmother (76156/76160, an objective with no position), then the walk to the Barrens (placeholder). Level 12 comes at 4h41, 102 minutes after level 11.
- 60 The Barrens, Crossroads (tauren-druid-05, levels 12 to 15): The Forgotten Pools, Plainstrider Menace at 52.3,31.9; 61 the flight path.

## A sample from the middle (tauren-druid-16, steps 210-234, Hillsbrad Foothills, levels 23 to 25)
The longest stay in the Eastern Kingdoms: 2h05, 14 quests, 55,000 experience (leg 22). Tarren Mill at 61.4,19.1 gives six quests at once (1066, 496, 501, 527, 549, 498); the Battle of Hillsbrad chain (527,
528, 529, 532) is four hand-ins at 62.3,20.5 for kills near 32,35 and 33,46 (Classic, from memory: Alliance farmers and town NPCs, unproven for HARDCORE); step 219 Souvenirs of Death has an objective with no
position; 222 is the `.level 25` gate (4,600 experience, 28 kills, 20 minutes); 230, 232 and 234 are placeholders (Silverpine, Undercity, the Barrens)
around one library item, The Dalaran Digest (78127, a guessed 2,320).

## The last chapter (tauren-druid-23, The Barrens, levels 29 to 30, 16 steps)
It starts at 29: The Tear of the Moons (857: a strongbox in Bael'dun Keep, a dwarf fort with a boss as I remember Classic; the data flags nobody) and half of
Gathering the Cure (6128, taken at 22; its other half is at step 11). Then
flights to Thunder Bluff (Melor Sends Word, 1130) and Splintertree Post: The Lost Pages (6504, three objectives with no position) and the `.level 30` gate, "Grind about 18,000 experience ... about 95 kills",
70 minutes. It ends with the third Moonglade round trip for two class quests (6129 Curing the Sick and 6130 Power over Poison): steps 13-15 and the last 43 minutes of the route. Nothing is left in the log.

## Findings, ranked (impossible, dangerous, confusing, missing)
1. IMPOSSIBLE as written: 26 zone changes are placeholders, 19 objectives have no position (Echeyakee, The Warsong Reports x3, The Lost Pages x3, Curing the Sick ...) and Great Bear Spirit (5930) and Body and
   Heart (6002) have no objective: the step says what, not where or how. Items "Zone changes in planned guides are placeholders" and "Tauren Druid guide: all 46 zone changes are placeholders" (26 now).
2. IMPOSSIBLE for a druid without the spell: the six Moonglade steps (levels 11, 20 to 22, 30) say "cast Teleport: Moonglade if you have it ... Do not walk it" (WP-F's HARDCORE-safe wording). The Bear Form
   hand-ins, Lessons Anew, Aquatic Form and the Cat Form chain all go there; whether Forever gives the spell is open: "Does a Forever druid get Teleport: Moonglade ...".
3. DANGEROUS: six routed item quests have an elite or rare among their item sources and carry a note (the planner drops a quest only when ALL sources are elite): 869 and 865 (Takk the Leaper), 845
   (Swiftmane), 855 (Rocklance, Warlord Krom'zar), 86576 (Sister Riven, Bloodfury Ripper), 1104 Salt Flat Venom (Vile Sting). Dungeon and elite-only quests are `#skipquest`ed now: 1013, 1491, 6921, 1486, 5726,
   850, 879, 6621, 1150, 5147 (the batch's rules, merged).
4. DANGEROUS: named targets the data cannot rank (Classic, from memory, unproven; "No creature new in Forever carries an elite flag ..."): 6629 Kill Grundig Darkcloud, 896 (Boss Copperplug), 881
   Echeyakee (a named rare), 876 Serena Bloodfeather, the Battle of Hillsbrad chain, 857, 843/846/849 (Gann Stonespire's), 6543. Skipped by this review: 92422, 92706, 97003 and the Gloomrise nest (96241,
   96259, 96260, 96261). Also Classic from memory: Hillsbrad at 23 to 25, Thousand Needles at 27 to 29.
5. DOUBTFUL: 51 of 190 quests get 10% of the level as experience. The five routed library quests (Owen Thadd: 78127, 78143, 78149, 79097, 78150) carry level 20 for a required level 1 and 2,320 each (11,600;
   79094 and 79096 are out); the three Undercity legs (levels 19-20, 23, 25) pay 32,800 for 0h38, nearly three times the route's pace, 11,600 of it the guess: "The Undercity library quests ... what do they give?".
6. CONFUSING: six grind gates (levels 15, 19, 22, 25, 29, 30) ask for about 3, 450, 19,000, 4,600, 30,000 and 18,000 experience (0, 2, 93, 20, 117, 70 minutes). They say how much, not where or why (the +1
   margin); the pack gives creatures no level, so no place can be named. The gate at 22 sits in Moonglade (a reviewer's item "HARDCORE grind gates do not say why ..." quotes the previous generation). Grinding was
   1h05 in generation 2 and is 5h03 now: I did not find out why (the search's grains disagree by 11%, the report warns), "The planner's search is rough".
7. LEVELS: nothing is two levels above the character where its step ends. The walk flags six accepts that are two above at the start of a step that levels the character (96659, 99079, 97289, 97290, 97291,
   98094); the other 6 `.level` lines (4, 5, 10, 12, 17, 20) ask for the quests' required levels and make the route wait for nothing.
8. MISSING: the way back from Moonglade is "your hearthstone or a flight path if you have one" (unconfirmed, see 2); no step says where to grind (6).

## The user's rule: a quest offered where the player stands (generation 3)
Method (the Skyborne worker's, 150 and 250 yards, scratch script `gaps.py` of this review, not in the repository): for each step, the planner's kept quests with a giver within 150 yards, offered by the
planner's own availability and profit test at that level, with an objective within 250 yards of that step or the next six that work, never accepted. Generation 1 left out 745 Sharing the Land (taken in
generations 2 and 3); generation 2 left out 1104 Salt Flat Venom and 6442 Naga at the Zoram Strand. Generation 3 takes 1104 (chapter 22) and leaves out no quest: 0 gaps. 6442 is not offered where the route
stands. Three quests are offered at Durotar and Thunder Bluff steps but have no objective position (784, 99048, 98823), so the rule cannot judge them. Nothing forces this: the search chose it, so the post-check stays.

## Class quests (20 routed, 2 alternatives)
3094 at 3; the Bear Form chain 5926, 5922, 5930 at 11, 5932 and 6002 at 12 (opens 10); Lessons Anew 6126 at 21, 6127 at 22, 6128, 6129, 6130 at 30 (opens 14: 16 levels late; 6128 is held for 113 steps);
Aquatic Form 26, 28, 30 at 21, 31 at 22 (opens 16); Cat Form 98340, 98405 at 21, 98342, 98739, 98362 at 22 (opens 20). Six come more than five levels after they open: the planner found it cheaper than its 20
minutes a level. 5927 and 5928 are alternatives to 5926 (`#skipquest`). `.todo`: 5930 and 6002 (no objective), 6127, 30 and 6129 (an objective with no position). The three Cat Form relics share one position
(72.4,66.0, the Stormrage Barrow Dens; fan guides say the spirits there attack on sight, a note says so). The druid weapon quest is not known: "Is quest 98823 (Earthen Echo) a druid weapon quest ...".

## Left out, and what the review changed
`#skipquest` has 61 lines: 34 HARDCORE (elites, dungeons, escorts, named targets), 10 alternatives, 9 "not finished by this route" (765, 771, 3376, 3923, 79007, 79094, 79096, 96825, 99080), 8 other (cloth with no
source 7820 and 76240, battlegrounds 8368 and 8426, four quests of other classes). The planner also leaves out 52 quests slower than grinding (the slowest against it: 2842, 742, 787, 860, 886, 6542, 1361, 235).
Rules (docs/HARDCORE.md, tools/hardcore_rules.json): 23 added by this review plus the field `class_quest_of` for 98251, 98252, 65601 (Warlock) and 99108 (Warrior): escorts 6523, 6544, 6641, 6482, 4770, 4904
(Classic, from memory), Blackfathom Deeps 6562 and 6563, the named Forever targets, notes on the Moonglade quests; not ruled on for want of evidence: 76156, 76160, 98823, 527,
857. Measured on generation 2, not repeated: HARDCORE takes 17 of the 61 quests of levels 26 to 31
(82,000 of 259,000 experience) out of the pool; a +2 margin from level 26 saves half an hour (24h46 against 25h18): "HARDCORE at levels 26 to 30: keep one level of margin ...". Under uncertain assumptions alt 3
runs 26h33 at the median (23h06 to 31h30), fastest in 92% of runs; the thorough search warns that its grains differ by 11%.

## Recipe: make this guide again, and check it
Inputs: tools/hardcore_rules.json, tools/drafts.json (entry horde-tauren-druid: `--exclude 7820` and `76240`, `--chain 98340,98405,98342,98739,98362` on druid-cat-form-20, "hardcore": true, the "planned"
note the installer rewrites; no `"require"` list: docs/PLANNER.md "Required quests" can force a quest in), Guides/HordeTaurenDruid.lua (the installer replaces only its `#skipquest` and `#include` lines),
Classes/DRUID.lua, the pack in ../Signpost_Data. Guides/, both TOCs and tools/drafts.json must be committed (else `--force`).
1. `python tools/route_planner.py tauren --preset all --install --quiet` (the thorough search alone took 735 s: run it in the background) writes plans/horde-tauren-druid/ (gitignored), the
   chapters tauren-druid-NN-<zone>, the guide's `#skipquest`/`#include` lines, both TOCs and the "planned" note, and runs StyLua.
2. `python tools/guide_lint.py --strict` (0 errors, 0 warnings); `python tools/guide_sim.py --check` (no findings); `& .\tools\check.ps1`.
3. Post-checks from the repository root, PowerShell: `Select-String -Path Guides\Chapters\tauren-druid-*.lua -Pattern '<p>'` with <p> =
   `^\s*\.accept (6523|6544|6641|6482|4770|4904|6562|6563|92422|92706|97003|96241|96259|96260|96261|98251|98252|65601|99108)\b`: none (this review's skips);
   `^\s*\.accept (850|879|906|1013|1150|1491|5147|6621|6921)\b`: none (A1's skips);
   `^\s*\.accept (3094|5926|5922|5930|5932|6002|6126|6127|6128|6129|6130|26|28|30|31|98340|98405|98342|98739|98362)\b`: 20 lines (the class quests);
   `^\s*\.accept (745|1104|6442)\b`: 2 lines (745 and 1104; 6442 is no gap here); `\.todo`: 47; `^\s*\.level`: 12; `^\s*\.zone`: 26. In the guide file `#skipquest`: 61, `#include`: 23.
4. The user's rule: `python gaps.py --root <worktree> --guide horde-tauren-druid --all` (scratch script, method above) prints the gaps and exits 1 when there are any: 0 now, plus the 3 it cannot judge.
   `--guide horde-troll-hunter` and `horde-windshaper-druid` work too. Compare with a `--preset beam --no-write` run if in doubt.
