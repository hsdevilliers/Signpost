# Skyborne Druid (HARDCORE): a player's walk through the planner's route

Reviewer: worker A1 of batch 1, 2026-10-21, updated after the island exit became real. Subjects: generation 1 (PR #42, cf765da: 23 chapters, 204 quests, 65 `.todo`, 17h36 simulated), generation 2 (an earlier
install of this branch, 2088fb6: 25 chapters, 195 quests, no island exit) and generation 3, the files now in this branch (thorough alt 2 with the island exit required: 14 chapters, 272 steps, 188 quests, 27 `.todo`,
25h43 planned, 25h24 simulated). One more regeneration is still to come (planner fixes from the independent review): its numbers will move, the method and the findings stay. Source: the private pack as rebuilt on
2026-10-21 (QuestieDB's Classic baseline plus its Forever layers), the planner's report, the simulator, git history. NOTHING was seen in the game; Classic facts quoted from memory say so. Backlog items are named in quotes.

## Verdict
The exit is real now: the whole island story, a finale with warnings, the airship step and the Mulgore hand-in are in the route, all VERIFY(beta) (fan guides and the quest data). Not yet right: (1) the route goes back to
Zephras Isle at level 30 for the two island-side Bear Form class quests (94006, 94638), with a "no dock" placeholder and no way back in the data: the manifest now requires 94638 too, the next regeneration applies it;
(2) 28% of the planned time (7h18) is level-gate grinding, because the quest pool under the HARDCORE rules runs dry at 27 to 30; (3) the Bear Form chain's Mulgore part is done at 24 and Cat Form at 24 to 25;
(4) quests offered where the player stands are left out (now all 22 named with a reason). Lint and `guide_sim --check` are clean and cannot see any of this; the busted placement spec is red for this guide (finding 8).

## The island and the exit, as a player reads them (generation 3, chapter 01: 86 steps, levels 1 to 15, 5h32)
- 1-18 as in generation 1 up to Shen'dar Village: Coming of Age, Harmony in Balance, a joined step in step 4 with the class quest A Student of Nature (92485), Foul Matriarch in 11 (level 5, a named ursera). 19-26 Among the
  Faithful, Havoc in the Highlands, The Western Watch: the island story proper. 26-45 To Valanaar, The Grand Skyseer, the Broken Construct chain, the Windfield line, Elegael Thornpaw's chain. 51 takes the class quest
  The Great Ursera Spirit at level 10. 52-76 A Firm Response, In Service of Zephras, Tower Defense, Return to Valanaar, The Turncoat, Desperate Times, Prepare for Battle.
- 77-80 the finale: Making Our Move (the Al'Aketh guardian, spiritcaller and blademaster near 61,51), The Inner Sanctum, Confront Lorthuna (the fight: explore at 74.9,53.0). Each of the three `.accept` lines is followed by a
  `.note VERIFY(beta): ...` (rules 92947, 93958, 92646); the last reads: "a scripted boss fight at the Shrine of Akir. Fan guides say Rohash is summoned and Kirin Tor and Earthen Ring reinforcements arrive. Go in fully
  healed and buffed with your escape ready, fight beside the reinforcements, and leave if it goes badly. It is part of the chain that takes you off the island, so there is no way round it that we know of."
- 81-83 hand-ins with Ayessa Dawnsinger (59.2,79.8) and Talaanis Shadowsong (66.2,76.5): The Fate of Zephras, What Comes Next, then The Earthen Ring is taken.
- 84 `.zone 1412 >> Take the airship from Valanaar's southwest dock (Zephras Isle) to Skywatcher Plateau, beside Thunder Bluff (Mulgore)`, the note "Expect to wait about 7 to 8 minutes for it." and a `.todo`: "Not verified
  in the game: the dock, the airship's name, the landing spot and whether you can board before the quest chain asks you to. This step is done when you arrive in Mulgore." The simulator prices it at nothing.
- 85 Mulgore (33.4,22.6): The Earthen Ring is handed in, Welcome to Azeroth and the class quest Child of Nature are taken. 86 `.todo "Walk from Mulgore to Orgrimmar: the guide has no waypoints for this yet ..."` + `.zone 1454`.

## A sample from the middle (generation 3, steps 150-172, levels 20 to 23)
Undercity's library quests (invented levels: 20, required 1), then "Walk from Undercity to Silverpine Forest" (a placeholder) and Silverpine's quests in one run: Arugal's Folly, Stop the Spread, Border Crossings, Watching the Roads
(Dalaran Watchers and Wizards near 64,58), Beren's Peril, The Dead Fields, the Tortured Soul pair, back to Undercity and again to Silverpine. Chapter 05 also holds Ambermill Keep's quests (479, 480 The Weaver with a note on
Archmage Ataeric): from memory of Classic that is where a careful player gets hurt at 21 to 23. Elsewhere in the guide the zone changes are flight paths (`.fp`/`.fly`) where the data has them; here they are walks.

## The last chapter (generation 3, 14 Zephras Isle, level 30): the defect
Steps 262-272: Ashenvale (Ashenvale Outrunners, Satyr Horns, The Lost Pages with three positionless objectives), two grinds ("Grind about 44,000 experience before you go on: about 240 kills", then about 41,000 and 210 kills),
then `.todo "Get from Ashenvale to Zephras Isle: they are on different continents ... the guide has no dock for it yet"` and the island again: The Great Ursera Spirit is handed in and Strength and Mercy done at level 30. The
airship is one-way in the data; nothing brings a player back. The beam test with `--require 94638` does both quests on the island at levels 10 and 11 and never returns (its route graph ends in Stonetalon).

## What is still a placeholder (generation 3: 27 `.todo`; 12 `.zone`, 9 `.fly`, 8 `.fp` are real steps)
8 "Walk from X to Y: the guide has no waypoints for this yet" (Mulgore-Orgrimmar, Orgrimmar-Barrens, Undercity-Silverpine, Silverpine-Hillsbrad, Barrens-Ashenvale, Barrens-Thousand Needles, Thunder Bluff-Moonglade, Moonglade-Stonetalon);
3 "different continents, no dock" (Ashenvale-Undercity, Hillsbrad-Thunder Bluff, Ashenvale-Zephras Isle); the airship's unverified words; 12 objectives with no position in the pack (Falling With Style, The Lost Pages x3,
The New Plague, Light's Justice, The Sacred Flame ...); 3 relics of The Great Windborne Cat Spirit "only in places this guide does not go". No `.path`, `.zeppelin` or `.boat` anywhere.

## The left-out list (22 `#skipquest ... not finished by this route` lines in the guide file)
14 "objectives are N s of walking away (the route walks up to 30 s)": 421, 447, 875, 78149, 79094, 92515, 92516, 92553, 92598, 93172, 93318, 93951, 96101, 97253; 6 "handed in N s away and the route does not pass there": 428, 440, 444,
894, 79007, 91921; 2 "near but not worth the trip": 92462 Infestation Investigation (pays 2.07 XP/s against the route's 2.93, 71%; "completeness 0.71 or less would finish it") and 93160 The Forest's Bounty (its line says it pays 265% of the
pace and is still left out with completeness off: the wording looks wrong). Every quest the route picks up and drops now has a line; quests dropped before the search (other class, too high) have none.

## The user's rule: a quest offered where the player stands (completeness off)
Method: for each step, the planner's kept quests with a giver within 150 yards, offered by the planner's own availability test at that point, with every objective within 250 yards of the next six steps, that the guide never accepts.
Six, and all six are in the left-out list: 92462 Infestation Investigation (step 1; the user's find; 92463 follows it), 92598 The Gift of Skysight (4), 92515 The Problem With Prideclaws and 92553 Restocking the Larders (15), 93160 and
93172 (71). Earlier generations left out four of the first island quests as well (92473, 92528 ...). Cause: the search's objective (minimum time), not the finalist choice; no manifest hint fixes it (a `--chain` hint to a
quest that is not mandatory is dropped with it; one to a class quest forces the pair but throws the rough beam by hours); E1's completeness option is the fix, and with it off the guide at least names what it leaves.

## Findings, ranked
1. DEFECT, fixed in the manifest, not yet regenerated: the return to Zephras Isle at level 30 (above). `"require": [95349, 94638]` in tools/drafts.json. Requiring the whole Bear Form chain (94911, 94913 too) keeps the beam on the
   island for 13h20 in a test run: not done; the user decides ("HARDCORE druid routes finish the Bear Form chain late").
2. UNVERIFIED: the exit itself (chain, dock, airship name, landing, the level it is done at: 15 in the planner, 5h32 in) is the lead's research from fan guides, nothing seen in the game; the "Skyborne exit in the game" verify item holds it.
3. DANGEROUS: the finale boss fight (notes); the instance, escort and cave quests are out by rule (all 42 skip rules apply to this guide, none touches the 31 quests of the exit chain); Ambermill Keep; the planner's own
   HARDCORE note on the event quest 1090 Gerenzo's Orders (the simulator's hardcore risk score is 2, that quest). Elite sources among ordinary ones have notes by rule (869, 865, 845, 855, 1104, 86576), shown where the route takes those quests.
4. DANGEROUS (hardcore): the Bear Form chain's Mulgore part (94911, 94913) is done at 24 and Cat Form (98340-98738) at 24 to 25; 4 class quests come more than 5 levels late. docs/HARDCORE.md calls Bear Form "the early survival tool".
5. CONFUSING: 7h18 of grinding (28.4% of the planned time, 21% of the experience), 5 level gates: 29 (2h59) and 30 (2h37) in Ashenvale, 19 (1h30) in the Barrens; each now says how much to grind ("about 44,000 experience, about 240 kills").
6. CONFUSING: 27 placeholders (above); 12 objectives without a position; the three "no dock" legs.
7. MISSING: the user's-rule quests; a Windshaper's Cure Poison (14) and Aquatic Form (16) ("A Windshaper's Cure Poison ..."); Moonglade trips and the relics ("Skyborne Druid guide: the Moonglade trips ...").
8. TESTS: `tests/placement_spec.lua` is red for this guide, 4 of 6 cases (bounds in brackets): followed the guide to the step: 90th percentile 10 quest steps [2], 15 steps at most [6], 78% within five, no run three levels off;
   skipped a fifth: median 1, p90 10 [8]; done early: p90 11 [10]; all the noise together: 2.2% three levels off [0], median 4, p90 14. The Tauren guide is at 0 / 1 and the Troll at 0 / 0 for the first case
   (`python tools/placement_report.py`). Likely cause, not checked: long stretches of the Skyborne guide where the character's quest history does not change (the 7h18 of grinding, the island's 86 steps).
9. PLANNER: the review's own rule changes made `thorough` return the greedy route once (item "The thorough preset returned the greedy route ..."); this time it found a route 25h43 long; a regeneration is still a lottery.

## Class quests (all ten routed, none skipped)
Generation 3: 92485 at 2; 94006 taken at 10 (step 51) and handed in at 30; 94638 at 30; 94911 and 94913 at 24; Cat Form 98340, 98341, 98404, 98738 at 24, 98362 at 25. Beam test with `--require 94638`: 94006 at 10, 94638 at 11, 94911
and 94913 at 21, Cat Form at 21 to 25. The weapon quest 98823 Earthen Echo (level 31 from 24) has the Windshaper bit in its race mask; the Tauren worker's entry in Classes/DRUID.lua may say Tauren only (unverified).

## Recipe: make this guide again, and check it
Inputs: tools/hardcore_rules.json (42 skips and 20 notes), tools/drafts.json (entry horde-windshaper-druid: `"require": [95349, 94638]` (E1's option: the quests they need are required too, ~30 island-story quests, a zone lock keeps the
route on the island until the required work there is done); `--chain 94911,94913` on skyborne-arrival-12 and `--chain 98340,98341,98404,98738,98362` on windshaper-cat-form-20; the `--race-bit`s; "hardcore": true; the "planned" note the
installer rewrites), Guides/HordeWindshaperDruid.lua (the installer replaces only its `#skipquest` and `#include` lines and keeps `#guide` and the "Read this first" chapter and step), Classes/DRUID.lua, Guides/Travel/Borders.lua (the
airship), the pack in ../Signpost_Data. Guides/, both TOCs and tools/drafts.json must be committed (else `--force`). Completeness stays off (the planner's default) until the user chooses.
1. `python tools/route_planner.py windshaper --preset all --install --quiet` (12-30 minutes: run it in the background); read its report: `thorough`'s "finished" line, `required`, `class quests`, the grinding share, `unfinished`.
2. `python tools/guide_lint.py --strict` (0 errors, 0 warnings); `python tools/guide_sim.py --check`; `python -m unittest discover -s tools/tests -t tools` (test_shipped_guides: rules and chapters agree); `& .\tools\check.ps1`
   (the placement spec may stay red: finding 8).
3. Post-checks from the repository root, PowerShell, `$g = 'Guides\Chapters\windshaper-druid-*.lua'`:
   `$ids = ((Get-Content tools\hardcore_rules.json -Raw | ConvertFrom-Json).rules | ? action -eq 'skip').id; Select-String $g -Pattern ('^\s*\.accept (' + ($ids -join '|') + ')\b')`: none;
   `Select-String $g -Pattern '^\s*\.accept (92462|92463)\b'`: 2 lines (the user's early test; generations 1 to 3 had none);
   `Select-String $g -Pattern '^\s*\.accept (92485|94006|94638|94911|94913|98340|98341|98404|98738|98362)\b'`: 10; `... '^\s*\.accept 95349\b'`: 1; `... 'Take the airship from Valanaar'`: 1; the three finale notes
   `... 'VERIFY\(beta\): (the finale of the island story|the last stop before the boss fight|a scripted boss fight)'`: 3;
   `Get-ChildItem Guides\Chapters\windshaper-druid-*-zephras-isle.lua`: ONE file (chapter 01; generation 3 has a second one: the defect);
   `Select-String $g -Pattern 'Get from .* to Zephras Isle'`: none; `\.todo` about 27; "Read this first" once in Guides\HordeWindshaperDruid.lua.
4. The user's rule: `python tools/route_planner.py windshaper --preset beam --no-write` and compare its accepted quests with the chapters' (method above).
5. A new hazard review is needed after every regeneration: skim the quests the new chapters accept that the previous ones did not (the accept lines of `git diff`) for escorts, instances and caves.
