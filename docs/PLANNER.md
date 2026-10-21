# The Route Planner

`tools/route_planner.py` plans a leveling route for a guide's character, level 1 to the cap (30 for Version 1), searches for the
fastest one under the simulator's assumptions, writes it as guide chapters and says in detail what it did. It is one tool: the report
is part of it. It changes a guide only when asked to (`--install`, below); otherwise a route is a candidate to read and compare (PLAN Phase 9).

```
python tools/route_planner.py                          the guides, and what the tool can do
python tools/route_planner.py troll                    plan the Troll Hunter with the default technique (beam)
python tools/route_planner.py tauren --preset all      every technique, with a comparison
python tools/route_planner.py skyborne --preset thorough
python tools/route_planner.py skyborne --preset thorough --parts 1,2,3,4,6,8 --no-check    the grains of progress to compare, the search only
python tools/route_planner.py troll --cap 20 --friction 5 --steps 60 --decisions 20
python tools/route_planner.py troll --quest-log 25 --chapter-steps 4
python tools/route_planner.py skyborne --completeness 0.6 --completeness-trip 45    finish the quests picked up on the way whose work is a short walk away
python tools/route_planner.py windshaper --require 95349    the route must do this quest and the quests it needs (the manifest's `require` does the same)
python tools/route_planner.py troll --preset all --install    plan, compare, and make the best route that passes its checks the guide
```

The guide is named by any words of its id, name, race or class. `--help` lists every setting. It needs the private data pack
(`../Signpost_Data`, or `--pack`). Results go to `plans/<guide>/<technique>/` (gitignored): `report.txt` (what was printed),
`plan.json` and the route as `Guides/Chapters/plan-*.lua` plus `Guides/Plan.lua`.

## Techniques (`--preset`)

| technique | what it does | time |
| --- | --- | --- |
| `greedy` | nearest hub with something to do, a zone finished before the next (how the guides are drafted) | seconds |
| `lookahead` | each choice is tried by playing the next 12 visits on greedily; the best is kept | seconds |
| `beam` (default) | compares routes by **how far they have got** (the level and half of the next one): keeps the 30 best of each half level (8 hubs tried from each), drops a route when another reaches the same situation sooner | about a minute |
| `thorough` | the beam once for each grain of progress (2, 4 and 8 parts to a level; 40 routes wide, 10 hubs from each; each grain on its own, none prunes another), the best finished routes of all of them (each grain's own best route among them, written out, and the report says how far apart the grains are: "The spread of the search"), then the finalists walked hundreds of times with uncertain assumptions (Monte Carlo: pace, kills, drops, respawns) | minutes |
| `all` | every technique above and a comparison | the sum |

Why the beam compares by progress and not by the number of visits: a beam that keeps the best routes after each visit ranks a route that has
dawdled (small visits, a low level) against one that has levelled, and the estimate of what is left (the experience at the greedy walk's pace, the
class quests' charges) was kinder to the first: on the Skyborne, at the hundredth visit the beam's best route was at level 12 with a lower estimate
than the greedy walk's at level 17. The beam filled with dawdlers and the good routes were gone by the time it mattered (a review found it finishing
no route at all on the druids, and routes 10 to 40% slower than the ones now found). Wider is not always better and the search is rough: the width and the
grain change the result by a few hours, which is why `thorough` runs several grains and keeps the best. A route is written out *tidied*: the quests the
search left in the log at the cap are taken out and the same hubs walked again, which can cost a route a lot (it is the search's free experience), so the
beam compares its best finished routes as they would be written, and against the greedy route written the same way; the result is never slower than that.

## What the planner models

- **A node is a situation**: where the character is, level and experience, the quests done and in the log (with their open
  objectives), the clock. **An edge is a visit**: go to a hub and do everything worthwhile there until nothing new turns up (turn
  in, accept, work the objectives of the quests in the log that are there). The cost of an edge is the simulator's time: walking,
  talking, killing and looting, waiting for respawns; experience comes from quest rewards and kills, with the level table.
- **Hubs** are the quest givers, enders and objective areas of a map grouped within about 150 yards (`--hub-radius`).
- **Where the character begins** is the first place the guide as it stands sends them to (`--start MAP,X,Y` overrides it).
- **Availability** is the game's rule (docs/AVAILABILITY.md): a quest is accepted only where the game would offer it (level,
  prerequisites, chains, exclusive quests, race, class, faction). Quests of a chain the data does not link come from the hints in
  `tools/drafts.json` (`--chain`), and the quests the guide's chapters exclude there (`--exclude` with its reason) are left out too. A
  normal route accepts quests up to 5 levels above the character and works on them up to 3; a HARDCORE route 1 and 1, leaves out the elite
  and boss objectives, the dungeon quests (below) and the skips of `tools/hardcore_rules.json` (a skip whose reason starts with HARDCORE only in a HARDCORE route; a rule with
  `class_quest_of` only in the guides of other classes: docs/HARDCORE.md). Every quest left out on purpose is named in a `#skipquest` line with its
  reason, as the drafted chapters name theirs.
- **Data it does not trust** (found by an independent review of the first installed guide): the planner leaves out a quest that has no
  start position, no turn-in position (a class quest stays, its step carries a `.todo`), no objective and is accepted and handed in at one NPC
  (free experience; a quest another needs, a chain link and a class quest stay; `--instant-quests` keeps them all), an objective that exists
  only where the route does not go (another continent, a zone nobody quests in), a class that is not the character's (a quest with no mask whose
  giver has a same-named quest limited to another class, or whose giver's other quests all are), and every quest of a battleground zone
  (`skip_zones` in `tools/hardcore_rules.json`). An explore objective is an area to reach, with positions of its own. A class quest with no
  objective in the pack is given 5 minutes and a `.todo`. The setup says how many quests each rule left out.
- **Group quests, dungeon quests and the quests that follow them** (found by an independent review of the regenerated Troll Hunter route, 2026-10-21: a chain whose first
  quest needs a group blocked the route, and dungeon quests were plain steps). A solo player cannot do three kinds of quest, and a normal route tags each `.optional`, so that no
  step waits for it (an optional-only step never holds the player up: GUIDE-FORMAT "Optional-only steps"):
  - an **elite or boss kill**, a *group quest*;
  - a **dungeon quest** (`Planner._in_instance`): the pack sorts a quest under the zone it belongs to, and the id of a dungeon or a raid is not one of the pack's maps (those are
    the world, the continents, the zones and the battlegrounds), so a quest whose zone is no map of the pack is sorted under an instance. A quest with no zone is no dungeon quest,
    and a pack with no maps cannot tell. Its accept carries the note "dungeon quest: needs a group", and its objectives get no `.todo` for a missing position (they lie inside the
    dungeon: that is no hole in the data);
  - a quest that **follows** one of those (`Planner._mark_group_chains`): it needs one by the pack's prerequisites (every quest of a group of prerequisites; of a set of
    alternatives, any one of its `preSingle`, only when every alternative is one of these) or as the quest a chain hands over, and so on down the whole chain. Its accept carries "follows a
    group quest: needs a group too". A class quest keeps its place.

  A HARDCORE route leaves out the first two and, with them, everything that needs them (its prerequisite cannot be routed). A skip rule of `tools/hardcore_rules.json` for the same
  quest is looked at first, so its reason is the one the `#skipquest` line gives. The report's `done` line says how many optional quests there are of each kind and `plan.json` lists
  them (`optional`). Measured on the pack of 2026-10-21 (the pool is what the character may take): the Troll Hunter's has 21 group quests, **10 dungeon quests** (by their names
  Wailing Caverns 962, 1486, 1489, 1490, 1491, Shadowfang Keep 1013, Scarlet Monastery 1113, Blackfathom Deeps 6562, 6563, 6921) and **7 that follow one** (Hidden Enemies 5729 and
  5730, Battle of Hillsbrad 550, the Test of Lore chain 1152, 1154, 1159, 6627); its beam route holds 11 optional quests of 185 (6 group quests, 3 dungeon quests, 2 following one).
  The Tauren Druid's HARDCORE pool loses **6 more** quests to the dungeon rule (962, 1049, 1113, 1160, 1489, 1490), the Windshaper's **5** (962, 1113, 1160, 1489, 1490); the 6 dungeon
  quests the HARDCORE rules skip already (1013, 1486, 1491, 6562, 6563, 6921) are the same in both and keep the rule's reason, so those skips are redundant but harmless.
