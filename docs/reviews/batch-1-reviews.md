# Batch 1: the independent reviews and what became of each finding (2026-10-21)

Batch 1 was ten parallel work packages and one coordinator (CLAUDE.md, "Parallel agents"). When the work was integrated, fresh reviewers who knew only
their brief attacked it: they ran the checks, broke the code in a copy of the repository to see whether the new tests can fail (mutation checks), and read
the guides as a player. They changed nothing. This file records what they found and what was done; the long forms are the backlog items named here
(`python tools/backlog.py show <part of the title>`).

| Review | Scope | Mutants tried | Verdict |
|---|---|---|---|
| R-engine-1 | placement, quest tracking, conditions, pins, the step card's marks | 93 (78 caught) | no must-fix; 5 findings fixed anyway |
| R-engine-2 | launcher, Journal, step card, recorders, profession tracks, TOCs | 81 (62 caught) | no must-fix; 4 findings fixed anyway |
| R-tools | planner, lint, simulator, travel generator, importers, pricing, rules | 74 (63 caught) | one must-fix (fixed), seven to the backlog |
| R-guides-A | the Troll Hunter and Tauren Druid guides, the profession tracks, placement | (reads guides) | three must-fix (fixed in the tools, guides regenerated) |
| R-guides-B | the Skyborne Druid guide | (reads guides) | one must-fix candidate (a quest family, left to the user's decision), the rest to the backlog |

## R-engine-1: placement, tracking, conditions

| Finding | What became of it |
|---|---|
| The saved place is trusted by the positional step id: a regenerated chapter keeps its id, so saved progress silently pointed at another step (5 of 58 stale done marks handed in quests never handed in) | Fixed: a fingerprint of the guide's text is stored in the record; a differing or missing one counts as a lost place and the character is placed again from the quest history (every existing record places once). Follow-ups in the backlog: track texts are not in the fingerprint; a guide update drops the player's own skips |
| `historyReady` took a non-empty quest log as proof that the completed list had loaded (a level 28 follower was placed from the log alone, 209 steps marked skipped) | Fixed: ready means the completed list is loaded and non-empty |
| Optional-only (group quest) steps were passed and saved as done while the quest log was unread | Fixed: `Context:QuestLogLoaded()` gates them (VERIFY(beta): that QUEST_LOG_UPDATE arrives for an empty log too) |
| Placement never started the sticky goals of the steps it passed (all five profession skill goals were lost for a placed character) | Fixed |
| A first placement waiting for history overrode the player's own moves | Fixed: a player move ends the wait and the refinement |
| 15 surviving mutants (undo restore, lost-despite-matching-marks, stale timer, a record with only `current`, history that is only the quest log, three in the tracker) | Fixed with 76 specs; three equivalents stay |
| The accuracy tables in docs/ENGINE.md predate the integrated guides; the Windshaper placement spec might stay red | The tables were re-run and the level term made robust (see the end of this file) |

Found sound: `Placement:Find` is pure and O(n) (a 280-step guide: login 9 ms, `Place` 1 ms); followers at steps 60, 150 and 250 land exactly; a sweep of 957 pins over the shipped guides lost none;
no double placement on a profession re-parse or A-B-A; the undo works; the tracker's API use is retail-shaped and guarded; handlers and timers are wrapped; strings go through `ns.L`.

## R-engine-2: launcher, UI, recorders, tracks

| Finding | What became of it |
|---|---|
| The consent gate on `TRAINER_UPDATE` was untested (a mutant removed it) | Fixed: a spec; the consent text's "none of your gold" is pinned |
| The recorder's size bounds and the skill-source order were not pinned (a 1000x raise passed) | Fixed: specs assert the shipped values |
| The card's `Optional:` line repeated the current step's own group quest | Fixed |
| The consent text and the checklist undercounted what is stored (the skill value of a recipe observation, the known flag, a ride's duration and faction) | Fixed: the text names them |
| Smaller test gaps (`reason = "manual"` for the undo, the `SafeCall` around `OptionalOnly`, the Find my place message) | Fixed with specs |
| The Settings tab's fit rests on a guess about the template's size | Open probe and verify item `launcher-in-the-game` (needs the game) |
| `Bindings.xml` has a header on every binding and no category | Backlog (verify; needs the Key Bindings screen) |
| `foreignWindow` fails open if none of its four functions exists on Forever (a linked window would be filed as the character's own) | Backlog |
| Track data (trainer positions, skill goals) is pinned by almost nothing | Backlog (a lint rule against the pack) |

Found sound: privacy (names only through `UnitName("npc")` on creature, vehicle and object GUIDs; no gold, no player GUID, no chat); every new table is bounded (a few MB worst case); an old-shaped
`SignpostDB` merges; LibDBIcon use matches the bundled minor 57; the launcher touches nothing protected; both TOCs are identical with a dependency-safe load order.

## R-tools: the Python side

| Finding | What became of it |
|---|---|
| `guide_lint --strict` failed with two unmatched track anchors on the regenerated Troll route (the "back in Orgrimmar near level 30" fallback steps) | Fixed: both fallback steps removed from the Skinning and Leatherworking tracks |
| The totals quoted by the workers (Troll 22h48, Skyborne 28h26, Tauren 54h41) do not reproduce: the same command gives 22h07, 31h09 and 44h18; the explanation "class-quest charge" is not demonstrated | Corrected: a beam total is chaotic, compare play time only; docs/PLANNER.md says so and marks its Measurements as taken before integration. The planner/simulator agreement is real (within +1.0 and -3.1 percent under five different settings) |
| `tidy` can leave a quest accepted and unfinished, with no record, in extreme settings (a quest log of 2, an extreme completeness) | Backlog (not reached at the defaults; a fuzz of 1,152 cases found none there) |
| `guide_travel._walk_seconds` ignores the shared `detour`; `guide_sim --params` without `escort_seconds` crashes; the importer's innkeeper name is uncapped; the lint's missing-complete exemption matches any `.todo` containing the name | Backlog, one item each |
| docs/HARDCORE.md still said a `.todo` never completes a step; rule 1491's source count; the `scripted` bit may also mark exploration | The first is fixed; the other two are one backlog item |
| 11 surviving mutants | Backlog (one item, the list) |

Found sound: three Troll beam runs under random hash seeds are byte-identical; the defaults reproduce main's routes (identical per-visit digests with `scripted` stripped and no quest log limit);
the quest log limits 1, 5, 12, 25 and 40 are respected (peaks counted two ways, a 1,152-case fixture fuzz); the importer folds are idempotent and order-insensitive (300 random trials); no new write path touches
the pack; every hardcore rule id exists with the name it claims and none is duplicated.

## R-guides-A: the Troll Hunter and Tauren Druid guides

Walked: all 21 Troll and 22 Tauren chapters, the five profession tracks, both headers; the starts in the Valley of Trials and in Mulgore are sound; every accept and turn-in is within 60 yards of its `.goto` (one
exception); no quest is left in the log (peak 18 and 12); no HARDCORE accept or work is more than one level above the character; all 20 reachable Tauren class quests are routed; the 15 profession trainer
coordinates match the pack.

| Finding | What became of it |
|---|---|
| MUST-FIX, Troll: the Hidden Enemies chain (5729 and 5730 need the elite group quest 5728, only 5728 was optional) made three steps unfinishable and blocked the route at level 13 | Fixed in the planner: everything that needs a group quest through the pack's data is optional too (dropped in a HARDCORE route); the Troll guide was regenerated |
| MUST-FIX, Troll: Blackfathom Deeps quests 6563 and 6921 (objects inside the dungeon) were mandatory steps | Fixed in the planner: a quest whose zone is no map of the pack (an instance) is a dungeon quest, optional in a normal route and dropped in a HARDCORE route; regenerated |
| MUST-FIX, Tauren HARDCORE: the Moonglade legs said "Walk ... find your own way" at levels 11, 20 and 30 (from Classic memory the road runs through level 48+ zones) | Fixed in the generator: a druid guide words every Moonglade leg as "cast Teleport: Moonglade if you have it (VERIFY(beta)), else the way is not in the data", with a note not to walk it; regenerated |
| HARDCORE grind gates do not say why; one grind sits in Moonglade | Backlog |
| Named dangers the HARDCORE route still takes (Copperplug, Bael'dun, the Tear of the Moons, Hillsbrad) | Backlog |
| Find my place errs in the long first chapters (a level 8 Tauren is put at step 29, not 21) | Backlog, and the level term was made robust (see below) |
| Earthen Echo 98823 and the Gloomrise quests may not be a hunter's | Backlog |
| Five Orgrimmar quests from profession NPCs have no skill field | Backlog (verify at the first visit) |
| Developer text in `.todo` lines, an 11-line step, a far pin | Backlog |
| The Tauren walk report described the previous generation | Refreshed after the final regeneration |

## R-guides-B: the Skyborne Druid guide (final generation)

Walked: the first 60 steps, the whole island and its exit line by line, a sample from the middle, the last chapter. Sound: all 33 prerequisites of 95349 (the closure, computed) and every island quest are turned in before
the airship step; 94006 and 94638 are done on the island, so `require [95349, 94638]` worked; the exit is handled honestly (VERIFY marks, no invented coordinates, the airship step is `.zone 1412` plus a note
plus a `.todo` and finishes on arrival); the Moonglade legs say Teleport: Moonglade if you have it and not to walk it; every accept and turn-in pin matches its NPC; the class quests (10) are present and gated;
the quest log never holds more than 10 and ends empty; the race and class gates are right.

| Finding | What became of it |
|---|---|
| MUST-FIX candidate: the route takes the Tauren camp's quests 96605 and 96661 (Camp Narache) and skips the Skyborne's own set 96101 and 96646 as "alternative ... which is routed"; the game very likely does not offer a Skyborne the Tauren set, and accepting the Skyborne's 96101 locks the Tauren ones (PLAUSIBLE, not proven; the lint and the simulator are blind to it) | Not fixed here: the fix means regenerating the Skyborne guide, which was left to the lead and the user. Backlog item (high) with the likely cause (the planner guesses 10% of the level's bar as the experience of a quest the Classic seed does not know) and a PR-body line |
| The "Confront Lorthuna" warning sits on the pick-up, not on the fight twelve steps later | Backlog (filed by the Skyborne worker) |
| Exploring the Horde (93739) is dropped silently as an elite kill: its objectives are talk credits for rank-3 NPCs | Backlog |
| Three relic objectives in Moonglade are `.todo` although the pack has their positions | Backlog |
| A drafter-written `.level` gate has no grind note | Backlog |
| The Moonglade notes name a Nighthaven flight master; no step teaches the flight path | Backlog |
| Ambermill Keep and Forever's named island kills carry no HARDCORE note | Backlog |
| Zig-zags: the island's north camp twice, the Barrens four times | Backlog |
| Same-area omissions on the island (92462, 92598, 92515, 92553, 93951, 92516, 92679) | A note on the user's item; the completeness default is the user's choice |
| The walk report was stale | Refreshed for the final generation |

## Placement after the reviews (WP-B, final)

Two reviewers and the Skyborne worker found the same weakness: on the Skyborne guide (and in the long first chapters of the Troll and Tauren guides) a character who followed the guide exactly was put several steps
ahead, because the level model was a straight line over a chapter that spans many levels, and one level of model error outweighed a clean history. B found two causes, each needed: the line was straight in level
(1.68 levels low on average against the simulator, 3.18 at the 90th percentile, in chapters of nine or more levels), and the level term outweighed a history with no gap in it. The line now runs straight in
experience (Classic's table, VERIFY(launch): backlog item), and in history mode the level gap gets a tolerance (0.3 plus 0.05 per level the chapter spans, scaled by the share of done steps before the candidate;
a scattered or lagging character gets none). Result on the three final guides: the Skyborne follower is exact (0 quest steps at the 90th percentile, worst run 4 steps; it was 10 and 19); no-history tails against the
simulator's levels are 1.9% (Skyborne), 0.2% (Troll), none (Tauren); with chapter headers one level wider at each end the followers stay within the bounds (two levels wider is beyond what the tolerance can take).
60 mutants, all killed but one equivalent. **One bound changed, on the lead's decision:** `mixed.catastrophic == 0` is now at most 0.3% over a larger draw (measured 0.010% Tauren, 0.012% Troll, none Skyborne over about
9,000 runs each; the old zero failed for 2 of 40 other seeds). `levelonly.catastrophic == 0` still holds (worst run 2.76 levels, limit 3). The tables are in docs/ENGINE.md.
