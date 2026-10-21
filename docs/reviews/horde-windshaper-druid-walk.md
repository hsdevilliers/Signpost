# Skyborne Druid (HARDCORE): a player's walk through the planner's route

Reviewer: worker A1 of batch 1, 2026-10-21. Subject: the guide the Route Planner installed in PR #42 (generation 1, cf765da: 23 chapters, 326 steps,
204 quests, 65 `.todo`, 21h28 planned, 17h36 simulated) and, on this branch, generation 2 made under this review's rules. Source: the private pack of
2026-10-20 (QuestieDB's Classic baseline plus its Forever layers), the planner's report, the simulator and git history. NOTHING was seen in the game;
Classic facts quoted from memory say so. Backlog items written for this review are named in quotes.

## Verdict
Playable on paper, not yet safe to hand to a hardcore player. Four things decide it: (1) the route never says how to leave Zephras Isle and leaves out
the island story, the only link the data has; (2) it skips quests offered where the player stands (the user's rule); (3) escorts, instance lead-ins and
named bosses the data cannot rank stay in it until one regeneration applies the rules of both druid branches; (4) all 38 zone changes are placeholders.
All ten class quests are routed. Lint and `guide_sim --check` were clean on generation 1: they cannot see any of this.

## The first 60 steps (generation 1)
- 1-46 Zephras Isle, 3h00, level 1 to 12. Step 1: Coming of Age (Ailee Farheart), handed in at Rorian the Dayseeker, who gives Harmony in Balance; 3 waits for
  level 2 (Falling With Style: a spell objective with no position, `.todo`); 4 is one joined step over four places in the village: five hand-ins and four
  pick-ups, among them the class quest A Student of Nature (92485); 8-10 Aetheen of the Gales and Foul Matriarch (level 5, a named ursera); 11-18 Shen'dar Village; 19-29 the Windfield quest line
  (46.7,82); 30-36 the Bear Form class quests The Great Ursera Spirit and Strength and Mercy (level 10; the trial is killing Ur'endra near 53.7,65);
  37-45 Elegael Thornpaw's chain (61.7,39.2). The island's main story (To Valanaar ... The Earthen Ring) is absent.
- 46 `.todo "travel from Zephras Isle to Mulgore: the travel graph has no route yet"` + `.zone 1412`. The pack has no boat, flight or portal for the island.
- 47-73 Mulgore (33.4,22.6): Welcome to Azeroth (for Thrall) and the class quest Child of Nature (94911), the Venture Co. quests, then Thunder Bluff and back
  to Mulgore twice more for single hand-ins (zone changes at 57, 62, 69, 73); step 61 takes Moonglade (94913), which is held for 104 steps. 74: the Crossroads.

## A sample from the middle (generation 1, steps 97-135, levels 12 to 17)
The Crossroads loop is the best stretch: pick-ups at 51.5,30.9, kills close by, hand-ins, 40 steps with no zone change. What a hardcore player should know
and generation 1 does not say (generation 2 has notes): 855 Centaur Bracers (steps 100-102) also drops from Rocklance (rare elite) and Warlord Krom'zar
(elite); 845 The Zhevra (98) from Swiftmane (rare elite); 850 Kolkar Leaders (115) kills the named Barak Kodobane (now skipped); 881 Echeyakee and
882 Ishamuhale (105, 128) are named rares with a `.todo` and no position; 6543 The Warsong Reports (132) has three item objectives with no source in the data.

## The last chapter (generation 1, 23 Ashenvale, levels 29 to 30)
Steps 322-326: The Lost Pages (three item objectives, no position, `.todo`), Satyr Horns (the camps near 67-81,41-56; named satyrs among the drop sources)
and a last step `.level 30 -- reach it first: kill or grind on the way`, which names no amount. The guide ends at 30 with nothing left in the log (by its
own accepts and hand-ins never more than 9 quests are held; the longest stay is Moonglade's 104 steps).

## Findings, ranked (impossible, dangerous, confusing, missing)
1. IMPOSSIBLE as written: no way off Zephras Isle. The pack has no transport, crossing or flight master for map 2521. The only link in the data is the island
   story 93836 -> 93090 -> 95349 The Earthen Ring (starts with Ayessa Dawnsinger on the island, ends with Alaana Stormwalker in Mulgore, who gives 95350). The
   planner prices any trip off the island at a flat 15 minutes, so every technique but greedy left the story out (about 30 quests). Experiment: 95349 as a
   mandatory quest keeps the character on the island to level 15 (beam total 28h52 -> 41h13). The question item "How does a Skyborne character leave Zephras
   Isle" holds it; the guide's first step ("Read this first") says so. Not applied, for the user: `--chain 95349,94911` in the manifest would force the story.
2. DANGEROUS: quests generation 1 accepts that the Tauren worker's rules skip: escorts 6523, 6544, 6641, 6482, 4770, 4904 (from memory of Classic), probable
   Warlock/Rogue class quests 98251, 98252, 65601, 76156, 76160, 76240, 527 Battle of Hillsbrad (ends in Southshore), 857, 92422, 92706, 97003. "Regenerate the
   Skyborne guide after both druid guides' HARDCORE rules are merged"; `tools/tests/test_shipped_guides.py` names what is left.
3. DANGEROUS: instance quests. 1491 Smart Drinks, 1013 The Book of Ur and 6921 Amongst the Ruins were routed (zones 279, 310, 221 are instance map ids, not maps of
   the pack); skipped by rule. 5726 Hidden Enemies and 6562 are offered at its steps. "Dungeon and raid quests are not recognized".
4. DANGEROUS: elite sources among ordinary ones: 869 and 865 (Takk the Leaper), 845 (Swiftmane), 855 (Rocklance, Krom'zar), 1104 (Vile Sting), 86576 (Sister Riven,
   Bloodfury Ripper): notes added by rule. "HARDCORE guides route item quests with an elite source among ordinary ones".
5. DANGEROUS: named targets with no rank (none of the 419 Forever creatures has one): skipped 879, 850, 6621, 5147, 1150 (low confidence, by name); noted 94638
   (Ur'endra) and 6441 (satyrs); unflagged 92470 Urs'anah (level 5), 94488 Haalien, 92693 Ferauu, 876, 872, 896, 843, 846, 1096. "The pack has no rank for any Forever creature".
6. DANGEROUS (Classic, from memory, not proof): Hillsbrad at 24-26, the Kolkar camps and Bael'dun in the Barrens, Thousand Needles at 28-30, the Ashenvale satyrs at
   29-30; two zeppelin trips to the Eastern Kingdoms (Undercity at 19-20; Silverpine, Hillsbrad, Tirisfal at 24-26).
7. CONFUSING: 38 zone changes are `.todo` + `.zone` (26 "no route yet", 12 "no crossing coordinates yet"). 12 of 35 stops last five minutes or less, one hand-in each
   (Mulgore and Thunder Bluff three times in steps 57-73). "Skyborne Druid guide: 38 zone changes are placeholders".
8. CONFUSING: three bare `.level` gates (9: no wait; 29: 0h25 in Thousand Needles; 30: the last step) name no amount ("A grind step says how much experience to
   grind"). 87 of 204 accepts are above the simulated level before their step (9 by two, inside steps that level the character; the Undercity library quests
   78127, 78143, 78145, 78149, 79097 carry invented levels: 20, required 1).
9. CONFUSING: 24 objectives with no position and 3 only where the route does not go (the relics): `.todo`; quests started by objects (79192, 79980, 900-902, 549,
   95883, 95885), items with no source. Existing item "Thin Forever quest records and chains the pack cannot order".
10. MISSING: quests offered where the player stands (next section).
11. MISSING: nothing says where a Windshaper learns Cure Poison (14) and Aquatic Form (16); the Tauren chains are Tauren-only (race mask 32). "A Windshaper's Cure Poison ...".
12. MISSING: Moonglade: both legs are placeholders, the relics have no pins, the drafted Teleport: Moonglade text survives only as the note on 94913. "Skyborne Druid
    guide: the Moonglade trips and the Cat Form relics are placeholders".

## The user's rule: a quest offered where the player stands (generation 1)
Method: for each step, the planner's kept quests with a giver within 150 yards, offered by the planner's own availability test at that point (level and quests
done), with every objective within 250 yards of the next six steps, that the guide never accepts. Ten found, six real: 92462 Infestation Investigation (step 1;
the user's find; 92463 follows it), 92598 The Gift of Skysight (4; the Windshaper's own fork quest), 92473 Aggressive Encroachment (8), 94411 Meddlesome Mages (11),
92528 Among the Faithful (18; the first link of the island story), 93317 Crab Season (19); borderline 79007 (200; thin record). Not to take: 99108 (probably a
Warrior class quest), 6562 (Blackfathom Deeps lead-in), 5726 (Ragefire Chasm). Cause: the objective, not the finalist choice. In the saved generation 1 plans only
greedy (340 quests) and lookahead (237) take 92462 and 92463; beam (218) and thorough (202) do not: a few minutes of kills for an unknown-XP quest make a route
slower. A beam run under the current rules takes them by chance (47h45 in the planner's accounting). No manifest hint fixes it: a `--chain` hint to a quest that is
not mandatory is dropped with it (the beam then skipped Foul Matriarch), one to the class quest 92485 forces them but the rough beam's total jumped (28h52 -> 39h07).

## Class quests (all ten routed, none skipped)
92485 at 2; 94006 and 94638 on the island at 10; 94911 at 12 (opens at 10) and 94913 held from 12 to 20; Cat Form: 98340 taken in Thunder Bluff at 20, 98341, 98404 and
98738 in Moonglade at 21, 98362 handed in at 21: one Moonglade trip, placeholders both ways, the three relics `.todo`. The weapon quest: 98823 Earthen Echo (level 31 from
24; Bashana Runetotem in Thunder Bluff to Muln Earthfury) has the Windshaper bit in its race mask; the Tauren worker's `earthen-echo` entry in Classes/DRUID.lua says
Tauren only: add "Skyborne" if it is the druid weapon quest (unverified; their rule skips it for HARDCORE).

## Generation 2 (this branch)
GENERATION2

## Recipe: make this guide again, and check it
Inputs: tools/hardcore_rules.json (rules by quest id: 18 from this review; the Tauren worker's apply to this guide once merged), tools/drafts.json (entry
horde-windshaper-druid: `--chain 94911,94913` on skyborne-arrival-12, `--chain 98340,98341,98404,98738,98362` on windshaper-cat-form-20, the `--race-bit`s,
"hardcore": true, the "planned" note the installer rewrites), Guides/HordeWindshaperDruid.lua (the installer replaces only its `#skipquest` and `#include` lines and
keeps the rest: `#guide`, the "Read this first" chapter and step), Classes/DRUID.lua, the pack in ../Signpost_Data. Guides/, both TOCs and tools/drafts.json must be
committed (else `--force`).
1. `python tools/route_planner.py windshaper --preset all --install --quiet` (15-25 minutes on a busy machine: run it in the background) writes plans/horde-windshaper-druid/
   (gitignored), the chapters windshaper-druid-NN-<zone>, the guide's `#skipquest`/`#include` lines, both TOCs and the "planned" note, and runs StyLua.
2. `python tools/guide_lint.py --strict` (0 errors, 0 warnings); `python tools/guide_sim.py --check` (no findings);
   `python -m unittest discover -s tools/tests -t tools` (test_shipped_guides: rules and chapters agree); `& .\tools\check.ps1`.
3. Post-checks from the repository root, PowerShell: `Select-String -Path Guides\Chapters\windshaper-druid-*.lua -Pattern '<p>'` with <p> =
   `^\s*\.accept (92462|92463)\b`: 2 lines (the user's early test; generation 1 had none);
   `^\s*\.accept (1491|1013|6921|879|850|6621|5147|1150)\b`: none (this review's skips);
   `^\s*\.accept (98251|98252|65601|76156|76160|76240|6523|6544|6641|6482|4770|4904|527|857|92422|92706|97003)\b`: none (the Tauren worker's rules);
   `^\s*\.accept (92485|94006|94638|94911|94913|98340|98341|98404|98738|98362)\b`: 10 lines (the class quests);
   `\.todo`: about 65 (generation 1) and "Read this first" once in Guides\HordeWindshaperDruid.lua.
4. The user's rule: `python tools/route_planner.py windshaper --preset beam --no-write`, then compare its accepted quests with the chapters': a quest the beam takes at
   a place the route stands and the chapters lack is a candidate (method above).