- **Escorts and events** (the pack's `scripted` flag, QuestieDB's "needs event" bit: the game completes the quest by a script, and the pack
  lists no objective for most of them) are not free deliveries even when they start and end at one NPC (an ambush, a ritual). Such a quest costs
  `escort_seconds` (it starts and ends at different NPCs: the NPC walks with the player, 7 minutes) or `event_seconds` (one NPC: 3 minutes) from
  `tools/sim_params.json`, worked where the quest starts; it is written as `.accept`, `.complete` and `.turnin`, and a `.note` says what it is
  (a HARDCORE route says it as a risk). It is still left out when it is slower than grinding. A class quest keeps its 5 minutes and `.todo`
  (above), and a quest the pack gives objectives is priced by them. A pack built before the flag existed has none, and the planner then
  behaves as it did (an escort between two NPCs passes as a delivery).
- **Profitability**: a quest slower than grinding at the level it is done at is left out (`--threshold`, `--no-skip`), except class
  quests, the quests a kept quest needs, and quests the pack has no experience for.
- **Grinding** is an edge too: forced when nothing can be done until a level opens something, voluntary (one level) when nothing pays
  better. The simulator's own grinding rate is used.
- **Travel** is walking on one continent (distance by the map data, a detour factor); between continents it is the walk to the
  capital's boat or zeppelin, `--ferry` minutes, and the walk from the other capital. Reaching a continent or island with no
  gateway (another race's start island) is not allowed, unless the character begins there. The numbers are
  `tools/signpost_tools/pricing.py`'s, the same ones the simulation of the written route uses (below, "What it cannot see").
- **Zone friction**: every change of zone costs the planner `--friction` minutes (default 3) on top of the travel, so it does not
  hop between zones for a few experience points. It steers the search; it is not play time and is reported apart.
- **Class quests are mandatory** (the chains of `Classes/<CLASS>.lua`, up to the cap): each is done or accounted for with a
  `#skipquest` reason (an alternative the route did not take). At the cap only they, and what they need, are still worth the walk.
  There is no deadline (user, 2026-10-20): a class quest costs the route `--class-push` minutes (default 20) for every level past the one it
  opens at when it is handed in, up to `--class-grace` + 6 levels, so the route picks one up when it passes the giver and makes the trip for a far one
  (Moonglade) soon after it opens. While a quest is undone the search ranks a route by what it will probably cost: the level the character will
  have when it gets there (its own, plus the levels the trip takes at the pace of the greedy walk), so a quest that has not opened costs nothing
  and levelling is never what a route is charged for. This estimate ranks routes and does not prune them (see `hopeless`: a route is dropped
  only when it cannot beat the best finished one even with the class quests free). The search always tries the nearest few hubs (up to 4) where a
  class quest that is past its level can be got on with.
- **Steps are activity steps** (user, 2026-10-20; `signpost_tools/steps.py`, docs/GUIDE-FORMAT.md "Step kinds"): the route is written one
  place at a time and neighbouring steps of one kind within `--group-yards` (250) are joined: one pick-up and hand-in step per area (a hand-in
  and the next pick-up at one NPC are one step; the step keeps the `.goto` of every place in it, the player's pins when there is no data pack), one doing
  step for quests whose objectives are close to each other (the addon draws no marker for it; it keeps its first `.goto` for the tools). A quest whose
  objectives all fall in one doing step is `.complete <quest>`, otherwise `.complete <quest>,<objective>`. A step with a gate or a `.hub` line of its own is never joined.
- **A quest the route picks up is finished, or left out with the reason: completeness** (`--completeness F`, `--completeness-trip T`; **off by default** until the
  user has chosen from the table in "Measurements"; user, 2026-10-21, from his early test of the Skyborne guide: "for step two, it tells me to complete the Harmony and
  Balance. And there is another quest available to pick up called Infestation Investigation, and it's not telling me to pick it up ... these two quests literally are
  completed in the same zone on the map"). What happened there, traced on the route before `tidy` ran: the search accepts every quest on offer where it passes (an accept
  costs it 12 seconds, so it is free), 92462 Infestation Investigation was picked up in hub 566 and its only kill spots are in hub 570, 21.9 seconds of walking east;
  the search never went there (on its numbers the trip paid 1.96 experience a second against 2.46 for the next area: a coin flip on a quest whose experience is a guess,
  10% of the level's), so the quest was in the log at the end of 13 of the 14 finalists, `tidy` took it out silently as "accepted and never finished", and its follow-up
  92463 The Cirrusfly Queen was never offered. It was not the pick-up distance and not the size of a hub (below, "Measurements").

  Now `tidy` does two things with every quest the search left unfinished:
  - **It says so.** Every quest taken out has a record (`plan.stats["left_out"]`): its level, where and at what level it was picked up, the reason with the numbers (the
    walk to its objectives and to the hand-in, the experience a second it pays against the route's pace at that level, the time its work takes) and whether an
    objective of it has no position in the data. The report prints the list (`unfinished`), `plan.json` carries it (`left_out`) and the written guide has a
    `#skipquest <id> >> not finished by this route: <reason>` line for each, so no quest of the pack disappears without a line saying why. The codes:
    `price` (its objectives are within the trip but it pays less than the route's pace asks), `far` (its objectives are farther than the trip), `handin` (the place to
    hand it in is), `level` (it could not be worked at the level it was picked up at, and the route did not come back when it could), `unfinished` (a stop was added
    and it still was not finished).
  - **It finishes what is cheap to finish** (only with `--completeness F` above 0; `Planner._finishable`). A quest qualifies when it could be worked at the level it was
    picked up at, pays at least F of the route's pace at that level (`Planner.finish_ratio`: the quest's experience a second, the walk to its objectives and to the
    hand-in included, over the pace of the greedy walk the searches are calibrated with, which is never below grinding's), and its objectives are at most T seconds of walking
    (`--completeness-trip`, default 30) from where it was picked up, and so is the place to hand it in unless the route goes on to a hub where it is handed in anyway. The
    replay of the route then lifts the block on the quest at its pick-up visit and inserts a stop at the hub of each of its objectives (nearest first) right after that visit,
    and one at the hand-in's hub unless the route passes it later. The visits after that are the route's own, and the walk ends as it always does. A quest still in the log
    after that is taken out for good (`unfinished`); a quest that finishing one opens (92463 after 92462) is a candidate in the next round.

  The search itself is not changed: it still decides where the route goes; completeness decides, once the route is written, whether a quest it picked up on the way is
  finished by a short walk or named as left out. F is a *rate relative to the route's pace*, so it is the same number on every guide and level: 0.6 finishes a quest
  that pays at least 60% of what the route makes there. It is not a promise of the best route (the table shows what it costs). The design note below says what would
  make the search itself choose the shared hunting ground.
- **Required quests** (`--require ID[,ID...]`, repeatable, or `"require": [questID, ...]` in the guide's entry of `tools/drafts.json`; both are used and a quest
  named twice is one; asked 2026-10-21 for the Skyborne island's exit chain, whose finale and the quest that takes the player out must end the island part of the route,
  HARDCORE or not). A required quest is **done whatever it costs**, with the quests it needs:
  - It is mandatory like a class quest: the route is not complete without it, and nothing makes the search give it up. The profitability filter keeps it, `tidy` leaves it in
    the log (a route that ends with one undone is *incomplete* and says so, instead of being written without it), a full quest log never keeps it out and the wait for the
    level it opens at goes on, `skipquests` never lists it, the report's `unfinished` list never has it, and a quest that would close it (an exclusive alternative) is never taken.
  - **The quests it needs are required too** (`Planner._expand_required`): every quest of a group of prerequisites, the quest that has to be in the log (`parent`), and of a set
    of alternatives (any one of `preSingle`) the one that pays best. They are routed, not only kept: requiring the Skyborne's 95349 *The Earthen Ring* makes the 30 quests of the
    island's story chain required, from *Welcome to Shen'dar Village* on.
  - **An error before anything is planned** (exit code 2) when one cannot be offered to the character, naming each quest and the rule: not in the data pack, another class,
    race or faction, above the level cap, excluded by the guide's rules, a HARDCORE route's elite or boss rule, a prerequisite that cannot be routed (which one, and why), a level
    it cannot be accepted from below the cap (a HARDCORE route takes a quest one level above it, not five), two required quests that exclude each other. The HARDCORE rules and the
    guide's exclusions are not overridden: a guide that requires such a quest changes its rules first.
  - **It is scheduled by two rules, not pushed.** A class quest costs `--class-push` minutes for each level it waits past the one it opens at, up to 6 levels; for 30 required
    quests that open long before the character can take them (the island's chain opens at level 4 to 7, and its quests are level 6 to 13, so a HARDCORE character takes them from level 5 to 12) the charge is saturated and
    hides the real time (73 hours of it on the Skyborne, and the beam fell back to the greedy route), so a required quest has no lateness charge; its work still counts in the
    estimate of the time to go. Instead: **the zone lock**, the route does not leave a zone while a required quest has work there (one the game would offer that starts in
    the zone, one with an open objective in it, one whose hand-in is in it; it may do anything else there first, and grinds there for a level a required quest waits for), and
    **the exit**, a required quest that only has to be handed in, and only in another zone, is handed in next: the route leaves for it, and nothing else is an option, not even a
    grind. Together they end the island part of the route with the exit chain: the finale, *What Comes Next*, the pick-up of *The Earthen Ring*, the ride, and its hand-in
    in Mulgore.
  - A required quest the game scripts (an escort or an event) is priced as the work it is (`SCRIPTED_NOTES`), as any quest, not as a class quest's five minutes.
  - The report lists them (`required`: the level each was done at, the level it opens at, how many quests they needed) and `plan.json` has `required` and `required_needed`.
- **A grind step says how much to grind** (user, 2026-10-21: "I'm fine if you want to have certain points in the guide where you simply tell the player to
  grind a certain amount of experience"). When nothing can be done until a level opens something, the route grinds for it (the time is charged, nothing
  else). A grind is not a step of its own: it is two lines at the end of the step it follows, where the character stands when it begins (one that comes first
  goes on the step after it):

      .level 12 -- reach it first: kill or grind on the way
      .note Grind about 2,400 experience before you go on: about 55 kills of creatures near your level (an estimate)

  `.level N` stays the gate: the step completes when the character has reached level N, and the quests after it ask for no `.level` of their own. The note
  is the model's number, rounded to two figures: the experience still to grind (from the level table) and the kills of creatures of the character's own level
  that is (the model's kill experience, 45 + 5 for each level, level by level as the character climbs). It does not say "here": the step before may be in a
  town. It promises nothing: rested experience, the quests already in the log and the creatures at hand change the number. No new directive. Two grinds in a
  row are one. The report lists every grind with its amount and the share of the route's experience and time (`grinding`). The drafter's own `.level` gates are
  left as they are, without the note (they are the drafted guides' and the drafter does not price a grind; backlog `a-grind-step-says-how-much-experience-to-grind`).
- **Chapters are cut where the route stays in another zone**: a change of zone starts a new chapter when the new zone lasts at least `--chapter-steps` (default 3)
  steps in a row, counted once the steps are joined. A shorter stay is a detour and belongs to the chapter it happens in (and the first chapter takes in a short
  stay before the first long one), and a chapter is named after the zone most of its steps are in (a step's zone is that of its first `.goto`), which is what the
  Journal's route list shows. Chapter ids keep their shape, `<guide>-NN-<zone>` (`split_chapters` in `tools/planner.py`).
- **The quest log holds a fixed number of quests** (`--quest-log N`, default 40): no quest is accepted while it is full, by every search (a visit, `options`,
  `overdue_hubs` and the replay of a tidied route all go through `Planner.offered`), and a quest handed in at the NPC who gave it needs a free place too. 40 is
  Forever's capacity (Classic's is 25), confirmed by the user in the game, 2026-10-21 (they had said so before: "I believe the quest log limit has been bumped
  up from 25 to 40 for WoW Forever", then "accept a 40 quest cap for wow forever"). The limit counts every quest a partial route holds, including the ones tidy takes out of the written route
  again, so it steers the search harder than it constrains the guide (below). The report gives the most quests held at once, by the planner and counted again on
  the written route's own steps.
- **No quest is left in the log, and none is dropped silently** (`Planner.tidy`): a route that accepted something it never finished has it taken out and the same
  hubs are walked again (the grinds too), more than once if that leaves others unfinished; the quests taken out are named with the reason (completeness, above), and the
  ones a short walk would finish are finished first when the setting is on.

## Reading the report

`ROUTE PLANNER` (who, which data, which assumptions, what was left out and why) - `THE SEARCH` (situations made and dropped, the
baseline greedy route against this one, for a search of several grains of progress `grains`: each grain's best route as it would be
written, the work it took and how far apart they are; `tidied`: the quests taken out; and, with a completeness setting, `completed`: the quests finished instead) - `THE ROUTE AS A GRAPH` (zones with the time spent, the
travel between them, one row per leg) - `TIME AND EXPERIENCE` (where the time goes, the time at each level, and `grinding`: every grind
step with its amount and the share of the route it makes) - `THE QUESTS` (done, the most quests held at once, `unfinished`: the quests the search picked up and the route does not hold, with the reason, `required`: the quests the guide requires and the level each was done at, left out as
slow, the class quests with the level each is done at against the level it opens at) - `THE DECISIONS` (each change of
zone and the best route held in other zones at that step) - `CHECKED BY THE SAME SIMULATOR AND LINT` (the route written as guide
steps with the travel steps added, walked by `guide_sim` and `guide_lint`: availability errors, the most quests the written route
holds at once, lint errors, `.todo` steps, and how
far the full simulation is from the planner's estimate) - the first steps of the route as the simulator walks them.

## Installing a route (`--install`)

Installing is the step you take on purpose, and it refuses what looks like a mistake: no guide named, `--no-check`, a `--mode` other than the
guide's own, a route that stops below the guide's current top level and uncommitted changes in the guide files (`--force` overrides the last
two). The route to install is chosen among the routes that pass every check (it reaches the cap in the planner and in the full simulation, the
game would offer every quest where the route accepts it, no lint error): when `thorough` ran, every technique's route and thorough's finalists
are walked many times with varied assumptions and the one with the shortest median time to the cap wins (a run that never reached the cap counts as
infinitely slow, so a route that fails often has no median and the report says how often; ties: the shorter 90th percentile, then the lower planner
total), otherwise the lowest total wins. ("Fastest in most runs" is printed too but not used: finalists a few minutes apart
win it by luck.) The report then describes that route.

`tools/route_install.py` reads and checks everything first and writes nothing if anything is wrong. Then it writes the chapters as
`Guides/Chapters/<guide>-NN-<zone>.lua` (header `PLANNED` with the command that made it; the next install replaces them, do not edit them),
replaces the `#include` and `#skipquest` lines of the guide text and leaves every other line (`#professions`, notes, hand-written steps), sets
`levels`, deletes the chapters the guide used before unless another guide or chapter includes them, keeps both TOCs in step, marks the guide
`planned` in `tools/drafts.json` (its chapters, with their `--chain` and `--exclude` hints, stay: the planner reads them, and `rebuild_drafts.py`
skips a planned guide) and runs StyLua. Read `git diff`, run `tools/check.ps1` and, with the data pack, `guide_lint.py --strict` and
`guide_sim.py --check`, then commit. Nothing is published.

## What it cannot see (read these before trusting a number)

- **Every number is an assumption** (`tools/sim_params.json`): Classic's XP table, quest XP from QuestieDB's Classic seed (10% of
  the level when a quest has none), 8 kills and 6 items per objective, kill 12 s, loot 4 s. The route is the best one under them,
  not a prediction of a player's clock. Forever's own tuning is unknown (CLAUDE.md, "Forever is not Classic"): quests and class
  quests Forever added that the pack lacks are not routed.
- **Travel is priced once, and still an assumption.** The planner's search, the travel graph that proposes a guide's travel steps and the
  simulation of the written route take their numbers from `tools/signpost_tools/pricing.py` (7 yards a second, no detour, flights, a boat's
  3 minute wait and 4 minute ride, the hearthstone, 15 minutes for a change of continent the data has no boat for); a `"travel"` object in
  `tools/sim_params.json` overrides any of them, and a typo there is an error. Before this the simulation charged nothing for a `.zone` hop
  (the step leaves the player nowhere in particular, so the next walk was never measured) or for a change of continent with no boat in the
  data, and a planned route simulated 14 to 24% under the planner's estimate. Now the fidelity line agrees within 3% (beam, shared pack:
  Troll Hunter 20h15 simulated against 20h37 planned, -1.7%; Tauren Druid 24h12 against 24h57, -3.0%; Skyborne Druid 22h31 against 22h59,
  -2.0%). What is left is travel: the planner walks between hub centres and adds 8 seconds for each change of place within a visit (about 20
  minutes a route), and the simulation walks the steps' own positions and does not price the walk inside a doing step (last bullet). The
  detour is 1.0 (the straight line) because no play data says otherwise, and a boat or zeppelin has never been timed: `python tools/guide_sim.py
  --pace` is the way to calibrate once play data exists.
- **Class quests are pushed, not scheduled**: a chain whose quests are far apart (the Cat Form chain's items) can still come several levels
  after it opens; the report lists the class quests more than 5 levels late and the level each was done at. A character that starts on an island
  (the Skyborne's) cannot reach the other continents' class quests before it leaves, however hard they are pushed.
- **The search is rough**: two settings that look alike (a width of 30 or 60, 4 or 8 parts to a level) can differ by hours on a guide with many class
  quests (the druids), and a wider beam is not always better. `thorough` runs several grains and keeps the best, and its report says how far apart the grains'
  best routes are (`grains`: trust the best route no more than that; a warning above 5%). Read the baseline line of the report too, which says how much faster the
  result is than the greedy route, and distrust a route that is not clearly faster. "Measurements" below has the numbers. Measured on the Tauren Druid (beam, total =
  play + zone-change cost + the class-quest charge): widths 20, 30 and 45 and 4 parts give 48h59, 44h40, 43h02 and 50h42; leaving the data and the settings
  alone and changing `loot_seconds` from 4 to 4.1 gives 50h33, and `interact_seconds` from 12 to 12.5 gives 53h38. The play time moves less (24h57 to
  29h36 over those six runs) than the total; most of the swing is the charge for class quests done late (15 to 24 hours), i.e. whether the beam happened
  to hold a route that makes the Moonglade trip early. So a total is comparable only between runs of the same data and settings, and a change of data is
  judged by the play time and the "done at level" line of the class quests, or by the deterministic `greedy` preset (the escorts and events above cost it
  23 to 45 minutes of play on the three guides).
- **Completeness is local and rests on guesses**: it decides only about quests the search accepted (it does not make the route go back for one it has not picked up),
  measures the trip from the place the quest was picked up to its objectives and, unless the route passes there anyway, to the hand-in (the walk back to the route is the next
  visit's travel, and a quest with objectives in two hubs gets a stop at each), and compares the quest's rate with the route's pace, both on the model's numbers. A quest new to Forever has a guessed
  experience (10% of the level's), 8 kills and 6 items stand for whatever it asks, and an objective with no position in the data is planned as worked where the quest is
  picked up, with no walk (backlog `objectives-with-no-position-in-the-data-are-planned-as-done`): such a quest looks free to finish, and the report
  counts them (`completed`, `unfinished`, `completed_unplaced` and `unplaced` in `plan.json`). It does not look at the quests of one hunting ground together
  (design note below).
- **Required quests are scheduled by rules, not by cost**: the zone lock and the exit say *when in the route*, not *how soon*. The route does a required chain before it leaves
  the zone, and it does it last there (after the side quests that pay as well as the mainland), so the Skyborne leaves the island at level 14 to 16 where players leave at 12 to
  14 ("Measurements"); nothing in the model asks for an early exit. A required quest in a zone the route never goes to is done where the search finds it cheapest (often at
  the end of the route); the alternative of a set of prerequisites that stands for the others is the one that pays best, not the author's pick; the lock keys on the zone of a
  hub, so a zone that is split in two by the map data is two zones; and a quest that closes a required quest only through a prerequisite is not looked at.
- **The quest log limit counts what the search holds**, which is more than the written route holds ("Measurements"): 40 is Forever's capacity (confirmed by
  the user in the game, 2026-10-21; Classic's is 25).
- **The escort and event times are assumptions** (`escort_seconds`, `event_seconds`): Classic's escorts take about 5 to 12 minutes with their
  pauses, none is measured for Forever. The flag comes from QuestieDB's Classic baseline, so an escort Forever added is not flagged, and what the
  escort does on the way (where it goes, what attacks it) is not in the data: the note says so.
- **Data holes become `.todo` steps**: an objective with no position in the pack is worked where its quest starts, and the step
  says so; a zone change the travel data cannot place gets a placeholder step in plain words (docs/GUIDE-FORMAT.md) that the lint counts as a
  `.todo`. The travel generator also teaches flight paths: where the route passes a flight master and a later zone change would fly from it,
  it adds a `.fp` step (a flight must save 90 s, or there is no other way), so a written route has more travel steps than the planner priced.
- **Group, dungeon and following quests** in a normal route are tagged `.optional`. A step made only of such quests never holds the player up, and the step card shows
  the quest as a line beside the steps before it (`Optional: <quest> (group quest)`, GUIDE-FORMAT "Optional-only steps"). The card cannot yet
  retire the line five levels above the quest: that needs the quest's level in the guide (backlog: `a-group-questid-level-modifier`). The planner still plans them as done (their
  experience and time are in the totals), so a solo player's real route is slower than the plan by about their share. A dungeon quest is found by the zone the pack sorts it under: a
  quest sorted under an instance whose objectives lie outside it is tagged too, and a dungeon quest the pack sorts under no zone is not. What follows a group quest is found
  through the pack's prerequisite and chain data only. A zone missing from the pack's maps (they are the client's own dump) would make its quests look like dungeon
  quests; none does today (the 19 zone ids of quests that are no map of the pack are all dungeons and raids). The drafter (`tools/guide_draft.py`) still tags only elite kills.
- **Walking inside a doing step is not priced**: the planner adds a few seconds for each place of a hub; once the objective areas are joined into one
  doing step the simulator charges only the walk between steps (the step keeps one position). A pick-up and hand-in step keeps the position of
  each NPC, and the simulator walks them in order. This is part of the 2 to 3% by which the full simulation still runs under the planner's estimate.

## Measurements (2026-10-21)

What the quest log limit, completeness, the hub radius and the grains of progress were measured to do (data pack of 2026-10-20, the default beam unless said otherwise,
planner totals with the class-quest charges; each run is deterministic, so a number is reproduced by the command that names it).
These tables were measured on the planner's own branch, before the other batch-1 work (both druid rule sets, the `scripted` flag of the rebuilt pack, the shared
travel price) was merged: compare their numbers with each other, not with the totals of the guides installed afterwards. A beam total is chaotic (an independent
review ran the default beam on the integrated tools and the rebuilt pack and got Troll 22h07, Skyborne 31h09 and Tauren 44h18, which are not the numbers of these
tables or of the installed guides): judge a route by its play time and the class quests' "done at level", and re-measure after any change of data or rules.

**The quest log limit** (`python tools/route_planner.py <guide> --quest-log N --no-check --no-write`). The first number of a cell is the beam's total,
the one in brackets the most quests the written route holds at once:

| limit | Troll Hunter | Skyborne Druid | Tauren Druid |
| --- | --- | --- | --- |
| none (`--quest-log 1000`; the result before the limit existed) | 22h33 (16) | 28h52 (15) | 44h40 (11) |
| **40 (the default)** | 22h49 (16), +16 min | 28h52 (15), the same | 44h40 (11), the same |
| 25 (Classic's) | 23h40 (20), +1h07 | 31h22 (14), +2h30 | 44h52 (11), +12 min |
| 12 | 23h30 (12), +57 min | | |

The written routes hold at most 16, 15 and 11 quests, far below the limit, yet the limit slows the search: with the log unlimited the Troll Hunter beam's
situations hold more than 40 quests in 29% of the cases (more than 25 in 67%, at most 68), because the search accepts every quest on offer at the places it
passes and `tidy` takes the ones it never finishes out of the route afterwards (41 in the best Troll Hunter route). Those are counted against the limit while
the search runs, so it steers the search much harder than it constrains the guide. The differences are of the size of the search's own roughness (below), so
they are not a measure of what a real limit of that size would cost a player; a search that does not count the quests it will take out again would not lose
them (backlog `the-quest-log-limit-counts-quests-the-search-takes-out-again`). A relaxed search (no limit while it looks, the limit only when the route is written
out again) was tried and not kept: while the limit does not bind it is the unlimited search, but at a limit of 12 the Troll Hunter came out at 28h51 against 23h30
for the limit applied everywhere (the replay that has to obey the limit throws away the quests the search counted on), so the limit is applied everywhere.

**Completeness** (`--completeness F --completeness-trip T`; the beam, data pack of 2026-10-20, quest log 40; each row is one deterministic run and `off` is the planning
without the setting; in brackets the change against `off`; "quests added" are the quests the setting finished instead of taking out, "(+n)" the further quests the route then
does that those opened). The default stays **off** until the user has chosen from this table (backlog `completeness-which-values-of-f-and-t-should-be-the-defaults`).

**Troll Hunter (normal)** (planner totals with the class-quest charges; in brackets the change against `off`)

| F | T | quests added (and what they open) | planner total | class-quest charge | play, planner | full simulation |
| --- | --- | --- | --- | --- | --- | --- |
| off |  | 0 | 22h49 | 0h20 | 21h02 | 18h12 |
| 0.8 | 30 s | 0 | 22h49 (+0.0%) | 0h20 | 21h02 (+0.0%) | 18h12 (+0.0%) |
| 0.6 | 30 s | 0 | 22h49 (+0.0%) | 0h20 | 21h02 (+0.0%) | 18h12 (+0.0%) |
| 0.4 | 30 s | 0 | 22h49 (+0.0%) | 0h20 | 21h02 (+0.0%) | 18h12 (+0.0%) |
| 0.6 | 45 s | 1 (+2) | 22h47 (-0.1%) | 0h20 | 21h00 (-0.1%) | 18h11 (-0.1%) |
| 0.8 | 60 s | 1 (+2) | 22h47 (-0.1%) | 0h20 | 21h00 (-0.1%) | 18h11 (-0.1%) |
| 0.6 | 60 s | 1 (+2) | 22h47 (-0.1%) | 0h20 | 21h00 (-0.1%) | 18h11 (-0.1%) |
| 0.4 | 60 s | 1 (+2) | 22h47 (-0.1%) | 0h20 | 21h00 (-0.1%) | 18h11 (-0.1%) |
| 0.8 | 90 s | 1 (+2) | 22h47 (-0.1%) | 0h20 | 21h00 (-0.1%) | 18h11 (-0.1%) |
| 0.6 | 90 s | 1 (+2) | 22h47 (-0.1%) | 0h20 | 21h00 (-0.1%) | 18h11 (-0.1%) |
| 0.4 | 90 s | 5 (+2) | 22h39 (-0.7%) | 0h20 | 20h52 (-0.8%) | 18h03 (-0.9%) |

**Tauren Druid (HARDCORE)** (planner totals with the class-quest charges; in brackets the change against `off`)

| F | T | quests added (and what they open) | planner total | class-quest charge | play, planner | full simulation |
| --- | --- | --- | --- | --- | --- | --- |
| off |  | 0 | 44h40 | 17h40 | 24h57 | 18h57 |
| 0.8 | 30 s | 0 | 44h40 (+0.0%) | 17h40 | 24h57 (+0.0%) | 18h57 (+0.0%) |
| 0.6 | 30 s | 0 | 44h40 (+0.0%) | 17h40 | 24h57 (+0.0%) | 18h57 (+0.0%) |
| 0.4 | 30 s | 0 | 44h40 (+0.0%) | 17h40 | 24h57 (+0.0%) | 18h57 (+0.0%) |
| 0.6 | 45 s | 0 | 44h40 (+0.0%) | 17h40 | 24h57 (+0.0%) | 18h57 (+0.0%) |
| 0.8 | 60 s | 0 | 44h40 (+0.0%) | 17h40 | 24h57 (+0.0%) | 18h57 (+0.0%) |
| 0.6 | 60 s | 0 | 44h40 (+0.0%) | 17h40 | 24h57 (+0.0%) | 18h57 (+0.0%) |
| 0.4 | 60 s | 0 | 44h40 (+0.0%) | 17h40 | 24h57 (+0.0%) | 18h57 (+0.0%) |
| 0.8 | 90 s | 0 | 44h40 (+0.0%) | 17h40 | 24h57 (+0.0%) | 18h57 (+0.0%) |
| 0.6 | 90 s | 1 | 46h02 (+3.1%) | 19h00 | 24h59 (+0.2%) | 18h59 (+0.2%) |
| 0.4 | 90 s | 1 | 46h02 (+3.1%) | 19h00 | 24h59 (+0.2%) | 18h59 (+0.2%) |

**Skyborne Druid (HARDCORE)** (planner totals with the class-quest charges; in brackets the change against `off`)

| F | T | quests added (and what they open) | planner total | class-quest charge | play, planner | full simulation | 92462, 92463 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| off |  | 0 | 28h52 | 4h20 | 22h59 | 18h24 | no, no |
| 0.8 | 30 s | 0 | 28h52 (+0.0%) | 4h20 | 22h59 (+0.0%) | 18h24 (+0.0%) | no, no |
| 0.6 | 30 s | 1 | 29h33 (+2.4%) | 5h00 | 23h00 (+0.1%) | 18h25 (+0.1%) | yes, no |
| 0.4 | 30 s | 1 | 29h33 (+2.4%) | 5h00 | 23h00 (+0.1%) | 18h25 (+0.1%) | yes, no |
| 0.6 | 45 s | 3 (+2) | 29h49 (+3.3%) | 5h20 | 22h56 (-0.2%) | 18h21 (-0.2%) | yes, yes |
| 0.8 | 60 s | 3 (+3) | 30h09 (+4.5%) | 5h40 | 22h56 (-0.2%) | 18h22 (-0.2%) | no, no |
| 0.6 | 60 s | 5 (+2) | 30h32 (+5.8%) | 6h00 | 22h59 (+0.0%) | 18h25 (+0.1%) | yes, yes |
| 0.4 | 60 s | 6 (+2) | 30h33 (+5.9%) | 6h00 | 23h00 (+0.1%) | 18h27 (+0.3%) | yes, yes |
| 0.8 | 90 s | 5 (+2) | 30h12 (+4.6%) | 5h40 | 22h59 (+0.0%) | 18h23 (-0.1%) | no, no |
| 0.6 | 90 s | 7 (+2) | 30h56 (+7.2%) | 6h20 | 23h03 (+0.3%) | 18h27 (+0.3%) | yes, yes |
| 0.4 | 90 s | 8 (+2) | 30h57 (+7.2%) | 6h20 | 23h04 (+0.4%) | 18h30 (+0.5%) | yes, yes |

What the table says:
- **T matters, F hardly does.** At T = 30 s only the Skyborne gains a quest, 92462 Infestation Investigation (its work is 20 s away and pays 71% of the route's pace, so F = 0.8
  leaves it out and 0.6 or 0.4 finishes it); the Troll Hunter and the Tauren Druid gain none. At T = 45 s the Skyborne route does 92462 *and* its follow-up 92463 The Cirrusfly
  Queen (which is offered only once 92462 is handed in) and Flutterfly Dust, which pays 1.6 times the pace and is 34 s away; the Troll Hunter gets one small quest and the
  Tauren Druid none. Past 60 s the further quests are mostly small ones; the Troll Hunter gets 5 only at F = 0.4 and T = 90 s.
- **Most of what tidy takes out is far away**, and stays out: of the 28 (Skyborne), 41 (Troll Hunter) and 16 (Tauren Druid) quests the beam picked up and did not finish, 19, 30
  and 11 have their objectives more than 30 s from the pick-up (for the Troll Hunter and the Skyborne about a third of them pay less than a tenth of the route's pace; the rest pay as
  well as the route but are 70 s to several minutes away, and 857 s is the model's fallback for a place on another map with no walk known), 8, 7 and 5 are handed in far away where
  the route does not pass, and 4 (Troll Hunter) could not be worked at the level they were picked up at. The list with the reason and the numbers is in every report (`unfinished`),
  in `plan.json` (`left_out`) and as `#skipquest` lines in the guide.
- **It costs no time.** The planner's play time and the full simulation of the written route move between -0.9% and +0.5% in every row: the quests finished pay for their stops.
  The Skyborne's planner *total* rises by 2.4 to 7.2% (the Tauren's by 3.1% in its one row) only because of the class-quest charge (the Skyborne's 4h20 up to 6h20), which counts levels: a quest finished early puts the character a
  level higher at the later hand-ins of the class quests, and the charge counts that as 20 minutes each though the clock is not later (backlog
  `the-class-quest-charge-counts-levels-so-experience-gained`). Read the two play times, not the total.
- **None of the quests added has an objective with no position in the data** (`completed_unplaced` is empty in every run), so the numbers are not flattered by the bias of
  planning such an objective at the quest giver with no walk (backlog `objectives-with-no-position-in-the-data-are-planned-as-done`). One of the Troll Hunter's quests left out
  has such an objective.
- The raw search does not change with F or T (only the tidy that follows does, and the ranking of the finalists as written), so the rows of a guide are comparable with one
  another; a different guide, width or data pack is not (the search is rough: "What it cannot see").

**Required quests: the Skyborne island's exit chain** (`--require 95349`; HARDCORE; data pack of 2026-10-21, commit ca4420f; `--preset beam`, and `thorough --runs 10`; each run
is deterministic). *Play* time is what to read: the totals carry the class-quest charge, which moves by hours with the order of the class quests and is not comparable. The island is
the first leg of the route (Zephras Isle); 95349 *The Earthen Ring* is the quest that takes the player out, accepted from Ayessa Dawnsinger on the island and handed in to Alaana
Stormwalker in Mulgore, the end of a chain of 30 quests.

| run | play, planner | play, full simulation | leaves the island | quests done on it | planner total |
| --- | --- | --- | --- | --- | --- |
| beam, nothing required | 25h45 | 25h30 | level 11 after 3h03 | 37 | 31h09 |
| beam, `--require 95349` | 27h11 (+5.6%) | 26h51 (+5.3%) | level 16 after 6h31 | 83 | 35h37 |
| thorough, nothing required | 24h48 | 24h32 | level 12 after 3h00 | 38 | 28h58 |
| thorough, `--require 95349` | 24h32 (-1.1%) | 24h55 (+1.6%) | level 15 after 5h35 | 72 | 36h31 |

- **The island part ends with the exit chain, in both routes** (checked in the written chapters): the finale (*Prepare for Battle* to *Confront Lorthuna*), *The Fate of Zephras*,
  *What Comes Next*, the pick-up of *The Earthen Ring*, the ride to Mulgore (`.zone`), and its hand-in there. The beam does the finale at level 15, 5h56 into the route, and the pick-up
  of 95349 at 6h29; the next leg is Mulgore. Both routes pass the availability check and the lint with no error and no warning.
- **Grinding at level gates: none on the island.** The beam grinds 3 minutes there (430 experience, level 14 to 15); the thorough route none. The other grinds come later (level 17 and up in the beam, 20 and up in the thorough route).
- **The level gate on 95349** is the HARDCORE rule, not a grind: the quest is level 13 and a HARDCORE character takes a quest one level above it, so it opens at level 12 (the finale
  quests, level 12, at level 11). Its required level, 7, is no gate.
- **Why the island is left at 14 to 16 and not at 12 to 14.** In the model the island pays 5.8 to 6.9 experience a second at levels 11 to 14, the mainland route without the requirement
  3.2 to 4.1 at levels 11 to 13 (6.6 at 14): the island's quests are dense and their experience is a guess (the pack has none for them: 10% of the quest level's bar, about 1,000 for
  a level 12 quest). The guess decides the exit: with half of it (`--param quest_xp_fraction_of_level=0.05`) the beam leaves at level 14 (6h15, 76 quests), with 0.075 at 15, with 0.1 at
  16. And the exit chain comes *last* on the island (the zone lock), after the side quests; at levels 15 and 16 the island pays 2.5 and 4.2 against the mainland's 4.7 and 5.7, so
  the two levels after 14 are the rough beam's, not the model's preference. Nothing in the model asks for an early exit (backlog
  `the-skyborne-island-is-left-at-level-14-to-16-when-its-exit`).
- **Earlier versions of the option, for the record** (beam): with only 95349 mandatory like a class quest the character left the island at level 13 (4h24) and came back at level 29
  to do the chain (1h47), handing 95349 in at level 30 (play 33h58). With the whole chain mandatory and pushed like a class chain (30 quests) the class-quest charge was 73 hours, the
  beam finished no route better than the greedy one, and that route went back to the island at the end (total 106h54, play 31h57). An earlier measurement of 28h52 to 41h13 with the island
  until level 15 was of this second kind: the total is the charge. The lock and the exit replace the push.

**The hub radius and the walk inside a hub** (`--hub-radius`, `--walk-by-map`; the beam with nothing else changed, the full checks). The radius was looked at as a possible cause of
the missing 92462 because the user's first idea was a bigger "area" (he called it a shot in the dark), and it is not the cause: a separate `thorough` run of the Skyborne at 300
yards merged the NPCs and the kill area of 92462 into one hub (the first visit takes it and 92463 follows, 26.71 h against 26.72 h at 150) and at 500 yards was far too coarse
(92462 taken late, 92463 absent, 34.91 h), with `tidy` still taking 22 quests out. `--walk-by-map` prices the walk between the places of one hub by the map's distance instead of a flat 8 s (`Settings.local_walk`).

| radius | walk inside a hub | Skyborne: hubs | planner total | full simulation | Troll Hunter: hubs | planner total | full simulation |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 150 (the default) | flat 8 s | 613 | 28h52 | 18h24 | 569 | 22h49 | 18h12 |
| 150 | by the map | 613 | 42h34 | 24h54 | 569 | 21h01 | 17h04 |
| 250 | flat | 392 | 29h28 | 19h11 | 357 | 22h25 | 17h36 |
| 250 | by the map | 392 | 39h26 | 23h01 | 357 | 23h00 | 17h26 |
| 400 | flat | 238 | 27h42 | 17h20 | 220 | 29h03 | 22h27 |
| 400 | by the map | 238 | 30h24 | 18h08 | 220 | 22h28 | 16h50 |

The totals move by several hours either way (the Skyborne from 27h42 to 42h34, the Troll Hunter from 21h01 to 29h03), as much as any other setting of the rough search, and
with no direction: no evidence for a different default, so none is changed. Pricing the walk by the map makes the Skyborne much slower in the planner (every walk between two
NPCs is paid for) and the Troll Hunter faster, which is the same roughness again.

**The grains of progress** (`python tools/route_planner.py <guide> --preset thorough --runs 10 --no-check --no-write`; the `grains` table of the report: each grain searched on its own,
its best route as it would be written). `thorough` runs 2, 4 and 8 parts to a level; the Troll Hunter was run with 1, 2, 3, 4, 6 and 8 as well.

| guide | best route as written, by parts to a level | the grains disagree by | the beam (2 parts) |
| --- | --- | --- | --- |
| Troll Hunter | 1: 26h37, 2: 22h04, 3: 21h50, 4: 34h36, 6: 21h43, 8: 21h54 | 12h53 (59%) | 22h49 |
| Skyborne Druid | 2: 27h56, 4: 41h11, 8: 26h43 | 14h28 (54%) | 28h52 |
| Tauren Druid | 2: 45h46, 4: 40h46, 8: 44h45 (it finished 11 routes) | 5h00 (12%) | 44h40 |

No grain is the best everywhere (4 parts is the worst on the Troll Hunter and the Skyborne and the best on the Tauren Druid), so the answer to "which grain" is the one `thorough` gives:
all of them, and the best route as written. The best of 2, 4 and 8 is 7.4% (Skyborne) and 8.7% (Tauren) shorter than the beam's one grain, and on the Troll Hunter 6 parts is
less than 1% better than the best of the default three, so the default grains stay. Every guide is over the 5% warning: the best route found is a good one, not a proven one.

## Design note: shared hunting spots (not built)

Requested with the completeness work (backlog `shared-hunting-spots-do-the-objectives-of-several-quests-at`; user, 2026-10-21: "I assume the later shared hunting spots
will be written up as a backlog item"). Completeness is the net under the search (a quest the search picked up and did not finish is finished or named); this is
the other half: the search itself choosing the ground that serves most of the quests it has open.

**The problem.** Every kind of objective reduces to a list of spots on the map (`PObjective.spots`, `_consider`): the creatures to kill, the creatures that drop the
item, the containers or ground pick-ups the item lies in, the objects to use, the area to reach (an `explore` objective carries positions of its own). A visit works an
objective at the first hub of the route that has one of its spots (`Planner._index` puts each spot in `objs_by_place`; `visit()` works what is at the hub whatever else
is open). An objective with spots in two grounds is therefore done in whichever the route reaches first, even when another open quest has spots only in the other, and
that quest then needs a trip of its own which the search may never make. Traced case (the Skyborne start): Harmony in Balance (92461) has kill spots in hubs 566 and 570
and was done at 566; Infestation Investigation (92462) has spots only in 570, 21.9 s of travel east (1.96 XP/s for that trip against 2.46 for the next area). Done together
at the east spot, one trip would have served both.

**The idea.** Do what lives in one hunting ground in one trip: for an objective with spots in several hubs, choose the spot that also serves another open quest (one the
route holds, or is about to open at this hub), so a single trip does both. Never a longer walk for one quest than today's rule would make.

**Where it would sit, and a first rule.**
1. The candidates are already known: `PObjective.hubs` lists the hubs that have a spot.
2. For a visit at hub A, an objective with spots in A and B is held back from A when a quest the route holds (in the log, or offered in this visit) has an objective whose
   *only* spots are in B (`len(o.hubs) == 1`) and B is within the trip (`completeness_trip` is the natural measure, or the walk the next area costs): the objective is
   worked in B with the other. Otherwise it is worked in A as now. One rule, no search choice: the answer is the same for every route through the same situation, so the
   state key and the pruning stay valid.
3. The value of a hub for the search (`options`, `rank`) counts the held-back objectives at B as work to be done there; `_quest_rate` charges the walk once for the
   quests that share a ground.
4. Completeness is the safety net: an objective held back for a ground the route then does not go to is a quest left unfinished, which completeness finishes or names.

**Every kind of objective, not only kills.**
- Kills: the same creatures serve any number of quests; the kills of the larger objective count for the others (the model counts 8 kills per objective, so two
  quests on one creature are 8 kills, not 16: a refinement of `Model.objective`, which prices each objective alone).
- Items dropped by creatures: the creature is a spot of the item. One kill session serves a kill objective and an item objective on the same creature; the drop chance
  makes the item the longer of the two, so the session is as long as the item needs.
- Items in containers or on the ground, and objects to use: spots like any other; no respawn wait inside a visit. A ground pick-up beside a kill area is the cheapest
  quest of all to share (a few seconds on the way through), and the one whose positions the data is likeliest to lack (backlog
  `objectives-with-no-position-in-the-data-are-planned-as-done`: such an objective has no spot to share, and is planned at the giver).
- Areas to reach (explore): an area on the way costs nothing and is shared with any quest whose spots are there.

**How to test it.** A fixture with a quest A that has spots in two hubs and a quest B that has spots only in the farther one: today A is done in the near hub and B costs a
trip of its own (or is left unfinished); with the rule both are done in the far hub in one trip. One such fixture per kind of objective (kill, creature drop, container or
ground item, object, explore), a mutation check of the rule (held back when it should not be, not held back when it should), and the numbers on the three guides (quests
added, planner and simulated time change); on the Skyborne the route should do 92461 and 92462 together at the east spot if the totals improve.

**Risks.** A held-back objective makes a visit leave work behind, so the quest log holds the quest longer (the log limit binds sooner); the model prices kills per objective,
not per creature, so the saving is counted at the visit level only; and the rule changes the search, not only the written route, so the usual roughness applies (a beam
that is rough anyway can land on a worse route for a better rule: read the grains, "The search is rough").

