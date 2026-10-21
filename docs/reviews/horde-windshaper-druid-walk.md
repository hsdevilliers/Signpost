# Skyborne Druid (HARDCORE): a player's walk through the planner's route

Reviewer: worker A1 of batch 1, 2026-10-21. Subject: the guide the Route Planner installed in PR #42 (generation 1, cf765da: 23 chapters, 326 steps, 204 quests,
65 `.todo`, 21h28 planned, 17h36 simulated) and this branch's guide (generation 2: 25 chapters, 333 steps, 195 quests, 54 `.todo`, 24h41 planned, 20h33 simulated),
made under the 22 rules of this review. Source: the private pack of 2026-10-20 (QuestieDB's Classic baseline plus its Forever layers), the planner's report, the
simulator and git history. NOTHING was seen in the game; Classic facts quoted from memory say so. Backlog items written for this review are named in quotes.

## Verdict
Playable on paper, not yet safe to hand to a hardcore player. Five things decide it: (1) the route never says how to leave Zephras Isle and leaves out the island
story, the only link the data has; (2) it skips quests offered where the player stands (the user's rule); (3) escorts, instance quests and a cave quest are in it until one
regeneration applies the rules of both druid branches (21 quests of generation 2); (4) the Bear Form chain is finished at level 20 to 24; (5) all zone changes are
placeholders. All ten class quests are routed. Lint and `guide_sim --check` are clean on both generations: they cannot see any of this.

## The first 60 steps (generation 1; generation 2 is the same stretch with small differences)
- 1-46 Zephras Isle, 3h00, level 1 to 12. Step 1: Coming of Age (Ailee Farheart), handed in at Rorian the Dayseeker, who gives Harmony in Balance; 3 waits for level 2
  (Falling With Style: a spell objective with no position, `.todo`); 4 is one joined step over four places in the village: five hand-ins and four pick-ups, among them the
  class quest A Student of Nature (92485); 8-10 Aetheen of the Gales and Foul Matriarch (level 5, a named ursera); 11-18 Shen'dar Village; 19-29 the Windfield quest line
  (46.7,82); 30-36 the Bear Form class quests The Great Ursera Spirit and Strength and Mercy (level 10; the trial is killing Ur'endra near 53.7,65); 37-45 Elegael Thornpaw's
  chain (61.7,39.2). The island's main story (To Valanaar ... The Earthen Ring) is absent. Generation 2 also takes Meddlesome Mages, Crab Season and Vulgara and stops
  the Windfield line before The Hills Have Eyes.
- 46 `.todo "travel from Zephras Isle to Mulgore: the travel graph has no route yet"` + `.zone 1412`. The pack has no boat, flight or portal for the island.
- 47-73 Mulgore (33.4,22.6): Welcome to Azeroth (for Thrall) and the class quest Child of Nature (94911), the Venture Co. quests, then Thunder Bluff and back to Mulgore twice
  more for single hand-ins (zone changes at 57, 62, 69, 73); step 61 takes Moonglade (94913), which is held for 104 steps. 74: the Crossroads.

## A sample from the middle (generation 1, steps 97-135, levels 12 to 17)
The Crossroads loop is the best stretch: pick-ups at 51.5,30.9, kills close by, hand-ins, 40 steps with no zone change. What a hardcore player should know and generation 1
does not say (generation 2 has notes): 855 Centaur Bracers (steps 100-102) also drops from Rocklance (rare elite) and Warlord Krom'zar (elite); 845 The Zhevra (98) from Swiftmane
(rare elite); 850 Kolkar Leaders (115) kills the named Barak Kodobane (now skipped); 881 Echeyakee and 882 Ishamuhale (105, 128) are named rares with a `.todo` and no position;
6543 The Warsong Reports (132) has three item objectives with no source in the data.

## The last chapter
Generation 1 (23 Ashenvale, 29 to 30): The Lost Pages (three item objectives, no position), Satyr Horns (the camps near 67-81,41-56; named satyrs among the sources) and a last step
`.level 30 -- reach it first`, no amount. Generation 2 (25 Thousand Needles, steps 320-333): back from Stonetalon to Mulgore for the Gloomrise lair quests (96259, 96260, 96241) and to the
Barrens for The Tear of the Moons (857), both in the Tauren worker's rules; the Salt Flats quests (a note warns of Vile Sting); then `.level 30`. Both end at 30 with nothing left in the log
(by the guide's own accepts and hand-ins at most 9 quests are held in generation 1, 11 in generation 2).

## Generation 2 (this branch), and how it came about
Made by the recipe below. `thorough` returned the greedy route (46h55 in the planner's accounting: "none faster than the greedy one once tidied", item "The thorough preset returned the
greedy route ..."), so the install took the beam route: 24h41 of play, 1h42 of zone friction, 11h00 charged for class quests done late; 36 of generation 1's quests gone, 27 new. Worse than
generation 1 in three ways: 3h50 of level-gate grinding in 5 gates (level 28 in Thousand Needles 2h01, 24 in Undercity 1h03, 29 in Stonetalon 0h33), against 0h37 in 3; the Moonglade trip
at 24 to 25 (item "HARDCORE druid routes finish the Bear Form chain late"); and the same four island quests left out. An earlier install on the first 18 rules (commit 0e8ca3a) differed from
generation 1 by 30 quests each way and newly accepted 435 Escorting Erland and 5726 Hidden Enemies (Skull Rock): a review of one generation does not survive the next regeneration. So the
hazards were looked for in the planner's whole pool (486 kept quests of 542 routable: 5 with an instance zone, 8 with an elite source among ordinary ones, 14 with an escort-like name, 19 with a
class-trainer giver) and triaged by hand: skips 435, 5726, 1486, a note on 480. The scan is a scratch script, not in the repository.

## Findings, ranked (impossible, dangerous, confusing, missing)
1. IMPOSSIBLE as written: no way off Zephras Isle. The pack has no transport, crossing or flight master for map 2521. The only link in the data is the island story 93836 -> 93090 ->
   95349 The Earthen Ring (starts with Ayessa Dawnsinger on the island, ends with Alaana Stormwalker in Mulgore, who gives 95350). The planner prices any trip off the island at a flat
   15 minutes, so every technique but greedy left the story out (about 30 quests). Experiment: 95349 as a mandatory quest keeps the character on the island to level 15 (beam total 28h52 ->
   41h13). The question item "How does a Skyborne character leave Zephras Isle" holds it; the guide's first step ("Read this first") says so. Not applied, for the user: `--chain 95349,94911`
   in the manifest would force the story (94911 Child of Nature starts at Alaana's side).
2. DANGEROUS: 21 quests of generation 2 are in the Tauren worker's rules, not yet merged: escorts 6523, 6544, 6641, 6482, 4770, 4904 (from memory of Classic), 6562 and 6563 (Blackfathom Deeps),
   the Gloomrise lair 96259, 96260, 96241, 857, probable class quests 98251, 98252, 65601, 76156, 76160, 76240, named Forever targets 92422, 92706, 97003. 435 Escorting Erland (an escort, not in
   their list) is skipped by this review. "Regenerate the Skyborne guide after both druid guides' HARDCORE rules are merged"; `tools/tests/test_shipped_guides.py` names what is left.
3. DANGEROUS: instance quests and a cave. 1491 Smart Drinks, 1013 The Book of Ur, 6921 Amongst the Ruins (zones 279, 310, 221 are instance map ids, not maps of the pack), 1486 Deviate Hides and
   5726 Hidden Enemies (its item drops at Skull Rock, 53,9; the chain ends in Ragefire Chasm): skipped by rule. "Dungeon and raid quests are not recognized".
4. DANGEROUS (hardcore): the Bear Form chain is finished late: 94913 Moonglade at 20 (generation 1) and 24 (generation 2), the Cat Form chain with it; the push stops growing after six levels.
   docs/HARDCORE.md calls Bear Form "the early survival tool". Where the Windshaper gets it is not in the data. A question for the user: "HARDCORE druid routes finish the Bear Form chain late".
5. DANGEROUS: elite sources among ordinary ones: 869 and 865 (Takk the Leaper), 845 (Swiftmane), 855 (Rocklance, Krom'zar), 1104 (Vile Sting), 86576 (Sister Riven, Bloodfury Ripper): notes added by
   rule. "HARDCORE guides route item quests with an elite source among ordinary ones".
6. DANGEROUS: named targets with no rank (none of the 419 Forever creatures has one): skipped 879, 850, 6621, 5147, 1150 (low confidence, by name); noted 94638 (Ur'endra), 6441 (satyrs), 480 (Archmage
   Ataeric); unflagged 92470 Urs'anah (level 5), 94488 Haalien, 92693 Ferauu, 876, 872, 896, 843, 846, 1096. "The pack has no rank for any Forever creature".
7. DANGEROUS (Classic, from memory, not proof): Hillsbrad at 24-26 (generation 1 only), the Kolkar camps and Bael'dun in the Barrens, Thousand Needles at 28-30, the Ashenvale satyrs at 29-30; Ambermill
   Keep in Silverpine (the Dalaran wizards: 479, 480, 95981) came with the earlier install and is in neither generation, but the pool offers it.
8. CONFUSING: 38 (generation 1) and 36 (generation 2) zone changes are `.todo` + `.zone` (26 "no route yet", 12 "no crossing coordinates yet" in generation 1). In generation 1, 12 of 35 stops last five
   minutes or less (Mulgore and Thunder Bluff three times in steps 57-73); in generation 2 Stonetalon is entered four times. "Skyborne Druid guide: 38 zone changes are placeholders".
9. CONFUSING: bare `.level` gates name no amount (generation 1: 3 gates, 0h37; generation 2: 5 gates, 3h50, 15.6% of the planned time and 11% of the experience): "A grind step says how much experience to
   grind". 76 of 195 accepts (generation 2) are above the simulated level before their step, inside steps that level the character; the Undercity library quests (78127 ...) carry invented levels (20, required 1).
10. CONFUSING: 24 objectives with no position and 3 only where the route does not go (the relics): `.todo`; quests started by objects (79192, 79980, 900-902, 549, 95883, 95885), items with no source.
    Existing item "Thin Forever quest records and chains the pack cannot order".
11. MISSING: quests offered where the player stands (next section).
12. MISSING: nothing says where a Windshaper learns Cure Poison (14) and Aquatic Form (16); the Tauren chains are Tauren-only (race mask 32). "A Windshaper's Cure Poison ...".
13. MISSING: Moonglade: both legs are placeholders, the relics have no pins, the drafted Teleport: Moonglade text survives only as the note on 94913. "Skyborne Druid guide: the Moonglade trips and the Cat Form
    relics are placeholders".
14. PLANNER: after the review's rules `thorough` returned the greedy route, and a beam run on 18 of the 22 rules came out at 47h45 against 28h52: a regeneration is a lottery ("The thorough preset returned ...").

## The user's rule: a quest offered where the player stands
Method: for each step, the planner's kept quests with a giver within 150 yards, offered by the planner's own availability test at that point (level and quests done), with every objective within 250 yards of
the next six steps (a delivery: its hand-in too), that the guide never accepts. Seven in each generation, six real. Generation 1: 92462 Infestation Investigation (step 1; the user's find; 92463 follows it),
92598 The Gift of Skysight (4; the Windshaper's own fork quest), 92473 Aggressive Encroachment (8), 94411 Meddlesome Mages (11), 92528 Among the Faithful (18; the first link of the island story), 93317 Crab Season
(19). Generation 2: the first, second, third and fifth of those, 92683 Flutterfly Dust (23) and 96825 This Fruit Could Bite Back (107). Not to take: 99108 (probably a Warrior class quest). Cause: the objective, not the
finalist choice. In the saved generation 1 plans only greedy (340 quests) and lookahead (237) take 92462 and 92463; beam (218) and thorough (202) do not: a few minutes of kills for an unknown-XP quest make a
route slower. The beam route installed now omits them too, a beam run on an earlier state of the rules took them: chance. No manifest hint fixes it: a `--chain` hint to a quest that is not mandatory is dropped
with it (the beam then skipped Foul Matriarch); one to the class quest 92485 forces them, but the rough beam's total jumped (28h52 -> 39h07) and so it did without the hint (47h45).

## Class quests (all ten routed, none skipped)
Generation 1: 92485 at 2; 94006 and 94638 on the island at 10; 94911 at 12 (opens at 10), 94913 held to 20; Cat Form 98340 taken in Thunder Bluff at 20, 98341, 98404, 98738 in Moonglade at 21, 98362 at 21.
Generation 2: 94911 at 13, 94913 at 24, Cat Form at 24-25. One Moonglade trip, placeholders both ways, the three relics `.todo`. The weapon quest: 98823 Earthen Echo (level 31 from 24; Bashana Runetotem in
Thunder Bluff to Muln Earthfury) has the Windshaper bit in its race mask; the Tauren worker's `earthen-echo` entry in Classes/DRUID.lua says Tauren only: add "Skyborne" if it is the druid weapon quest
(unverified; their rule skips it for HARDCORE).

## Recipe: make this guide again, and check it
Inputs: tools/hardcore_rules.json (rules by quest id: 22 from this review, 36 in the file; the Tauren worker's apply to this guide once merged), tools/drafts.json (entry horde-windshaper-druid:
`--chain 94911,94913` on skyborne-arrival-12, `--chain 98340,98341,98404,98738,98362` on windshaper-cat-form-20, the `--race-bit`s, "hardcore": true, the "planned" note the installer rewrites),
Guides/HordeWindshaperDruid.lua (the installer replaces only its `#skipquest` and `#include` lines and keeps the rest: `#guide`, the "Read this first" chapter and step), Classes/DRUID.lua, the pack in
../Signpost_Data. Guides/, both TOCs and tools/drafts.json must be committed (else `--force`).
1. `python tools/route_planner.py windshaper --preset all --install --quiet` (13-30 minutes on a busy machine: run it in the background) writes plans/horde-windshaper-druid/ (gitignored), the chapters
   windshaper-druid-NN-<zone>, the guide's `#skipquest`/`#include` lines, both TOCs and the "planned" note, and runs StyLua. Read its report: the "finished" line of `thorough`, the grinding share.
2. `python tools/guide_lint.py --strict` (0 errors, 0 warnings); `python tools/guide_sim.py --check` (no findings); `python -m unittest discover -s tools/tests -t tools` (test_shipped_guides: rules and
   chapters agree); `& .\tools\check.ps1`.
3. Post-checks from the repository root, PowerShell: `Select-String -Path Guides\Chapters\windshaper-druid-*.lua -Pattern '<p>'` with <p> =
   `^\s*\.accept (92462|92463)\b`: 2 lines (the user's early test; generations 1 and 2 had none);
   `^\s*\.accept (1491|1013|6921|879|850|6621|5147|1150|435|5726|1486)\b`: none (this review's skips; generation 2 has none);
   `^\s*\.accept (98251|98252|65601|76156|76160|76240|6523|6544|6641|6482|4770|4904|527|857|92422|92706|97003|6562|6563|96259|96260|96241)\b`: none (the Tauren worker's rules; generation 2 has 21);
   `^\s*\.accept (92485|94006|94638|94911|94913|98340|98341|98404|98738|98362)\b`: 10 lines (the class quests; the level of 94913 is in the planner's report, "class quests");
   `\.todo`: 54 in generation 2 and "Read this first" once in Guides\HordeWindshaperDruid.lua.
4. The user's rule: `python tools/route_planner.py windshaper --preset beam --no-write`, then compare its accepted quests with the chapters': a quest the beam takes at a place the route stands and
   the chapters lack is a candidate (method above).
5. A new hazard review is needed after every regeneration: skim the quests the new chapters accept that the previous ones did not (`git diff --stat`, then the accept lines) for escorts, instances and caves.
