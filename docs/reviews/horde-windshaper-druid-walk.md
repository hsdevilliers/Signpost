# Skyborne Druid (HARDCORE): a player's walk through the planner's route

Reviewer: worker A1 of batch 1, 2026-10-21, refreshed for the completeness-on generation (branch feat/skyborne-completeness). Subject: the Route Planner's `thorough` route with completeness on (F 0.6, T 45 s) and the island exit
required: 19 chapters, 312 steps, 207 quests, 36 `.todo`, 24h17 planned, 24h05 simulated. Earlier generations: 1 (PR #42: 23 chapters, 204 quests, 65 `.todo`, 17h36 simulated, no island exit), then the same route with completeness off
(commit 9ca64ab: 19 chapters, 304 steps, 201 quests, 33 `.todo`, 24h14 planned, 24h03 simulated).
Source: the private pack as rebuilt on 2026-10-21 (QuestieDB's Classic baseline plus its Forever layers), the planner's report, the simulator, git history. NOTHING was seen in the game; Classic facts from memory say so.

## Verdict
Playable on paper. The exit is real and the shape is the same as with completeness off: the same 19 chapters in the same order of zones, the whole island story, the finale with warnings, the airship step and the Mulgore hand-in,
all VERIFY(beta). The six quests more are small and local. Infestation Investigation (92462) and The Cirrusfly Queen (92463), the user's find, are now the first things the island asks. Open: the Moonglade part of the Bear Form
chain comes at level 25; 19% of the planned time is level-gate grinding; two quests offered where the player stands are still left out; 36 placeholders. Lint, `guide_sim --check` and the tool tests are clean and cannot see any of this.

## What changed against the completeness-off generation
- Six quests more, none fewer: 92462 Infestation Investigation (island step 1, done in 5, handed in in 9), 92463 The Cirrusfly Queen (accepted in 9, handed in in 13), 92515 The Problem With Prideclaws and 92553 Restocking the
  Larders (island 20-25), 93318 WANTED: Vulgara the Insatiable (island 28-32), 6543 The Warsong Reports (Barrens, chapter 04). Island chapter: 85 to 93 steps; planned time +3 minutes overall (24h14 to 24h17).
- The left-out list is recounted: 31 to 27 `#skipquest ... not finished by this route` lines: 18 "objectives are N s of walking away (the route walks up to 45 s for one)", 7 "handed in N s of walking away and the route does not
  pass there", and 2 "near but not worth the trip" (747, 0.03 XP/s against the route's 6.63; 96895, handed in 44 s away, 1.69 against 6.03). The nearby ones the route can now reach are taken.
- Grinding: 7 level gates, 4h29 in the simulator (4h57 and 8 gates before, 19% of the planned time). The Ashenvale and Thousand Needles gates are as large as before (41,000 and 18,000 experience); the five others are short
  (99 to 3,400 experience).
- Class quest levels moved a little: A Student of Nature 3, The Great Ursera Spirit and Strength and Mercy 11-12 (island), Child of Nature 16, Moonglade 94913 and the Cat Form chain 25. Nothing skipped.
- The busted placement spec (`tests/placement_spec.lua`) is green for this guide now (check.ps1: 1288 successes, 0 failures); it was red in 3 of 6 cases.

## The island and the exit, as a player reads them (chapter 01: 93 steps, levels 1 to 15, left after 5h55)
- 1-18 Coming of Age, Harmony in Balance, Infestation Investigation (1-9), Falling With Style, Elemental Unrest, Agitators, Return to Rorian, the Cirrusfly Queen (9-13), Foul Matriarch (a named ursera), A Student of Nature (92485,
  joined to 6), Shen'dar Village. 19-48 the island story proper: Among the Faithful, Havoc in the Highlands, The Western Watch, WANTED: Vulgara, To Valanaar, The Grand Skyseer, the Broken Construct chain, A Firm Response,
  In Service of Zephras. 49-55 the island-side class quests: The Great Ursera Spirit, then Strength and Mercy (kill Ur'endra near 53.7,65), handed in in 55. 56-85 Tower Defense, Return to Valanaar, The Turncoat,
  Desperate Times, the Strange Hermit, Mercy Falls on Deaf Ears.
- The finale: 69-72 Prepare for Battle, Making Our Move (the Al'Aketh guardian, spiritcaller and blademaster near 61,51), The Inner Sanctum, and Confront Lorthuna is taken; 86 is the fight. Each of the three `.accept` lines
  is followed by a `.note VERIFY(beta): ...` (rules 92947, 93958, 92646); the last: "a scripted boss fight at the Shrine of Akir. Fan guides say Rohash is summoned and Kirin Tor and Earthen Ring reinforcements
  arrive. Go in fully healed and buffed with your escape ready, fight beside the reinforcements, and leave if it goes badly. It is part of the chain that takes you off the island, so there is no way round it that we know of."
  The note sits at step 72, fourteen steps before the fight in 86, which has no note of its own.
- 88-90 hand-ins with Ayessa Dawnsinger and Talaanis Shadowsong: Confront Lorthuna, The Fate of Zephras, What Comes Next, then The Earthen Ring is taken (95349 is done at level 15, opens at 7).
- 91 `.zone 1412 >> Take the airship from Valanaar's southwest dock (Zephras Isle) to Skywatcher Plateau, beside Thunder Bluff (Mulgore)`, the note "Expect to wait about 7 to 8 minutes for it." and a `.todo`: "Not verified in the game: the
  dock, the airship's name, the landing spot and whether you can board before the quest chain asks you to. This step is done when you arrive in Mulgore." The simulator prices the ride at nothing.
- 92 Mulgore (33.4,22.6): The Earthen Ring is handed in, Welcome to Azeroth and Child of Nature (94911) are taken. 93 `.todo "Walk from Mulgore to Thunder Bluff ..."` + `.zone 1456`. Chapter 02 (Thunder Bluff, level 15): Traditions of the
  Bluff, the flight master (`.fp`), Child of Nature handed in and Moonglade (94913) taken, then a walk to Orgrimmar.

## A sample from the middle and the end (unchanged in kind)
Chapter 06 (Silverpine, 28 steps) still has Ambermill Keep's Dalaran wizards (479, 480 The Weaver with a note on Archmage Ataeric, 95981 Watching the Roads); chapter 07 Hillsbrad Foothills (22 steps). From memory of Classic these
are the places where a careful player gets hurt at this level. Ashenvale (chapter 16, 10 steps): Satyr Horns, The Lost Pages (three objectives with no position), then "Grind about 41,000 experience before you go on: about 220 kills" for
level 29. Chapter 17 is Mulgore again (12 steps): the level 4 to 9 quests Longwalker Malah, Kyle's Gone Missing!, The Ravaged Caravan, grey at level 29 (quests with unknown XP are never filtered out). Chapter 19, Thousand Needles
(3 steps): a note warns of Vile Sting, then "about 18,000 experience, about 93 kills" to level 30.

## What is still a placeholder (36 `.todo`; the `.zone`, `.fly` and `.fp` steps are real)
12 "Walk from X to Y: the guide has no waypoints for this yet"; 2 "different continents ... no dock" (Barrens-Undercity, Undercity-Ashenvale); the airship's unverified words (1); 16 objectives with no position in the pack; 3 relics of
The Great Windborne Cat Spirit "only in places this guide does not go"; the 2 Moonglade legs, in the generator's words: "Go to Moonglade: cast Teleport: Moonglade if you have it (VERIFY(beta): where a druid learns it), else the way
is not in the data" and "Return from Moonglade to Thunder Bluff: use your hearthstone or a flight path if you have one (VERIFY(beta): the way back is not in the data)", with a note that the trip is a long walk. No `.path`, `.zeppelin`
or `.boat`. Three more than before (33): objectives of the quests the route now adds.

## The left-out list (27 lines in the guide file)
Counts above (18 objectives too far, 7 hand-ins too far, 2 near but not worth it). Every quest the route picks up and drops has a line; quests dropped before the search (other class, too high, dungeon quests in a HARDCORE route) have none.

## The user's rule: a quest offered where the player stands (completeness on)
Method: for each step, the planner's kept quests with a giver within 150 yards, offered by the planner's availability test at that point, with every objective within 250 yards of the next six steps, that the guide never accepts.
Two are left (five with completeness off): 92598 The Gift of Skysight (island step 4; its objectives are 49 s of walking, the route walks up to 45 s: a line in the guide file says so), and 86784 Sticks and Bones (a level 7 quest
met at level 24; no line in the guide file, so it is dropped before the search or never in it: not investigated). The other three (92462, 92515, 92553) are in the guide now.

## Findings, ranked
1. UNVERIFIED: the exit itself (chain, dock, airship name, landing, level 15): fan guides and the quest data, nothing seen in the game ("Skyborne exit in the game"). The exit chain is intact after the dungeon-quest drop: 2 required, 31 quests they need, all routed.
2. DANGEROUS: the finale fight has no note of its own (item "The finale warning sits on the pick-up ..."); Ambermill and Hillsbrad (above); the event quest 1090 Gerenzo's Orders carries the planner's HARDCORE note (the simulator's risk score is 2).
   42 skip rules (instances, escorts, caves, named targets) and 20 notes apply; no skipped quest is accepted; elite sources among ordinary ones have notes (869, 865, 845, 855, 1104, 86576).
3. DANGEROUS (hardcore): Child of Nature is handed in at 16, but 94913 Moonglade and the whole Cat Form chain come in one trip at 25; docs/HARDCORE.md calls Bear Form "the early survival tool" ("HARDCORE druid routes finish the Bear Form chain late").
4. CONFUSING: 4h29 of grinding in the simulator in 7 level gates; each says how much to grind. The two big ones are at levels 29 and 30.
5. MISSING: the quests above; a Windshaper's Cure Poison (14) and Aquatic Form (16) ("A Windshaper's Cure Poison ..."); the Moonglade trips and relics ("Skyborne Druid guide: the Moonglade trips ...").
6. PLACEMENT: `python tools/placement_report.py`, seed 1, quest steps from the true place, median / 90th percentile (truth: the simulator's levels; the first row against the warp truth is the same, 0 / 0): followed the guide to the step 0 / 0;
   skipped a fifth 0 / 4; skipped 30 percent in runs 0 / 8; did four quests that come later 0 / 2; level off by two 0 / 6; all the noise together 2 / 8; no quest history at all 10 / 23; stopped following at 40 percent 10 / 25.
   Three or more levels off: 0.8% (all the noise together), 3.2% (no history), 2.5% (stopped following), 2.3% (half the quests, no order). The Tauren and Troll guides are at 0.0 to 0.2% in all four rows: the Skyborne guide is the one where a character with no history can land three levels off (the sim's levels, not the pure warp truth, where it is 0.0 to 0.2% too).
7. PLANNER: `thorough` is a search with luck in it: it returned the greedy route once on slightly different rules (item "thorough returned greedy"), so a regeneration is a lottery; this one is the thorough route (24h17 planned).
8. OPEN: the Tauren camp's 96605 and 96661 taken by the Skyborne route (backlog item; regeneration pass).

## Class quests (all ten routed, none skipped)
92485 at 3; The Great Ursera Spirit at 11 and Strength and Mercy at 12 (on the island, required through 94638); Child of Nature at 16; Moonglade 94913 and Cat Form 98340, 98341, 98404, 98738, 98362 at 25. One class quest comes more than 5 levels late.
The weapon quest 98823 Earthen Echo has the Windshaper bit in its race mask; the Tauren worker's entry in Classes/DRUID.lua may say Tauren only (unverified).

## Recipe: make this guide again, and check it
Inputs: tools/hardcore_rules.json (42 skips, 20 notes), tools/drafts.json (entry horde-windshaper-druid: `"require": [95349, 94638]`, E1's option: the quests they need are required too, about 30 island-story quests, and a zone lock keeps the route on the
island until the required work there is done; `--chain 94911,94913` and `--chain 98340,98341,98404,98738,98362`; the `--race-bit`s; "hardcore": true; the "planned" note the installer rewrites), Guides/HordeWindshaperDruid.lua (the installer replaces only its
`#skipquest` and `#include` lines and keeps `#guide` and the "Read this first" chapter and step), Classes/DRUID.lua (class quests, the Moonglade words), Guides/Travel/Borders.lua (the airship), the pack in ../Signpost_Data. Guides/, both TOCs and tools/drafts.json must be committed
(else `--force`). Completeness is the planner's default now (F 0.6, T 45 s, the user's choice); this generation passed both flags anyway.
1. `python tools/route_planner.py windshaper --preset all --install --force --quiet --completeness 0.6 --completeness-trip 45` (about 13 minutes: run it in the background); read its report: `thorough`'s "finished" line, `required`, `class quests`, the grinding share, `unfinished`.
2. `python tools/guide_lint.py --strict` (0 errors, 0 warnings); `python tools/guide_sim.py --check`; `python -m unittest discover -s tools/tests -t tools` (test_shipped_guides: rules and chapters agree); `& .\tools\check.ps1` (busted: the placement spec).
3. Post-checks from the repository root, PowerShell, `$g = 'Guides\Chapters\windshaper-druid-*.lua'` (results for this generation in brackets):
   `$ids = ((Get-Content tools\hardcore_rules.json -Raw | ConvertFrom-Json).rules | ? action -eq 'skip').id; Select-String $g -Pattern ('^\s*\.accept (' + ($ids -join '|') + ')\b')`: none [0];
   `Select-String $g -Pattern '^\s*\.accept (92462|92463)\b'`: 2 lines [2];
   `... '^\s*\.accept (92485|94006|94638|94911|94913|98340|98341|98404|98738|98362)\b'`: 10 [10]; `... '^\s*\.accept 95349\b'`: 1 [1]; `... 'Take the airship from Valanaar'`: 1 [1];
   `... 'VERIFY\(beta\): (the finale of the island story|the last stop before the boss fight|a scripted boss fight)'`: 3 [3]; `Get-ChildItem Guides\Chapters\windshaper-druid-*-zephras-isle.lua`: ONE file [1]; `... 'Get from .* to Zephras Isle'`: none [0];
   `... 'Go to Moonglade: cast Teleport: Moonglade if you have it'`: 1 [1]; `\.todo`: 36; "Read this first" once in Guides\HordeWindshaperDruid.lua [1]; the guide file's `not finished by this route` lines: 27; both TOCs list exactly the 19 chapter files [19 and 19].
4. The user's rule: `python tools/route_planner.py windshaper --preset beam --no-write` and compare its accepted quests with the chapters' (method above).
5. A new hazard review is needed after every regeneration: skim the quests the new chapters accept that the previous ones did not (the accept lines of `git diff`) for escorts, instances and caves.
