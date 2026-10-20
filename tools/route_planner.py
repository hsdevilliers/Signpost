"""The Route Planner: plans a leveling route for a guide's character on a state graph, then says in detail what it did.

    python tools/route_planner.py                           the guides and what the tool can do
    python tools/route_planner.py troll                     plan the Troll Hunter with the default technique (beam)
    python tools/route_planner.py troll --preset all        run every technique and compare them
    python tools/route_planner.py druid --preset thorough   a wide search, then the finalists under uncertain assumptions
    python tools/route_planner.py tauren --cap 20 --friction 5 --steps 60

The guide is named by any words of its id, name, race or class. The tool takes the guide's character (faction, race, class),
whether it is a HARDCORE or a normal guide, and its class quests (which must be done or accounted for), and plans a route from
level 1 to the cap through every quest the character may take, anywhere. A node of the planner's graph is a situation (place,
level and experience, quests done and in the log, the clock), an edge is "go to a hub and do everything worthwhile there"; the
cost of an edge is the simulator's time, and a quest is accepted only where the game would offer it (docs/PLANNER.md).

The techniques (--preset):
  greedy     nearest thing first, finish a zone, move on (the way the guides are drafted); seconds
  lookahead  greedy, but each choice is tried by playing the rest out greedily and the best is kept; seconds
  beam       keeps the best partial routes at every step, drops one when another is both faster and further along; the default
  thorough   a wide beam, then the finalists walked hundreds of times with uncertain assumptions (Monte Carlo)
  all        every technique above, with a comparison

The report says what the search did (how many situations, how many dropped and why), the route as a graph of zones, the time
and experience by level, the quests done and left out, the decisions at each change of zone with the alternatives, and the
check of the finished route by the same simulator and lint the shipped guides go through. It is written to plans/<guide>/.
Every number is an assumption (tools/sim_params.json): this is the best route under those assumptions, not a prediction.
"""

from __future__ import annotations

import argparse
import json
import shutil
import sys
import tempfile
import time
from argparse import Namespace
from dataclasses import dataclass, field
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import guide_draft  # noqa: E402
import guide_lint  # noqa: E402
import guide_sim  # noqa: E402
import guide_travel  # noqa: E402
import planner as engine  # noqa: E402
import rebuild_drafts  # noqa: E402
from signpost_tools import availability, guidefile  # noqa: E402

REPO_ROOT = Path(__file__).resolve().parent.parent
PRESETS = ("greedy", "lookahead", "beam", "thorough")
WIDTH = 112
PRESET_SETTINGS = {  # what each technique changes in the planner's settings
    "greedy": {},
    "lookahead": {"branch": 8, "horizon": 12},
    "beam": {"branch": 8, "width": 60},
    "thorough": {"branch": 10, "width": 300, "alternatives": 5},
}


# small formatting helpers ----------------------------------------------------------------------------------------------


def hms(seconds: float) -> str:
    minutes = int(round(seconds / 60))
    return f"{minutes // 60}h{minutes % 60:02d}"


def mins(seconds: float) -> str:
    return f"{seconds / 60:.0f}m"


def bar(fraction: float, width: int = 28) -> str:
    n = max(0, min(width, int(round(fraction * width))))
    return "#" * n + "." * (width - n)


def share(part: float, whole: float) -> str:
    return f"{part / whole * 100:4.1f}%" if whole else "  -  "


def wrap(text: str, indent: str = "", width: int = WIDTH) -> list[str]:
    words, lines, line = text.split(), [], indent
    for word in words:
        if len(line) + len(word) + 1 > width and line.strip():
            lines.append(line.rstrip())
            line = indent
        line += word + " "
    if line.strip():
        lines.append(line.rstrip())
    return lines


class Out:
    """Prints as it goes and keeps what it printed, for the report file."""

    def __init__(self, quiet: bool = False) -> None:
        self.lines: list[str] = []
        self.quiet = quiet

    def __call__(self, text: str = "", always: bool = False) -> None:
        for line in str(text).split("\n"):
            self.lines.append(line)
            if always or not self.quiet:
                print(line)

    def section(self, title: str) -> None:
        self("")
        self(f"== {title} " + "=" * max(4, WIDTH - len(title) - 4))


# the job: who is planned for and with what ------------------------------------------------------------------------------


@dataclass
class Job:
    root: Path
    project: guidefile.Project
    pack: guide_travel.Pack
    pack_dir: Path
    guide: guidefile.Guide
    hardcore: bool
    character: availability.Character
    race: str
    cls: str
    world: guide_travel.World
    settings: engine.Settings
    params: dict
    mandatory: tuple
    exclude: dict
    notes: dict
    class_chains: list = field(default_factory=list)


