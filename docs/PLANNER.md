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
  and boss objectives and the skips of `tools/hardcore_rules.json`. Every quest left out on purpose is named in a `#skipquest` line with its
  reason, as the drafted chapters name theirs.
- **Data it does not trust** (found by an independent review of the first installed guide): the planner leaves out a quest that has no
  start position, no turn-in position (a class quest stays, its step carries a `.todo`), no objective and is accepted and handed in at one NPC
  (free experience; a quest another needs, a chain link and a class quest stay; `--instant-quests` keeps them all), an objective that exists
  only where the route does not go (another continent, a zone nobody quests in), a class that is not the character's (a quest with no mask whose
  giver has a same-named quest limited to another class, or whose giver's other quests all are), and every quest of a battleground zone
  (`skip_zones` in `tools/hardcore_rules.json`). An explore objective is an area to reach, with positions of its own. A class quest with no
  objective in the pack is given 5 minutes and a `.todo`. The setup says how many quests each rule left out.
- **Profitability**: a quest slower than grinding at the level it is done at is left out (`--threshold`, `--no-skip`), except class
  quests, the quests a kept quest needs, and quests the pack has no experience for.
- **Grinding** is an edge too: forced when nothing can be done until a level opens something, voluntary (one level) when nothing pays
  better. The simulator's own grinding rate is used.
- **Travel** is walking on one continent (distance by the map data, a detour factor); between continents it is the walk to the
  capital's boat or zeppelin, `--ferry` minutes, and the walk from the other capital. Reaching a continent or island with no
  gateway (another race's start island) is not allowed, unless the character begins there.
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
  `overdue_hubs` and the replay of a tidied route all go through `Planner.offered`), and a quest handed in at the NPC who gave it needs a free place too. 40 is the
  working value the user accepted for Forever (2026-10-21: "I believe the quest log limit has been bumped up from 25 to 40 for WoW Forever", then "accept a 40
  quest cap for wow forever"; Classic's is 25). VERIFY(beta): it has not been read from the client yet (the probe `SignpostDB.probe.questLogMax`, API notes "Open
  probes"); change the default only with that reading. The limit counts every quest a partial route holds, including the ones tidy takes out of the written route
  again, so it steers the search harder than it constrains the guide (below). The report gives the most quests held at once, by the planner and counted again on
  the written route's own steps.
- **No quest is left in the log**: a route that accepted something it never finished has it taken out and the same hubs are walked
  again (the grinds too), more than once if that leaves others unfinished.

## Reading the report

`ROUTE PLANNER` (who, which data, which assumptions, what was left out and why) - `THE SEARCH` (situations made and dropped, the
baseline greedy route against this one, and for a search of several grains of progress `grains`: each grain's best route as it would be
written, the work it took and how far apart they are) - `THE ROUTE AS A GRAPH` (zones with the time spent, the
travel between them, one row per leg) - `TIME AND EXPERIENCE` (where the time goes, the time at each level, and `grinding`: every grind
step with its amount and the share of the route it makes) - `THE QUESTS` (done, the most quests held at once, left out as slow, the
class quests with the level each is done at against the level it opens at) - `THE DECISIONS` (each change of
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
- **The planner and the simulator price travel differently.** The simulator charges a flat few minutes for a border that is not
  learned yet; the planner prices it by distance. The full simulation of a written route runs 10-20% below the planner's estimate
  (backlog: `price-travel-differently`).
- **Class quests are pushed, not scheduled**: a chain whose quests are far apart (the Cat Form chain's items) can still come several levels
  after it opens; the report lists the class quests more than 5 levels late and the level each was done at. A character that starts on an island
  (the Skyborne's) cannot reach the other continents' class quests before it leaves, however hard they are pushed.
- **The search is rough**: two settings that look alike (a width of 30 or 60, 4 or 8 parts to a level) can differ by hours on a guide with many class
  quests (the druids), and a wider beam is not always better. `thorough` runs several grains and keeps the best, and its report says how far apart the grains'
  best routes are (`grains`: trust the best route no more than that; a warning above 5%). Read the baseline line of the report too, which says how much faster the
  result is than the greedy route, and distrust a route that is not clearly faster. "Measurements" below has the numbers.
- **The quest log limit is a working value**: 40 is what the user accepted for Forever (Classic's is 25), and nothing read from the client confirms it yet
  (VERIFY(beta); the probe `SignpostDB.probe.questLogMax`). It counts what the search holds, which is more than the written route holds ("Measurements").
- **Data holes become `.todo` steps**: an objective with no position in the pack is worked where its quest starts, and the step
  says so; a border with no route yet gets a travel step the lint reports.
- **Group quests** in a normal route are tagged `.optional`, not yet shown as a line beside the step.
- **Walking inside a doing step is not priced**: the planner adds a few seconds for each place of a hub; once the objective areas are joined into one
  doing step the simulator charges only the walk between steps (the step keeps one position). A pick-up and hand-in step keeps the position of
  each NPC, and the simulator walks them in order.

## Measurements (2026-10-21)

What the quest log limit and the grains of progress were measured to do (data pack of 2026-10-20, the default beam unless said otherwise, planner totals
with the class-quest charges; each run is deterministic, so a number is reproduced by the command that names it).

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
