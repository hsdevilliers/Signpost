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
| `beam` (default) | keeps the 60 best partial routes at every step (8 hubs tried from each), drops a route when another reaches the same situation sooner | 20-30 s |
| `thorough` | a beam 300 wide, then the finalists walked hundreds of times with uncertain assumptions (Monte Carlo: pace, kills, drops, respawns) | minutes |
| `all` | every technique above and a comparison | the sum |

## What the planner models

- **A node is a situation**: where the character is, level and experience, the quests done and in the log (with their open
  objectives), the clock. **An edge is a visit**: go to a hub and do everything worthwhile there until nothing new turns up (turn
  in, accept, work the objectives of the quests in the log that are there). The cost of an edge is the simulator's time: walking,
  talking, killing and looting, waiting for respawns; experience comes from quest rewards and kills, with the level table.
- **Hubs** are the quest givers, enders and objective areas of a map grouped within about 150 yards (`--hub-radius`).
- **Where the character begins** is the first place the guide as it stands sends them to (`--start MAP,X,Y` overrides it).
- **Availability** is the game's rule (docs/AVAILABILITY.md): a quest is accepted only where the game would offer it (level,
  prerequisites, chains, exclusive quests, race, class, faction). Quests of a chain the data does not link come from the hints in
  `tools/drafts.json` (`--chain`). A normal route accepts quests up to 5 levels above the character and works on them up to 3; a
  HARDCORE route 1 and 1, leaves out the elite and boss objectives and the skips of `tools/hardcore_rules.json`.
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
  There is no deadline (user, 2026-10-20): a class quest still undone costs the route `--class-push` minutes (default 20) for every level past
  the one it opens at, up to `--class-grace` + 6 levels, so the route picks one up when it passes the giver and makes the trip for a far one
  (Moonglade) soon after it opens. The search always tries the nearest hub of a class quest that is past its level.
- **Steps are activity steps** (user, 2026-10-20; `signpost_tools/steps.py`, docs/GUIDE-FORMAT.md "Step kinds"): the route is written one
  place at a time and neighbouring steps of one kind within `--group-yards` (250) are joined: one pick-up and hand-in step per area (a hand-in
  and the next pick-up at one NPC are one step), one doing step for quests whose objectives are close to each other, no marker or position text
  for a doing step. A quest whose objectives all fall in one doing step is `.complete <quest>`, otherwise `.complete <quest>,<objective>`.
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

Installing is the step you take on purpose. The planner picks the route to install: of the routes that pass every check (it reaches the cap,
the game would offer every quest where the route accepts it, no lint error) the one it finds fastest; when `thorough` ran, its own candidate is
the one that was fastest in most of the runs with varied assumptions. Then `tools/route_install.py`: writes the chapters as
`Guides/Chapters/<guide>-NN-<zone>.lua` (header `PLANNED`, regenerated by the next install, not edited by hand), points the guide file at them
(levels, `#include` list, `#skipquest` lines), deletes the chapters the guide used before unless another guide includes them, keeps both TOCs
in step, marks the guide `planned` in `tools/drafts.json` (so `rebuild_drafts.py` leaves it alone) and runs StyLua. Read `git diff`, run
`tools/check.ps1` and commit. Nothing is published.

## What it cannot see (read these before trusting a number)

- **Every number is an assumption** (`tools/sim_params.json`): Classic's XP table, quest XP from QuestieDB's Classic seed (10% of
  the level when a quest has none), 8 kills and 6 items per objective, kill 12 s, loot 4 s. The route is the best one under them,
  not a prediction of a player's clock. Forever's own tuning is unknown (CLAUDE.md, "Forever is not Classic"): quests and class
  quests Forever added that the pack lacks are not routed.
- **The planner and the simulator price travel differently.** The simulator charges a flat few minutes for a border that is not
  learned yet; the planner prices it by distance. The full simulation of a written route runs 10-20% below the planner's estimate
  (backlog: `price-travel-differently`).
- **Class quests are pushed, not scheduled**: a chain whose quests are far apart (the Cat Form chain's items) can still come several levels
  after it opens; the report lists the class quests more than 5 levels late and the level each was done at.
- **The quest log is not limited** (25 in Classic); the route may hold more at a moment than the game allows (backlog: `limit-the-quest-log`).
- **Data holes become `.todo` steps**: an objective with no position in the pack is worked where its quest starts, and the step
  says so; a border with no route yet gets a travel step the lint reports.
- **Group quests** in a normal route are tagged `.optional`, not yet shown as a line beside the step.
- **Walking inside a step is not priced**: the planner adds a few seconds for each place of a hub; once the places are joined into one step
  the simulator charges only the walk between steps.