def manifest_hardcore(root: Path, guide_id: str) -> bool | None:
    try:
        manifest = json.loads((root / "tools" / "drafts.json").read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None
    for entry in manifest.get("guides", []):
        if entry.get("guide") == guide_id and isinstance(entry.get("hardcore"), bool):
            return entry["hardcore"]
    return None


def kind_of(root: Path, guide: guidefile.Guide) -> str:
    hardcore = manifest_hardcore(root, guide.id)
    if hardcore is None:
        hardcore = "HARDCORE" in guide.name.upper()
    return "HARDCORE" if hardcore else "normal"


def find_guides(project: guidefile.Project, words: list[str]) -> list[guidefile.Guide]:
    def text(guide: guidefile.Guide) -> str:
        return " ".join([guide.id, guide.name, guide.faction, *guide.races, *guide.classes]).lower()

    return [g for _, g in sorted(project.guides.items()) if all(w.lower() in text(g) for w in words)]


def list_guides(project: guidefile.Project, root: Path) -> list[str]:
    out = ["The guides (name one with any words of its id, name, race or class):", ""]
    for gid, g in sorted(project.guides.items()):
        out.append(f"  {g.name:<34} {kind_of(root, g):<9} {g.faction} {'/'.join(g.races)} {'/'.join(g.classes)}  ({gid})")
    out += [
        "",
        "Run one:   python tools/route_planner.py troll",
        "Compare:   python tools/route_planner.py troll --preset all",
        "Techniques: " + ", ".join(PRESETS) + ", all   (see --help for the settings)",
    ]
    return out


def build_job(options, project: guidefile.Project, guide: guidefile.Guide, out: Out) -> Job | None:
    pack_dir = options.pack or guide_travel.default_pack_dir(options.root)
    pack = guide_travel.load_pack(pack_dir)
    if not pack.present:
        out("the Route Planner needs the data pack: " + pack.describe(), always=True)
        return None
    kind = kind_of(options.root, guide)
    hardcore = kind == "HARDCORE" if options.mode == "auto" else options.mode == "hardcore"
    race, cls = guide.races[0], guide.classes[0]
    character = availability.Character(guide.faction, availability.race_bit(race, guide.faction), availability.class_bit(cls))
    params = guide_sim.load_params(overrides=options.param)
    exclude: dict = {}
    notes: dict = {}
    if hardcore:
        try:
            rules = json.loads((options.root / "tools" / "hardcore_rules.json").read_text(encoding="utf-8")).get("rules", [])
        except (OSError, ValueError):
            rules = []
        for rule in rules:
            if isinstance(rule, dict) and isinstance(rule.get("id"), int):
                if rule.get("action") == "skip":
                    exclude[rule["id"]] = str(rule.get("reason") or "HARDCORE: not routed")
                elif rule.get("action") == "note" and rule.get("text"):
                    notes[rule["id"]] = str(rule["text"])
    for qid in options.exclude:
        exclude[qid] = "excluded on the command line"
    chains = guide_lint.class_chains(project, pack, cls, race)
    mandatory = tuple(q for c in chains if not c.pending and (c.level or 0) <= options.cap for q in c.quests)
    settings = engine.Settings(
        cap=options.cap,
        hardcore=hardcore,
        hub_radius=options.hub_radius,
        zone_friction=options.friction * 60,
        skip_unprofitable=not options.no_skip,
        profit_threshold=options.threshold,
        ferry_seconds=options.ferry * 60,
        gateways=(1454, 1458) if guide.faction == "Horde" else (1453, 1455, 1457),
    )
    world = guide_travel.World(pack, project.borders, guide.faction)
    return Job(
        options.root, project, pack, pack_dir, guide, hardcore, character, race, cls, world, settings, params, mandatory, exclude, notes, chains
    )


# plan -> guide text -> the shipped guides' checks ------------------------------------------------------------------------


@dataclass
class Evaluation:
    root: Path
    chapters: list
    sim: guide_sim.Result
    route: object
    travel: object
    lint_errors: list
    lint_warnings: int
    todos: int
    travel_steps: int
    steps: int


def materialize(job: Job, pl: engine.Planner, plan: engine.Plan, label: str, root: Path | None = None) -> tuple[Path, list]:
    """Write the route as chapter files and a guide file in a project folder, with the travel steps the zone changes need."""
    root = root or Path(tempfile.mkdtemp(prefix="signpost-plan-"))
    for sub in ("Classes", "Professions", "Guides/Travel"):
        source = job.root / sub
        if source.exists() and not (root / sub).exists():
            shutil.copytree(source, root / sub)
    chapters = pl.emit(plan, job.cls)
    entries = []
    for n, chapter in enumerate(chapters, 1):
        zone_name = pl.world.geo.name(chapter.zone) if chapter.zone is not None else "Grinding"
        cid = f"plan-{label}-{n:02d}-{engine.slug(zone_name)}"
        text = chapter.text(zone_name)
        header = [f"PLAN: the {label} route for {job.guide.name}, planned by tools/route_planner.py (docs/PLANNER.md)."]
        path = root / "Guides" / "Chapters" / f"{cid}.lua"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(guide_draft.lua_file(cid, text, header), encoding="utf-8", newline="\n")
        entries.append((cid, zone_name, chapter))
    skips = pl.skipquests(plan)
    lines = [f"#guide {job.guide.name}"]
    lines += [f"#skipquest {qid} >> {guide_draft._clean(reason)}" for qid, reason in sorted(skips.items())]
    lines += [f"#include {cid}" for cid, _, _ in entries]
    guide_lua = (
        "local ADDON_NAME, ns = ...\n\nns.Guides:Register({\n"
        f'\tid = "{job.guide.id}",\n\tname = "{job.guide.name}",\n\tfaction = "{job.guide.faction}",\n'
        f"\traces = {{ {', '.join(chr(34) + r + chr(34) for r in job.guide.races)} }},\n"
        f"\tclasses = {{ {', '.join(chr(34) + c + chr(34) for c in job.guide.classes)} }},\n"
        f"\tlevels = {{ 1, {job.settings.cap} }},\n\ttext = [[\n" + "\n".join(lines) + "\n]],\n})\n"
    )
    (root / "Guides" / "Plan.lua").write_text(guide_lua, encoding="utf-8", newline="\n")
    return root, entries


def evaluate(job: Job, pl: engine.Planner, plan: engine.Plan, label: str) -> Evaluation:
    root, entries = materialize(job, pl, plan, label)
    inserted = 0
    for _ in range(rebuild_drafts.TRAVEL_PASSES):
        found = rebuild_drafts.proposals(job.guide.id, job.pack_dir, root)
        if not found:
            break
        inserted += rebuild_drafts.insert_proposals(found, root)
    project = guidefile.load_project(root)
    guide = project.guides[job.guide.id]
    options = Namespace(faction=None, race=None, cls=None, profession=[], no_tracks=True)
    route = guide_travel.guide_routes(project, guide, options, lambda faction: job.world)[0]
    skill_lines = {key: module.skill_line for key, module in project.professions.items() if module.skill_line}
    rules = availability.Rules(job.pack.table("quests"), guide_sim.character_of(route, skill_lines))
    model = guide_sim.make_model(job.pack, job.params)
    travel = guide_travel.simulate(route, job.world)
    sim = guide_sim.run(route, job.world, model, rules=rules, travel=travel)
    report, _, _ = guide_lint.lint(root, job.pack_dir, [job.guide.id])
    errors = [line for line in report.render(True) if "error" in line]
    steps = sum(len(rs.step.directives) > 0 for rs in route.steps)
    return Evaluation(
        root, entries, sim, route, travel, errors, report.count("warning"), len(report.todos), inserted, len(route.steps)
    )


# a technique's run --------------------------------------------------------------------------------------------------------


@dataclass
class Outcome:
    preset: str
    plan: engine.Plan
    wall: float
    evaluation: Evaluation | None = None
    monte: dict = field(default_factory=dict)


def planner_for(job: Job, out: Out, overrides: dict | None = None, quiet: bool = False) -> engine.Planner:
    import dataclasses

    settings = dataclasses.replace(job.settings, **(overrides or {}))
    pl = engine.Planner.build(
        job.pack,
        job.world,
        job.character,
        settings,
        job.params,
        exclude=job.exclude,
        notes=job.notes,
        mandatory=job.mandatory,
        log=(lambda text: None) if quiet else (lambda text: out("  " + text)),
    )
    return pl


def run_preset(job: Job, preset: str, options, out: Out, base: engine.Planner | None = None) -> tuple[engine.Planner, Outcome]:
    overrides = dict(PRESET_SETTINGS[preset])
    for name in ("width", "branch", "horizon"):
        if getattr(options, name) is not None:
            overrides[name] = getattr(options, name)
    pl = planner_for(job, out, overrides, quiet=base is not None)
    start = engine.start_hub_for(pl)
    if start is None:
        raise SystemExit("no quest to start from")
    started = time.perf_counter()
    plan = pl.plan(preset, start, progress=None if options.quiet else lambda text: out(text))
    return pl, Outcome(preset, plan, time.perf_counter() - started)


# the report -------------------------------------------------------------------------------------------------------------


def legs_of(pl: engine.Planner, plan: engine.Plan) -> list[dict]:
    """The route as legs: consecutive visits in one zone."""
    legs: list[dict] = []
    clock, level = 0.0, 1
    for v in plan.visits:
        zone = pl.hubs[v.hub].zone if v.hub is not None else (legs[-1]["zone"] if legs else None)
        if not legs or (v.hub is not None and zone != legs[-1]["zone"]):
            legs.append(
                dict(zone=zone, start=clock, level_in=level, level_out=level, seconds=0.0, travel=0.0, xp=0.0, visits=0, hubs=[],
                     quests=0, accepts=0, interact=0.0, objective=0.0, wait=0.0, grind=0.0, arrival=v.travel_seconds)
            )
        leg = legs[-1]
        leg["seconds"] += v.seconds
        leg["travel"] += v.travel_seconds
        leg["xp"] += v.xp
        leg["visits"] += 1
        leg["interact"] += v.interact_seconds
        leg["objective"] += v.objective_seconds
        leg["wait"] += v.wait_seconds
        leg["grind"] += v.grind_seconds
        leg["quests"] += sum(1 for a in v.actions if a.kind == "turnin")
        leg["accepts"] += sum(1 for a in v.actions if a.kind == "accept")
        if v.hub is not None and v.hub not in leg["hubs"]:
            leg["hubs"].append(v.hub)
        clock += v.seconds
        level = v.level
        leg["level_out"] = level
    return legs


def level_times(plan: engine.Plan) -> dict[int, float]:
    reached: dict[int, float] = {}
    clock, level = 0.0, 1
    for v in plan.visits:
        clock += v.seconds
        while level < v.level:
            level += 1
            reached[level] = clock
    return reached


def report_setup(job: Job, out: Out, pl: engine.Planner, options) -> None:
    g, s = job.guide, pl.s
    kind = "HARDCORE" if s.hardcore else "normal"
    out.section(f"ROUTE PLANNER: {g.name} [{kind} route], {g.faction} {job.race} {job.cls}, level 1 to {s.cap}")
    pack = job.pack
    out(f"data pack     {job.pack_dir} ({pack.meta.get('generated', '?')}; {len(pack.table('quests'))} quests, "
        f"{len(pack.table('npcs'))} NPCs)")
    xp_seed = len(guide_sim.read_quest_xp(job.pack_dir))
    p = job.params
    out(f"time model    Classic XP table; quest XP from QuestieDB's Classic seed ({xp_seed} quests), else {p['quest_xp_fraction_of_level']:.0%} "
        f"of the level; {p['default_kills']} kills and {p['default_items']} items per objective; kill {p['kill_seconds']} s, loot {p['loot_seconds']} s, "
        f"talk {p['interact_seconds']} s; respawn {p['respawn_seconds']['normal']} s (normal)")
    out("              every one of these is an assumption (tools/sim_params.json): the route is the best one under them")
    total = len(pack.table("quests"))
    routable = sum(len(v) for v in pl.dropped.values())
    out(f"quests        {total} in the pack; {len(pl.quests)} can be routed for this character; "
        f"{sum(1 for q in pl.quests.values() if q.kept)} kept for the planner")
    reasons = sorted(pl.dropped.items(), key=lambda kv: -len(kv[1]))
    out("              left out: " + "; ".join(f"{len(ids)} {reason}" for reason, ids in reasons[:7]))
    out(f"hubs          {len(pl.hubs)} of about {s.hub_radius:.0f} yards; {len(pl.gateways)} continent gateways; the route starts at "
        f"{pl.hubs[engine.start_hub_for(pl)].label}")
    rules = [
        "a quest is accepted only where the game would offer it (level, prerequisites, chains, exclusive quests)",
        f"a change of zone costs {s.zone_friction / 60:.0f} min on top of the travel; a trip between continents is the walk to "
        f"the capital's boat or zeppelin + {s.ferry_seconds / 60:.0f} min + the walk from the other capital",
        f"quests slower than grinding are left out (threshold {s.profit_threshold:g}x) unless they are class quests or needed by a kept quest"
        if s.skip_unprofitable
        else "no quest is left out for being slow",
        (f"HARDCORE: no elite or boss objectives, no quest more than {s.hardcore_over} level above the character, "
         f"{len(job.exclude)} sourced skips (tools/hardcore_rules.json)")
        if s.hardcore
        else f"a normal route: quests up to {pl.accept_over} levels above you are accepted and worked on up to {pl.work_over}; group quests are tagged optional",
        f"{len(job.mandatory)} class quests are mandatory: each is done or accounted for with a #skipquest reason",
    ]
    for rule in rules:
        out("rules         " + rule if rule is rules[0] else "              " + rule)


def report_search(out: Out, pl: engine.Planner, outcome: Outcome) -> None:
    plan = outcome.plan
    p = plan.stats
    s = pl.s
    out.section(f"THE SEARCH: {outcome.preset}")
    how = {
        "greedy": "nearest hub with something to do, a zone finished before the next; one path, no alternatives considered",
        "lookahead": f"at every step the {s.branch} best hubs are each tried by playing {s.horizon} visits on greedily; the best is kept",
        "beam": f"at every step the {s.width} best partial routes are kept ({s.branch} hubs tried from each); a route is dropped "
                f"when another reaches the same situation sooner",
        "thorough": f"as beam but {s.width} routes wide and {s.branch} hubs from each; the finalists are then walked with uncertain assumptions",
    }[outcome.preset]
    out(wrap(f"technique     {how}", "              ")[0] if False else "technique     " + how)
    out(f"work          {outcome.wall:.1f} s; {p.get('nodes', 0):,} situations made" + (f"; {p['pruned']:,} dropped (worse than another route to the same situation, "
        f"beyond the beam, or hopeless against the best finished route)" if "pruned" in p else ""))
    if "baseline_seconds" in p:
        base = p["baseline_seconds"]
        better = (base - (plan.seconds + plan.penalty)) / base * 100 if base else 0
        out(f"baseline      the greedy route takes {hms(base)} (with the zone-change cost); this one {hms(plan.seconds + plan.penalty)}: "
            f"{better:.1f}% {'faster' if better >= 0 else 'slower'}")
    if p.get("finals"):
        out(f"finished      {p['finals']:,} complete routes reached the cap during the search; the best {len(plan.alternatives) + 1} with different "
            f"orders of zones are kept to compare")
    if p.get("removed"):
        names = ", ".join(pl.quests[q].name for q in p["removed"][:6] if q in pl.quests)
        out(f"tidied        {len(p['removed'])} quests the search had accepted but never finished were taken out of the route (a guide may not leave them in the log): {names}"
            + (" ..." if len(p["removed"]) > 6 else ""))
    if plan.trace:
        out("progress      best estimated total time as the search deepened (visits made | routes kept | estimate):")
        picks = plan.trace[:: max(1, len(plan.trace) // 8)]
        out("              " + "   ".join(f"{d}: {n}, {hms(e)}" for d, n, e in picks))
    out(f"result        {'reaches level ' + str(s.cap) if plan.complete else 'does NOT complete'}: {hms(plan.seconds)} of play"
        f" (+ {hms(plan.penalty)} of zone-change cost the planner charged), {len(plan.visits)} hub visits")


def report_route(out: Out, pl: engine.Planner, plan: engine.Plan) -> None:
    legs = legs_of(pl, plan)
    out.section("THE ROUTE AS A GRAPH (nodes: zones with the time spent; edges: the travel between them)")
    parts = []
    for i, leg in enumerate(legs):
        name = pl.world.geo.name(leg["zone"]) if leg["zone"] is not None else "grind"
        parts.append(f"[{name} {hms(leg['seconds'] - leg['arrival'] if i else leg['seconds'])}]")
        if i + 1 < len(legs):
            parts.append(f"-{mins(legs[i + 1]['arrival'])}->")
    for line in wrap(" ".join(parts), "  "):
        out(line)
    zones = {leg["zone"] for leg in legs}
    continents = {pl.world.geo.instance(pl.hubs[h].map) for leg in legs for h in leg["hubs"]}
    out(f"  {len(legs)} legs in {len(zones)} zones on {len(continents)} continent(s); "
        f"{sum(1 for leg in legs if leg['arrival'] > 600)} legs began with a trip over 10 minutes")
    out("")
    out(f"  {'#':>3}  {'zone':<24} {'levels':>7} {'arrives':>8} {'time':>6} {'travel':>7} {'quests':>6} {'XP':>8}  hubs visited")
    for i, leg in enumerate(legs, 1):
        name = pl.world.geo.name(leg["zone"]) if leg["zone"] is not None else "(grinding)"
        hubs = ", ".join(pl.hubs[h].label.split(": ", 1)[-1] for h in leg["hubs"][:4]) + (" ..." if len(leg["hubs"]) > 4 else "")
        out(f"  {i:>3}  {name:<24} {leg['level_in']:>3}-{leg['level_out']:<3} {hms(leg['start']):>8} {hms(leg['seconds']):>6} "
            f"{mins(leg['travel']):>7} {leg['quests']:>6} {leg['xp']:>8.0f}  {hubs}")


def report_time(out: Out, pl: engine.Planner, plan: engine.Plan) -> None:
    out.section("TIME AND EXPERIENCE")
    reached = level_times(plan)
    total = sum(v.seconds for v in plan.visits)
    kinds = [
        ("travelling", sum(v.travel_seconds for v in plan.visits)),
        ("talking to NPCs", sum(v.interact_seconds for v in plan.visits)),
        ("kills, loot, collecting", sum(v.objective_seconds for v in plan.visits)),
        ("waiting for respawns", sum(v.wait_seconds for v in plan.visits)),
        ("grinding for a level", sum(v.grind_seconds for v in plan.visits)),
    ]
    out(f"where the {hms(total)} goes:")
    for name, seconds in kinds:
        out(f"  {name:<26} {hms(seconds):>7} {share(seconds, total)}  {bar(seconds / total if total else 0)}")
    out("")
    out(f"  {'level':>5} {'reached':>8} {'in level':>9}   time in the level")
    previous = 0.0
    longest = max([reached[l] - (reached.get(l - 1, 0.0)) for l in reached] or [1.0])
    for level in sorted(reached):
        spent = reached[level] - previous
        previous = reached[level]
        out(f"  {level:>5} {hms(reached[level]):>8} {mins(spent):>9}   {bar(spent / longest, 30)}")
    xp_total = sum(pl.model.to_next(n) for n in range(1, plan.final.level))
    quest_xp = sum(v.xp for v in plan.visits if v.hub is not None)
    out(f"  experience: {xp_total:,.0f} to reach level {plan.final.level}; {quest_xp:,.0f} of it from quests and kills, "
        f"{plan.final.ground:,.0f} from grinding ({share(plan.final.ground, xp_total).strip()})")


def report_quests(out: Out, pl: engine.Planner, job: Job, plan: engine.Plan) -> None:
    out.section("THE QUESTS")
    done = plan.final.done
    optional = [q for q in done if pl.quests[q].optional]
    out(f"done          {len(done)} quests turned in" + (f", {len(optional)} of them group quests tagged optional" if optional else ""))
    slow = pl.dropped.get("slower than grinding", [])
    out(f"left out      {len(slow)} quests were slower than grinding; the slowest, by experience per minute against grinding at the level it is done at:")
    scored = sorted((pl.quests[q] for q in slow), key=lambda q: q.rate / max(pl.model.grind_xp_per_second(max(q.req, q.level - 1, 1)), 1e-9))
    for q in scored[:8]:
        grind = pl.model.grind_xp_per_second(min(pl.s.cap, max(q.req, q.level - 1, 1)))
        out(f"              {q.id:>6} {q.name[:34]:<34} L{q.level:<3} {q.rate * 60:6.0f} XP/min vs grinding {grind * 60:5.0f}")
    other = {k: len(v) for k, v in pl.dropped.items() if k != "slower than grinding"}
    out("not routable  " + "; ".join(f"{n} {k}" for k, n in sorted(other.items(), key=lambda kv: -kv[1])[:8]))
    if job.mandatory:
        out(f"class quests  {len(job.mandatory)} (mandatory): "
            + ", ".join(f"{q} {'done' if q in done else 'skipped'}" for q in job.mandatory))
        for qid, reason in pl.skipquests(plan).items():
            if qid in job.mandatory:
                out(f"              #skipquest {qid} ({pl.quests[qid].name if qid in pl.quests else '?'}): {reason}")
    if pl.s.hardcore:
        highest = max((pl.quests[q].level - 0 for q in done), default=0)
        out(f"HARDCORE      no elite or boss objective in the pool (those are left out before the search); the highest quest level routed is {highest}")


def explain_decisions(out: Out, pl: engine.Planner, plan: engine.Plan, limit: int) -> None:
    out.section("THE DECISIONS (each change of zone on the route, and the best route held in other zones at that step)")
    decisions = plan.decisions
    if not decisions:
        out("  " + ("the greedy technique makes no choices between alternatives" if plan.preset == "greedy" else "the route never changes zone"))
        return
    name = lambda zone: pl.world.geo.name(zone) if zone is not None else "?"
    step = max(1, len(decisions) // limit) if limit else 1
    shown = decisions[::step][:limit]
    out("  the estimate is the search's own: the time already spent, the zone-change cost and the time still to go at the pace of a greedy walk")
    for d in shown:
        out(f"  at {hms(d['clock'])}, level {d['level']}: left {name(d['from_zone'])} for {name(d['to_zone'])} "
            f"(travel {mins(d['travel'])}); estimated total {hms(d['chosen'])}")
        for score, zone, level, clock in d["alternatives"]:
            diff = score - d["chosen"]
            out(f"        instead {name(zone):<24} held at level {level}, {hms(clock)}: estimated total {hms(score)} "
                f"({'+' if diff >= 0 else '-'}{abs(diff) / 60:.0f} min)")
        if not d["alternatives"]:
            out("        no route in another zone was still held at that step")
    if len(shown) < len(decisions):
        out(f"  ... {len(decisions) - len(shown)} more changes of zone not shown (--decisions N)")


def report_validation(out: Out, pl: engine.Planner, plan: engine.Plan, ev: Evaluation) -> None:
    out.section("CHECKED BY THE SAME SIMULATOR AND LINT AS THE SHIPPED GUIDES")
    sim = ev.sim
    out(f"chapters      {len(ev.chapters)} written as guide steps: {ev.steps} steps, {ev.travel_steps} travel steps added for zone changes, {ev.todos} .todo steps")
    errors = sum(1 for v in sim.violations if v.reason.severity == "error")
    warnings = len(sim.violations) - errors
    out(f"availability  {errors} error(s), {warnings} warning(s): the game would offer every quest where the route accepts it"
        if not errors else f"availability  {errors} ERROR(S): quests the game would not offer where the route accepts them")
    for v in sim.violations[:6]:
        out(f'              step {v.step.id} quest {v.quest} "{v.name}": {v.reason.text}')
    out(f"lint          {len(ev.lint_errors)} error(s), {ev.lint_warnings} warning(s)")
    for line in ev.lint_errors[:8]:
        out("              " + line[:WIDTH - 14])
    estimate, full = plan.seconds, sim.seconds
    out(f"fidelity      the planner estimated {hms(estimate)}; the full simulation of the written route says {hms(full)} "
        f"({(full - estimate) / estimate * 100:+.1f}%). The simulator cannot price a change of zone whose border is not learned yet "
        f"(it charges a flat few minutes); the planner prices it by distance, so it is the more cautious of the two")
    out(f"              it reaches level {sim.level}; {len(sim.stalls)} level gates stall it for {hms(sim.stall)}; travel {share(sim.travel, sim.seconds).strip()} of the time")


def report_monte(out: Out, outcomes: list[Outcome]) -> None:
    out.section("UNDER UNCERTAIN ASSUMPTIONS (Monte Carlo: the player's pace, kills needed, drops and respawns all vary)")
    out("each candidate route is walked many times; all candidates meet the same luck in run i. Columns: time to level 10 / 20 / cap, "
        "10th - 50th - 90th percentile")
    for o in outcomes:
        m = o.monte
        if not m:
            continue
        cells = []
        for level in m["levels"]:
            cells.append(f"L{level}: {hms(m['p10'][level])} - {hms(m['p50'][level])} - {hms(m['p90'][level])}")
        out(f"  {o.preset:<14} " + "   ".join(cells) + f"   fastest in {m['wins']:.0%} of runs")
    best = max((o for o in outcomes if o.monte), key=lambda o: o.monte["wins"], default=None)
    if best is not None:
        out(f"  most often the fastest: {best.preset} ({best.monte['wins']:.0%} of the runs)")


def monte_carlo(job: Job, outcomes: list[Outcome], runs: int, seed: int) -> None:
    quests, npcs, items = job.pack.table("quests"), job.pack.table("npcs"), job.pack.table("items")
    xp = guide_sim.read_quest_xp(job.pack_dir)
    per_outcome = []
    for o in outcomes:
        ev = o.evaluation
        per_outcome.append(guide_sim.monte_carlo(ev.route, job.world, quests, npcs, items, xp, job.params, runs, seed, travel=ev.travel))
    levels = sorted({l for l in (10, 20, job.settings.cap) if l <= job.settings.cap})
    wins = [0] * len(outcomes)
    for i in range(runs):
        times = [res[i].seconds if res[i].level >= job.settings.cap else float("inf") for res in per_outcome]
        wins[times.index(min(times))] += 1
    for o, results, w in zip(outcomes, per_outcome, wins):
        def at(level):
            return [r.levels[level][0] for r in results if level in r.levels]

        o.monte = dict(
            levels=levels,
            p10={l: guide_sim.percentile(at(l), 10) for l in levels},
            p50={l: guide_sim.percentile(at(l), 50) for l in levels},
            p90={l: guide_sim.percentile(at(l), 90) for l in levels},
            wins=w / runs,
            runs=runs,
        )


def report_compare(out: Out, pls: dict, outcomes: list[Outcome]) -> None:
    out.section("COMPARISON OF THE TECHNIQUES")
    base = next((o for o in outcomes if o.preset == "greedy"), outcomes[0])
    base_total = base.plan.seconds + base.plan.penalty
    out(f"  {'technique':<11} {'work':>8} {'situations':>11} {'play time':>9} {'+ zone cost':>11} {'vs greedy':>9} {'legs':>5} {'visits':>6} {'quests':>6}  complete")
    for o in outcomes:
        pl = pls[o.preset]
        legs = legs_of(pl, o.plan)
        total = o.plan.seconds + o.plan.penalty
        out(f"  {o.preset:<11} {o.wall:>7.1f}s {o.plan.stats.get('nodes', 0):>11,} {hms(o.plan.seconds):>9} {hms(total):>11} "
            f"{(total - base_total) / base_total * 100:>+8.1f}% {len(legs):>5} {len(o.plan.visits):>6} {len(o.plan.final.done):>6}  {'yes' if o.plan.complete else 'NO'}")


def report_steps(out: Out, ev: Evaluation, limit: int) -> None:
    out.section(f"THE FIRST {limit if limit else 'ALL'} STEPS OF THE ROUTE (as the simulator walks them)")
    count = 0
    for entry in ev.sim.log:
        if limit and count >= limit:
            out(f"  ... {len(ev.sim.log) - count} more steps (--steps N, or --steps 0 for all)")
            break
        count += 1
        header = f"  {entry.id:<26} {hms(entry.clock):>6} L{entry.level:<2} {mins(entry.seconds):>5}"
        events = entry.events or ["(nothing to do)"]
        out(header + "  " + events[0])
        for event in events[1:]:
            out(" " * len(header) + "  " + event)


def write_outputs(job: Job, outcome: Outcome, pl: engine.Planner, out_dir: Path, out: Out) -> None:
    ev = outcome.evaluation
    target = out_dir / outcome.preset
    if target.exists():
        shutil.rmtree(target)
    (target / "Guides" / "Chapters").mkdir(parents=True, exist_ok=True)
    for cid, _, _ in ev.chapters:
        shutil.copy(ev.root / "Guides" / "Chapters" / f"{cid}.lua", target / "Guides" / "Chapters")
    shutil.copy(ev.root / "Guides" / "Plan.lua", target / "Guides")
    legs = legs_of(pl, outcome.plan)
    data = dict(
        guide=job.guide.id,
        preset=outcome.preset,
        hardcore=job.settings.hardcore,
        cap=job.settings.cap,
        seconds=outcome.plan.seconds,
        penalty=outcome.plan.penalty,
        complete=outcome.plan.complete,
        levels={str(l): t for l, t in level_times(outcome.plan).items()},
        legs=[dict(zone=pl.world.geo.name(leg["zone"]) if leg["zone"] is not None else None, seconds=leg["seconds"], levels=[leg["level_in"], leg["level_out"]],
                   hubs=[pl.hubs[h].label for h in leg["hubs"]]) for leg in legs],
        quests_done=sorted(outcome.plan.final.done),
        simulated_seconds=ev.sim.seconds,
        lint_errors=ev.lint_errors,
    )
    (target / "plan.json").write_text(json.dumps(data, indent=2), encoding="utf-8")
    (target / "report.txt").write_text("\n".join(out.lines) + "\n", encoding="utf-8")


# the command line ------------------------------------------------------------------------------------------------------


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("guide", nargs="*", help="words of the guide's id, name, race or class (none: list the guides)")
    parser.add_argument("--preset", default="beam", choices=[*PRESETS, "all"], help="the technique (default beam)")
    parser.add_argument("--cap", type=int, default=30, help="the level the route ends at (default 30, Version 1)")
    parser.add_argument("--mode", default="auto", choices=["auto", "hardcore", "normal"], help="plan as HARDCORE or normal (default: the guide's)")
    parser.add_argument("--friction", type=float, default=3.0, help="minutes a change of zone costs the planner besides the travel (default 3)")
    parser.add_argument("--ferry", type=float, default=7.0, help="minutes for the boat or zeppelin between continents (default 7)")
    parser.add_argument("--hub-radius", type=float, default=150.0, help="yards a hub spans (default 150)")
    parser.add_argument("--threshold", type=float, default=1.0, help="times the grinding rate a quest must give to be kept (default 1)")
    parser.add_argument("--no-skip", action="store_true", help="do not leave out quests for being slower than grinding")
    parser.add_argument("--width", type=int, help="routes the beam keeps (default by technique)")
    parser.add_argument("--branch", type=int, help="hubs tried from each situation (default by technique)")
    parser.add_argument("--horizon", type=int, help="visits a lookahead plays out (default 12)")
    parser.add_argument("--param", action="append", default=[], help="a simulator assumption: name=value or name.part=value")
    parser.add_argument("--exclude", type=int, action="append", default=[], metavar="QUEST", help="never route this quest")
    parser.add_argument("--runs", type=int, default=300, help="Monte Carlo runs for the thorough technique (default 300)")
    parser.add_argument("--seed", type=int, default=1)
    parser.add_argument("--decisions", type=int, default=8, help="changes of zone to explain with alternatives (0: none)")
    parser.add_argument("--steps", type=int, default=25, help="steps of the route to show (0: all)")
    parser.add_argument("--no-check", action="store_true", help="skip writing the route as guide steps and checking it")
    parser.add_argument("--out", type=Path, help="where to write the plan (default plans/<guide>)")
    parser.add_argument("--no-write", action="store_true", help="write nothing")
    parser.add_argument("--quiet", action="store_true", help="print only the summary")
    parser.add_argument("--root", type=Path, default=REPO_ROOT, help="the Signpost checkout")
    parser.add_argument("--pack", type=Path, help="the data pack folder (default ../Signpost_Data)")
    options = parser.parse_args(argv)
    guide_travel.safe_stdout()

    project = guidefile.load_project(options.root)
    out = Out(options.quiet)
    if not options.guide:
        out("\n".join(list_guides(project, options.root)), always=True)
        return 0
    matches = find_guides(project, options.guide)
    if len(matches) != 1:
        out(f"{'no guide' if not matches else 'several guides'} matches {' '.join(options.guide)!r}:", always=True)
        out("\n".join(list_guides(project, options.root)), always=True)
        return 2
    job = build_job(options, project, matches[0], out)
    if job is None:
        return 1

    presets = list(PRESETS) if options.preset == "all" else [options.preset]
    first_pl = planner_for(job, out, quiet=True)
    report_setup(job, out, first_pl, options)
    pls: dict[str, engine.Planner] = {}
    outcomes: list[Outcome] = []
    for preset in presets:
        out(f"\nplanning with {preset} ...", always=True)
        pl, outcome = run_preset(job, preset, options, out, base=first_pl)
        pls[preset] = pl
        outcomes.append(outcome)
        report_search(out, pl, outcome)
    # what a technique returns, written as guide steps and checked
    if not options.no_check:
        for outcome in outcomes:
            if outcome.plan.complete or outcome.plan.visits:
                outcome.evaluation = evaluate(job, pls[outcome.preset], outcome.plan, outcome.preset)
    shown = outcomes[-1]
    pl = pls[shown.preset]
    if "thorough" in presets and not options.no_check:
        candidates = [shown] + [
            Outcome(f"thorough alt {i}", alt, 0.0, evaluate(job, pl, alt, f"alt{i}")) for i, alt in enumerate(shown.plan.alternatives, 1)
        ]
        monte_carlo(job, candidates, options.runs, options.seed)
        shown.monte = candidates[0].monte
        shown_monte = candidates
    else:
        shown_monte = []
    report_route(out, pl, shown.plan)
    report_time(out, pl, shown.plan)
    report_quests(out, pl, job, shown.plan)
    if options.decisions and shown.preset != "greedy":
        explain_decisions(out, pl, shown.plan, options.decisions)
    if shown.evaluation is not None:
        report_validation(out, pl, shown.plan, shown.evaluation)
        if options.steps >= 0:
            report_steps(out, shown.evaluation, options.steps)
    if shown_monte:
        report_monte(out, shown_monte)
    if len(outcomes) > 1:
        report_compare(out, pls, outcomes)
    if not options.no_write and shown.evaluation is not None:
        out_dir = options.out or options.root / "plans" / job.guide.id
        for outcome in outcomes:
            if outcome.evaluation is not None:
                write_outputs(job, outcome, pls[outcome.preset], out_dir, out)
        out.section("FILES")
        out(f"  {out_dir}/<technique>/ holds report.txt, plan.json and the route as guide chapters (Guides/Chapters/*.lua, Guides/Plan.lua)")
        out("  nothing was changed in the guides: the chapters are a candidate to read, compare and then install on purpose")
    out("", always=True)
    out(f"{shown.preset}: {hms(shown.plan.seconds)} to level {shown.plan.final.level} under the stated assumptions"
        + (f"; {hms(shown.evaluation.sim.seconds)} when the written route is simulated in full" if shown.evaluation else ""), always=True)
    return 0 if shown.plan.complete else 1


if __name__ == "__main__":
    sys.exit(main())
