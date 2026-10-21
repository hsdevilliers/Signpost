# Skyborne Druid (HARDCORE): a player's walk through the planner's route

Reviewer: worker A1 of batch 1, 2026-10-21, final version. Subject: the guide as it stands in commit 9ca64ab: the Route Planner's `thorough` route, completeness off, the island exit required: 19 chapters, 304 steps,
201 quests, 33 `.todo`, 24h14 planned, 24h03 simulated. Earlier generations: 1 (PR #42: 23 chapters, 204 quests, 65 `.todo`, 17h36 simulated, no island exit) and an intermediate one that went back to Zephras Isle at level 30.
Source: the private pack as rebuilt on 2026-10-21 (QuestieDB's Classic baseline plus its Forever layers), the planner's report, the simulator, git history. NOTHING was seen in the game; Classic facts from memory say so.

## Verdict
Playable on paper. The exit is real: the whole island story, the finale with warnings, the airship step and the Mulgore hand-in are in the route, all VERIFY(beta) (fan guides and the quest data). The earlier return to the
island is gone (the manifest requires 94638 too). Open: the Moonglade part of the Bear Form chain comes at level 25; 20% of the planned time is level-gate grinding; quests offered where the player stands are left out (all named);
33 placeholders; the busted placement spec is red for this guide (3 cases). Lint, `guide_sim --check` and the tool tests are clean and cannot see any of this.

## The island and the exit, as a player reads them (chapter 01: 85 steps, levels 1 to 15, left after 5h29)
- 1-18 Coming of Age, Harmony in Balance, a joined step 4 with the class quest A Student of Nature (92485), Foul Matriarch in 11 (level 5, a named ursera), Shen'dar Village. 19-40 the island story proper: Among the Faithful,
  Havoc in the Highlands, The Western Watch, To Valanaar, The Grand Skyseer, the Broken Construct chain, A Firm Response, In Service of Zephras. 41-47 the island-side class quests at level 10: The Great Ursera Spirit, then
  Strength and Mercy (kill Ur'endra near 53.7,65), handed in in 47. 48-77 Tower Defense, Return to Valanaar, The Turncoat, Desperate Times, Elegael Thornpaw's chain, the Strange Hermit, Mercy Falls on Deaf Ears.
- The finale: 62-64 Prepare for Battle, Making Our Move (the Al'Aketh guardian, spiritcaller and blademaster near 61,51), The Inner Sanctum, and Confront Lorthuna is taken; 78 is the fight (explore at 74.9,53.0). Each of the three
  `.accept` lines is followed by a `.note VERIFY(beta): ...` (rules 92947, 93958, 92646); the last: "a scripted boss fight at the Shrine of Akir. Fan guides say Rohash is summoned and Kirin Tor and Earthen Ring reinforcements
  arrive. Go in fully healed and buffed with your escape ready, fight beside the reinforcements, and leave if it goes badly. It is part of the chain that takes you off the island, so there is no way round it that we know of."
  The note sits at step 64, fourteen steps before the fight in 78, which has no note of its own.
- 80-82 hand-ins with Ayessa Dawnsinger and Talaanis Shadowsong: The Fate of Zephras, What Comes Next, then The Earthen Ring is taken (95349 is done at level 15, opens at 7).
- 83 `.zone 1412 >> Take the airship from Valanaar's southwest dock (Zephras Isle) to Skywatcher Plateau, beside Thunder Bluff (Mulgore)`, the note "Expect to wait about 7 to 8 minutes for it." and a `.todo`: "Not verified in the game: the
  dock, the airship's name, the landing spot and whether you can board before the quest chain asks you to. This step is done when you arrive in Mulgore." The simulator prices the ride at nothing.
- 84 Mulgore (33.4,22.6): The Earthen Ring is handed in, Welcome to Azeroth and Child of Nature are taken. 85 `.todo "Walk from Mulgore to Thunder Bluff ..."` + `.zone 1456`. Chapter 02 (Thunder Bluff, level 15): Traditions of the
  Bluff, the flight master (`.fp`), Child of Nature handed in and Moonglade (94913) taken, then a walk to Orgrimmar.

## A sample from the middle (steps 150-200, levels 20 to 24)
Chapters 05-07: Undercity's library quests (invented levels: 20, required 1), a walking placeholder to Silverpine, then Silverpine in one run (chapter 06, 28 steps, levels 21 to 23) including Ambermill Keep's Dalaran wizards (479, 480 The
Weaver with a note on Archmage Ataeric, 95981 Watching the Roads), and Hillsbrad Foothills (chapter 07, 23 to 24). From memory of Classic these are the places where a careful player gets hurt at this level.

## The last chapters (17-19, levels 29 to 30)
Ashenvale (chapter 16, 194 simulated minutes): Satyr Horns, The Lost Pages (three objectives with no position), and a grind: "Grind about 41,000 experience before you go on: about 220 kills" for level 29. Chapter 17 is Mulgore again for 18 minutes:
the level 4 to 9 quests Longwalker Malah, Kyle's Gone Missing!, The Ravaged Caravan and others, grey at level 29 (quests with unknown XP are never filtered out). Chapter 18, The Tear of the Moons. Chapter 19, Thousand Needles (96 min): the Salt Flats
quests (a note warns of Vile Sting) and a last grind, "about 18,000 experience, about 93 kills", to level 30. Nothing is left in the log (by the guide's own accepts and hand-ins at most 10 quests are held).

## What is still a placeholder (33 `.todo`; 17 `.zone`, 11 `.fly`, 7 `.fp` are real steps)
12 "Walk from X to Y: the guide has no waypoints for this yet"; 2 "different continents ... no dock" (Barrens-Undercity, Undercity-Ashenvale); the airship's unverified words; 13 objectives with no position in the pack; 3 relics of The Great Windborne
Cat Spirit "only in places this guide does not go"; the 2 Moonglade legs, now in the generator's words: "Go to Moonglade: cast Teleport: Moonglade if you have it (VERIFY(beta): where a druid learns it), else the way is not in the data" and
"Return from Moonglade to Thunder Bluff: use your hearthstone or a flight path if you have one (VERIFY(beta): the way back is not in the data)", with a note that the trip is a long walk. No `.path`, `.zeppelin` or `.boat`.

## The left-out list (31 `#skipquest ... not finished by this route` lines in the guide file)
23 "objectives are N s of walking away (the route walks up to 30 s)", 7 "handed in N s away and the route does not pass there", 1 "near but not worth the trip": 92462 Infestation Investigation (pays 2.07 XP/s against the route's 2.93, 71%;
"completeness 0.71 or less would finish it"). Every quest the route picks up and drops has a line; quests dropped before the search (other class, too high, dungeon quests in a HARDCORE route) have none.

## The user's rule: a quest offered where the player stands (completeness off)
Method: for each step, the planner's kept quests with a giver within 150 yards, offered by the planner's availability test at that point, with every objective within 250 yards of the next six steps, that the guide never accepts. Five:
92462 Infestation Investigation (step 1; the user's find; 92463 follows it), 92598 The Gift of Skysight (4), 92515 The Problem With Prideclaws and 92553 Restocking the Larders (15), 86784 Sticks and Bones (198; a level 7 quest at level 24).
Cause: the search's objective (minimum time), not the finalist choice; no manifest hint fixes it. With completeness off the guide at least names what it leaves out.

## Findings, ranked
1. UNVERIFIED: the exit itself (chain, dock, airship name, landing, level 15): fan guides and the quest data, nothing seen in the game ("Skyborne exit in the game"). The exit chain is intact after the dungeon-quest drop: 2 required, 31 quests they need, all routed.
2. DANGEROUS: the finale fight has no note of its own (item "The finale warning sits on the pick-up ..."); Ambermill and Hillsbrad (above); the event quest 1090 Gerenzo's Orders carries the planner's HARDCORE note (the simulator's risk score is 2).
   42 skip rules (instances, escorts, caves, named targets) and 20 notes apply; no skipped quest is accepted; elite sources among ordinary ones have notes (869, 865, 845, 855, 1104, 86576).
3. DANGEROUS (hardcore): Child of Nature is handed in at 15, but 94913 Moonglade and the whole Cat Form chain come in one trip at 25 to 26; docs/HARDCORE.md calls Bear Form "the early survival tool" ("HARDCORE druid routes finish the Bear Form chain late").
4. CONFUSING: 4h57 of grinding in the simulator (20.5% of the planned time, 14.6% of the experience) in 8 level gates: 29 in Ashenvale 2h43, 30 in Thousand Needles 1h08, the rest 16 minutes or less; each says how much to grind.
5. MISSING: the user's-rule quests; a Windshaper's Cure Poison (14) and Aquatic Form (16) ("A Windshaper's Cure Poison ..."); the Moonglade trips and relics ("Skyborne Druid guide: the Moonglade trips ...").
6. TESTS: `tests/placement_spec.lua` is red for this guide in 3 of 6 cases (the Tauren and Troll pass). `python tools/placement_report.py`, seed 1 (the spec uses another seed; bounds in brackets): followed the guide to the step: p90 8 quest steps [2],
   15 steps at most [6], 86% within five; skipped a fifth: p90 8 [8]; done early: p90 9 [10]; all the noise together: 1.5% three levels off [0].
7. PLANNER: `thorough` found a route of its own this time (24,962 complete routes; 24h14 against beam 25h59, lookahead 29h58, greedy 31h59 of play); earlier runs on slightly different rules returned the greedy route once: a regeneration is a lottery.

## Class quests (all ten routed, none skipped)
92485 at 2; The Great Ursera Spirit at 10 and Strength and Mercy at 11 (on the island, required through 94638); Child of Nature at 15; Moonglade 94913 and Cat Form 98340, 98341, 98404, 98738, 98362 at 25. One class quest comes more than 5 levels late. The weapon
quest 98823 Earthen Echo has the Windshaper bit in its race mask; the Tauren worker's entry in Classes/DRUID.lua may say Tauren only (unverified).

## Recipe: make this guide again, and check it
Inputs: tools/hardcore_rules.json (42 skips, 20 notes), tools/drafts.json (entry horde-windshaper-druid: `"require": [95349, 94638]`, E1's option: the quests they need are required too, about 30 island-story quests, and a zone lock keeps the route on the
island until the required work there is done; `--chain 94911,94913` and `--chain 98340,98341,98404,98738,98362`; the `--race-bit`s; "hardcore": true; the "planned" note the installer rewrites), Guides/HordeWindshaperDruid.lua (the installer replaces only its
`#skipquest` and `#include` lines and keeps `#guide` and the "Read this first" chapter and step), Classes/DRUID.lua (class quests, the Moonglade words), Guides/Travel/Borders.lua (the airship), the pack in ../Signpost_Data. Guides/, both TOCs and tools/drafts.json must be committed
(else `--force`). Completeness stays off (the planner's default) until the user chooses.
1. `python tools/route_planner.py windshaper --preset all --install --quiet` (about 13 minutes: run it in the background); read its report: `thorough`'s "finished" line, `required`, `class quests`, the grinding share, `unfinished`.
2. `python tools/guide_lint.py --strict` (0 errors, 0 warnings); `python tools/guide_sim.py --check`; `python -m unittest discover -s tools/tests -t tools` (test_shipped_guides: rules and chapters agree); `& .\tools\check.ps1` (busted: the placement spec).
3. Post-checks from the repository root, PowerShell, `$g = 'Guides\Chapters\windshaper-druid-*.lua'` (results for the final generation in brackets):
   `$ids = ((Get-Content tools\hardcore_rules.json -Raw | ConvertFrom-Json).rules | ? action -eq 'skip').id; Select-String $g -Pattern ('^\s*\.accept (' + ($ids -join '|') + ')\b')`: none [0];
   `Select-String $g -Pattern '^\s*\.accept (92462|92463)\b'`: 2 lines [0: the planner's fix is still to come];
   `... '^\s*\.accept (92485|94006|94638|94911|94913|98340|98341|98404|98738|98362)\b'`: 10 [10]; `... '^\s*\.accept 95349\b'`: 1 [1]; `... 'Take the airship from Valanaar'`: 1 [1];
   `... 'VERIFY\(beta\): (the finale of the island story|the last stop before the boss fight|a scripted boss fight)'`: 3 [3]; `Get-ChildItem Guides\Chapters\windshaper-druid-*-zephras-isle.lua`: ONE file [1]; `... 'Get from .* to Zephras Isle'`: none [0];
   `... 'Go to Moonglade: cast Teleport: Moonglade if you have it'`: 1 [1]; `\.todo`: 33; "Read this first" once in Guides\HordeWindshaperDruid.lua [1]; the guide file's `not finished by this route` lines: 31.
4. The user's rule: `python tools/route_planner.py windshaper --preset beam --no-write` and compare its accepted quests with the chapters' (method above).
5. A new hazard review is needed after every regeneration: skim the quests the new chapters accept that the previous ones did not (the accept lines of `git diff`) for escorts, instances and caves.
