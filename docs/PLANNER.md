# The Route Planner

`tools/route_planner.py` plans a leveling route for a guide's character, level 1 to the cap (30 for Version 1), searches for the
fastest one under the simulator's assumptions, writes it as guide chapters and says in detail what it did. It is one tool: the report
is part of it. It changes a guide only when asked to (`--install`, below); otherwise a route is a candidate to read and compare (PLAN Phase 9).

```
python tools/route_planner.py                          the guides, and what the tool can do
python tools/route_planner.py troll                    plan the Troll Hunter with the default technique (beam)
python tools/route_planner.py tauren --preset all      every technique, with a comparison
python tools/route_planner.py skyborne --preset thorough
python tools/route_planner.py troll --cap 20 --friction 5 --steps 60 --decisions 20
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
| `thorough` | the beam once for each grain of progress (2, 4 and 8 parts to a level; 40 routes wide, 10 hubs from each; each grain on its own, none prunes another), the best finished routes of all of them, then the finalists walked hundreds of times with uncertain assumptions (Monte Carlo: pace, kills, drops, respawns) | minutes |
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
- **No quest is left in the log**: a route that accepted something it never finished has it taken out and the same hubs are walked
  again (the grinds too), more than once if that leaves others unfinished.

## Reading the report

`ROUTE PLANNER` (who, which data, which assumptions, what was left out and why) - `THE SEARCH` (situations made and dropped, the
baseline greedy route against this one, the progress of the best estimate) - `THE ROUTE AS A GRAPH` (zones with the time spent, the
travel between them, one row per leg) - `TIME AND EXPERIENCE` (where the time goes, the time at each level) - `THE QUESTS` (done,
left out as slow, the class quests with the level each is done at against the level it opens at) - `THE DECISIONS` (each change of
zone and the best route held in other zones at that step) - `CHECKED BY THE SAME SIMULATOR AND LINT` (the route written as guide
steps with the travel steps added, walked by `guide_sim` and `guide_lint`: availability errors, lint errors, `.todo` steps, and how
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
  quests (the druids), and a wider beam is not always better. `thorough` runs several and keeps the best; read the baseline line of the report, which
  says how much faster the result is than the greedy route, and distrust a route that is not clearly faster.
- **The quest log is not limited** (25 in Classic); the route may hold more at a moment than the game allows (backlog: `limit-the-quest-log`).
- **The escort and event times are assumptions** (`escort_seconds`, `event_seconds`): Classic's escorts take about 5 to 12 minutes with their
  pauses, none is measured for Forever. The flag comes from QuestieDB's Classic baseline, so an escort Forever added is not flagged, and what the
  escort does on the way (where it goes, what attacks it) is not in the data: the note says so.
- **Data holes become `.todo` steps**: an objective with no position in the pack is worked where its quest starts, and the step
  says so; a border with no route yet gets a travel step the lint reports.
- **Group quests** in a normal route are tagged `.optional`, not yet shown as a line beside the step.
- **Walking inside a doing step is not priced**: the planner adds a few seconds for each place of a hub; once the objective areas are joined into one
  doing step the simulator charges only the walk between steps (the step keeps one position). A pick-up and hand-in step keeps the position of
  each NPC, and the simulator walks them in order. This is part of the 2 to 3% by which the full simulation still runs under the planner's estimate.
