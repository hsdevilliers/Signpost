# Tauren Druid (HARDCORE): a player's walk through the planner's route

Reviewer: worker A2 of batch 1, 2026-10-21. Subject: the guide the Route Planner installed on this branch (generation 2, 61901c9: 25 chapters, 343 steps, 201 quests,
72 `.todo` lines, 25h18 planned, 19h13 simulated) after a review of generation 1 (1a2ac40: 26 chapters, 211 quests, 67 `.todo`, 23h42 planned, 18h21 simulated).
Source: the private pack of 2026-10-20 (QuestieDB's Classic baseline plus its Forever layers), the planner's report, the simulator and git history. NOTHING was seen in
the game; Classic facts quoted from memory say so. Backlog items written for this review are named in quotes.

## Verdict
Playable on paper for a careful player, not yet safe to hand to a hardcore one. Four things decide it: (1) all 46 zone changes are placeholders (`.todo` + `.zone`: 30 "no
route yet", 16 "no crossing coordinates yet"): three Moonglade round trips (22 to 25 minutes each way) and two round trips to the Eastern Kingdoms (Undercity and Silverpine
at 20 to 22, Undercity and Hillsbrad at 28 to 29) are left to the player; (2) the data ranks no creature that is new in Forever and misses objectives, so HARDCORE safety
rests on lists made by hand: this review adds 23 rules, and eight quests with an elite source or in a dungeon, and four named targets, stay in the route until A1's rules are merged;
(3) 36% of the experience is a guess (52 of 201 quests have no entry in the Classic XP seed and get 10% of the level), among them the Undercity library quests that take a
Tauren across the sea at level 20; (4) five class quests carry a `.todo`. All 20 class quests a Tauren can do are routed (5927 and 5928 are alternatives to 5926). Lint and
`guide_sim --check` are clean on this: they cannot see any of it. The quest log never holds more than 15 quests and is empty at the end.

## The first 60 steps (generation 2)
- 1-36 Mulgore, 2h41, level 1 to 10. Step 1 accepts A Humble Task (Chief Hawkwind, 43.9,76.7) and The Hunt Begins (Grull Hawkwind); 2 is level 3 after 14 minutes of
  plainstriders; 5 is the first hand-in round and the druid's first class quest, Verdant Note (3094), handed in to Gart Mistrunner (44.6,76.5); 7-10 Rites of the Earthmother and
  Rite of Strength; 11-14 The Adventurer, The Great Outdoors (a campfire) and Camping 101: Cooking (a kill credit on a cook); 15-27 the Bloodhoof loop (Poison Water, Swoop
  Hunting, Kyle's Gone Missing, Thunderhorn Totem, Mazzranache, Sharing the Land); 28 level 10: Heeding the Call (5926, the Bear Form chain) and The Hunter's Way; 29-35 A Sacred
  Burial, the Venture Co., Wildmane Totem. 36 `.todo "travel from Mulgore to Thunder Bluff: the travel graph has no route yet"` + `.zone 1456`.
- 37-47 Thunder Bluff (tauren-druid-02, 0h24): Traditions of the Bluff (one item has no position: `.todo`), Moonglade (5922) accepted at 40 with the note that Moonglade is far
  and that Teleport: Moonglade is unconfirmed; four crossings between Mulgore and Thunder Bluff in the first 3h04 (steps 36, 41, 44, 47).
- 48-55 (tauren-druid-03): the Bear Form chain in one trip: Moonglade (placeholder, 26 minutes), Great Bear Spirit (no objective in the data: `.todo`, "read what it asks in the
  quest log"), Back to Thunder Bluff, Body and Heart (summons Lunaclaw: `.todo` and the note to buff and heal first); level 12 at 3h06; then the Crossroads (placeholder).
- 56-60 the Crossroads (tauren-druid-04): six pick-ups at 52,30, Plainstrider Menace, The Zhevra, Raptor Thieves and Disrupt the Attacks together; level 13 at 3h44.

## A sample from the middle (steps 94-132, tauren-druid-07, levels 15 to 18)
The longest stretch without a crossing: 39 steps, 3h16 in the planner's price, 23 quests, 59,000 experience around the Crossroads and Ratchet. It holds what a hardcore player
should look at twice (Classic, from memory): 850 Kolkar Leaders kills the named Barak Kodobane; 881 Echeyakee is a named rare (`.todo`, no position); 865 Raptor Horns
and 896 Miner's Fortune (Boss Copperplug); 6543 The Warsong Reports has three items with no position; 1491 Smart Drinks (finding 3). The Samophlange chain (894 to 902) is
valves and a console key around 52.4,11.7; the Forever quests of Vrang Wildgore (95494 to 95621, level 18) are taken at 43.8,12.2 and done on the spot.

## The last chapter (tauren-druid-25, Thousand Needles and the Barrens, level 29 to 30)
Steps 335-343: Hardened Shells (1105) and Load Lightening (1176) at the Salt Flats, but not Salt Flat Venom (1104), offered by the same NPC (the user's rule, below); The Tear of
the Moons (857: the strongbox in Bael'dun Keep, a dwarf fort with a General Twinbraid as I remember Classic; the data flags nobody there) and a last step `.level 30 -- reach it first:
kill or grind on the way`, which names no amount. It ends at level 30 with nothing left in the log.

## Findings, ranked (impossible, dangerous, confusing, missing)
1. IMPOSSIBLE as written: 46 zone changes are placeholders and 24 objectives have no position (Echeyakee, The Warsong Reports x3, Test of Endurance, Traditions of the Bluff ...):
   the step says what, not where or how. Items "Zone changes in planned guides are placeholders" and "Thin Forever quest records and chains the pack cannot order".
2. IMPOSSIBLE as written: Great Bear Spirit (5930) and Body and Heart (6002) have no objective in the data: accept, `.todo`, hand in. The second summons Lunaclaw (a note says to
   buff and heal first). Both are class quests and mandatory.
3. DANGEROUS: quests with an elite or rare among their item sources, which the planner keeps because it drops a quest only when ALL sources are elite: 869 and 865 (Takk the Leaper),
   845 (Swiftmane), 855 (Rocklance, Warlord Krom'zar), 86576 (Sister Riven, Bloodfury Ripper) and 1491 Smart Drinks, whose every known source is a Wailing Caverns elite (one
   source has no rank data, so the "all elite" test failed). A1's rules (notes for five, a skip for 1491) cover them once merged; this branch's rules do not.
4. DANGEROUS: dungeon quests: 1013 The Book of Ur (Shadowfang Keep), 6921 Amongst the Ruins (Blackfathom Deeps) and 1491 are routed (their zones, 310, 221 and 279, are instance map
   ids); 1489 and 1490 (Hamuul Runetotem, Nara Wildmane) are the harmless deliveries that lead to the Wailing Caverns chain. A1's rules skip the first three (A1's item: "Dungeon and raid quests are not recognized").
5. DANGEROUS: named targets the data cannot rank: skipped by this review: 92422, 92706, 97003 and the Gloomrise nest (96241, 96259, 96260, 96261); skipped by A1's rules once merged: 850, 879
   (906 follows it), 6621, 1150. Still routed, Classic from memory and unproven: 6629 Kill Grundig Darkcloud, 896 (Boss Copperplug), 881, 876 Serena Bloodfeather (held 99 steps), the
   Battle of Hillsbrad chain (527, 528, 529, 532, 539: Hillsbrad farm and town-hall NPCs), 857, 843/846/849 at Bael'dun. "No creature new in Forever carries an elite flag ...".
6. DANGEROUS (Classic, from memory, not proof): Hillsbrad at 24 to 29, the Kolkar camps, Bael'dun Keep, Thousand Needles at 26 to 30, the Thistlefur satyrs at 24.
7. DOUBTFUL: 52 of 201 quests get 10% of the level as experience. The Undercity library quests (Owen Thadd: 78127, 78143, 78149, 79096, 79097, 78150) carry a level 20 for a
   required level 1 and 2,320 experience each in the plan (six: 13,900), a guess; the leg that visits them (leg 22, Undercity at 20 to 21) is 28,800 planned experience for 0h43 and
   25 minutes of travel across the sea.
8. CONFUSING: chapters are named after their first zone: tauren-druid-11-thunder-bluff holds Thunder Bluff, Stonetalon, Moonglade and Undercity; tauren-druid-24-undercity holds
   Undercity, Hillsbrad, Ashenvale and Thousand Needles. 9 of 44 legs last five minutes or less, one hand-in each. Four steps are only a `.level` gate (17, 28, 29, 30) with no amount
   ("A grind step says how much experience to grind"); 4 gates stall the simulation for 1h02 in all (3% of the experience is ground).
9. LEVELS: nothing is two levels above the character. The walk flags two accepts that are one above at the start of a step that levels the character (96659 The Adventurer at 4,
   99079 Longwalker Malah at 7); the 13 `.level` lines ask for the quests' required levels.
10. MISSING: the user's rule, quests offered where the player stands (next section). MISSING: nothing says how a druid gets back from Moonglade or to the Eastern Kingdoms (see 1).

## The user's rule: a quest offered where the player stands (generation 2)
Method (the Skyborne worker's, 150 and 250 yards, scratch script `gaps.py` of this review): for each step, the planner's kept quests with a giver within 150 yards, offered by the
planner's own availability and profit test at that level, with an objective within 250 yards of that step or the next six that work, never accepted. Generation 1 left out 745
Sharing the Land (level 8, step 20; taken in generation 2); generation 2 leaves out two: 1104 Salt Flat Venom (level 30, 4 yards from the Salt Flats step, ~4,900 experience at 29)
and 6442 Naga at the Zoram Strand (level 19, at 26, ~1,600). Generation 1 took both, so it is the thorough route's choice, as the Skyborne finding says. No rule or manifest hint
fixes it: the manifest can leave a quest out (`--exclude`) or order quests already routed (`--chain`), none can make the planner take one. It waits for WP-E1's planner fix; the
post-check below says when it has worked.

## Class quests (20 routed, 2 alternatives)
3094 at 3; the Bear Form chain 5926, 5922, 5930, 5932, 6002 at 11 (opens 10); Lessons Anew 6126 at 18, 6127 at 19, 6128 and 6129 at 20, 6130 at 23 (opens 14: nine levels late);
Aquatic Form 26 at 18, 28 and 30 at 19, 31 at 20 (opens 16); Cat Form 98340, 98405, 98342 and 98739 at 20, 98362 at 23 (opens 20). Three Moonglade round trips (levels 11, 18 to 19,
20), each a placeholder both ways. `.todo`: 5930 and 6002 (no objective), 6127, 30 and 6129 (an objective with no position). The three Cat Form relics share one position (72.4,66.0,
in the Stormrage Barrow Dens: fan guides say the spirits there attack on sight; a note says so). The druid weapon quest is not known: "Is quest 98823 (Earthen Echo) a druid weapon
quest ...". Teleport: Moonglade is assumed by nothing: "Does a Forever druid get Teleport: Moonglade ...".

## What the review changed (generation 1 to 2) and what it measured
Rules (docs/HARDCORE.md, tools/hardcore_rules.json, 23 new, `class_quest_of` for the four quests of other classes: 98251, 98252, 65601 Warlock, 99108 Warrior): escorts 6523, 6544,
6641, 6482, 4770, 4904 (Classic, from memory), Blackfathom Deeps 6562 and 6563, the named Forever targets above, notes on the Moonglade quests. Taken out again for want of evidence:
76156, 76160, 76240 (maybe a Rogue's), 98823, 527, 857. Cost: 23h42 to 25h18 planned (+7%), 18h21 to 19h13 simulated (+5%), grinding 0h13 to 1h05.
HARDCORE takes 17 of the 61 quests of levels 26 to 31 out of the pool (82,000 of 259,000 experience): the elite criterion 7 (42,000), this review's Gloomrise rules 4 (30,000), two
escorts (5,000), knock-ons 3, slower than grinding 1; A1's pending rules take five more (21,000). The same thorough search with a +2 margin from level 26: 24h46 against 25h18
planned, 19h00 against 19h13 simulated: half an hour, inside the search's noise (the default beam alone gives 29h02 and 9h36 of grinding with this branch's rules and 27h06 and 4h52
with A1's added; "The planner's search is rough"). The question for the user is in the backlog: "HARDCORE at levels 26 to 30: keep one level of margin, and what about the Gloomrise nest?".

## Recipe: make this guide again, and check it
Inputs: tools/hardcore_rules.json (rules by quest id; A1's apply to this guide once merged, no duplicate ids), tools/drafts.json (entry horde-tauren-druid: the chapter hints of the
old drafts stay for the planner: `--exclude 7820` and `76240` with their reason, `--chain 98340,98405,98342,98739,98362` on druid-cat-form-20, "hardcore": true, the "planned" note the
installer rewrites), Guides/HordeTaurenDruid.lua (the installer replaces only its `#skipquest` and `#include` lines), Classes/DRUID.lua (unchanged), the pack in ../Signpost_Data.
Guides/, both TOCs and tools/drafts.json must be committed (else `--force`).
1. `python tools/route_planner.py tauren --preset all --install --quiet` (12 minutes on a busy machine: run it in the background) writes plans/horde-tauren-druid/ (gitignored), the
   chapters tauren-druid-NN-<zone>, the guide's `#skipquest`/`#include` lines, both TOCs and the "planned" note, and runs StyLua.
2. `python tools/guide_lint.py --strict` (0 errors, 0 warnings); `python tools/guide_sim.py --check` (no findings); `& .\tools\check.ps1`.
3. Post-checks from the repository root, PowerShell: `Select-String -Path Guides\Chapters\tauren-druid-*.lua -Pattern '<p>'` with <p> =
   `^\s*\.accept (6523|6544|6641|6482|4770|4904|6562|6563|92422|92706|97003|96241|96259|96260|96261|98251|98252|65601|99108)\b`: none (this review's skips);
   `^\s*\.accept (850|879|906|1013|1150|1491|5147|6621|6921)\b`: none (A1's skips, once merged);
   `^\s*\.accept (3094|5926|5922|5930|5932|6002|6126|6127|6128|6129|6130|26|28|30|31|98340|98405|98342|98739|98362)\b`: 20 lines (the class quests);
   `^\s*\.accept (745|1104|6442)\b`: 3 lines once E1's same-area fix has worked (generation 2 has 745 only); `\.todo`: about 72; `^\s*\.level`: about 13.
4. The user's rule: `python gaps.py --root <worktree> --guide horde-tauren-druid --all` (scratch script of this review, method above) prints the gaps and exits 1 when there are any:
   2 now (6442, 1104), 0 expected after E1's fix. `--guide horde-troll-hunter` and `horde-windshaper-druid` work too. Compare with a `--preset beam --no-write` run if in doubt.
