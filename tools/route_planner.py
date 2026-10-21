"""The Route Planner: plans a leveling route for a guide's character on a state graph, then says in detail what it did.

    python tools/route_planner.py                           the guides and what the tool can do
    python tools/route_planner.py troll                     plan the Troll Hunter with the default technique (beam)
    python tools/route_planner.py troll --preset all        run every technique and compare them
    python tools/route_planner.py druid --preset thorough   a wide search, then the finalists under uncertain assumptions
    python tools/route_planner.py tauren --cap 20 --friction 5 --steps 60
    python tools/route_planner.py troll --preset all --install   plan, compare, and make the best route that passes its checks the guide

The guide is named by any words of its id, name, race or class. The tool takes the guide's character (faction, race, class),
whether it is a HARDCORE or a normal guide, and its class quests (which must be done or accounted for), and plans a route from
level 1 to the cap through every quest the character may take, anywhere. A node of the planner's graph is a situation (place,
level and experience, quests done and in the log, the clock), an edge is "go to a hub and do everything worthwhile there"; the
cost of an edge is the simulator's time, and a quest is accepted only where the game would offer it (docs/PLANNER.md).

The techniques (--preset):
  greedy     nearest thing first, finish a zone, move on (the way the guides are drafted); seconds
  lookahead  greedy, but each choice is tried by playing the rest out greedily and the best is kept; seconds
  beam       keeps the best partial routes for each part of a level (routes are compared by how far they have got); the default
  thorough   the beam at several grains of progress, then the finalists walked hundreds of times with uncertain assumptions (Monte Carlo)
  all        every technique above, with a comparison

The report says what the search did (how many situations, how many dropped and why), the route as a graph of zones, the time
and experience by level, the quests done and left out, the decisions at each change of zone with the alternatives, and the
check of the finished route by the same simulator and lint the shipped guides go through. It is written to plans/<guide>/.
Every number is an assumption (tools/sim_params.json): this is the best route under those assumptions, not a prediction.

--install is the step taken on purpose: the route that passes every check and has the shortest median time to the cap over the Monte Carlo
runs (or, without thorough, the lowest total) becomes the guide's chapters; tools/route_install.py says what it changes (docs/PLANNER.md).
"""

from __future__ import annotations

import argparse
import datetime
import json
import shutil
import subprocess
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
import route_install  # noqa: E402
from signpost_tools import availability, guidefile  # noqa: E402
from signpost_tools.guidefile import Coord  # noqa: E402

REPO_ROOT = Path(__file__).resolve().parent.parent
PRESETS = ("greedy", "lookahead", "beam", "thorough")
WIDTH = 112
CLASS_LATE = 5  # levels after it opens at which a class quest done is called late in the report
SPREAD_WARNING = 5.0  # percent: grains of progress whose best routes are this far apart make the search too rough to trust
PRESET_SETTINGS = {  # what each technique changes in the planner's settings
    "greedy": {},
    "lookahead": {"branch": 8, "horizon": 12},
    "beam": {"branch": 8, "width": 30, "parts": (2,)},
    "thorough": {"branch": 10, "width": 40, "parts": (2, 4, 8), "alternatives": 5},
}


# small formatting helpers ----------------------------------------------------------------------------------------------


def hms(seconds: float) -> str:
    if seconds == float("inf"):
        return "never"  # a run of the Monte Carlo that did not get there
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


def labelled(label: str, text: str, width: int = WIDTH) -> list[str]:
    """A report line with its label in the first column and the text wrapped under it."""
    pad = " " * len(label)
    lines = wrap(text, pad, width)
    if lines:
        lines[0] = label + lines[0][len(pad):]
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
    chains: tuple = ()
    start: Coord | None = None
    skip_zones: dict = field(default_factory=dict)
    required: tuple = ()  # the quests the guide requires (the manifest's `require`, --require): done whatever they cost


def manifest_hardcore(root: Path, guide_id: str) -> bool | None:
    try:
        manifest = json.loads((root / "tools" / "drafts.json").read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None
    for entry in manifest.get("guides", []):
        if entry.get("guide") == guide_id and isinstance(entry.get("hardcore"), bool):
            return entry["hardcore"]
    return None


def manifest_chains(root: Path, guide_id: str) -> list[list[int]]:
    """The `--chain` hints the guide's chapters are drafted with: quests of a chain the data does not link."""
    try:
        manifest = json.loads((root / "tools" / "drafts.json").read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return []
    found = []
    for entry in manifest.get("guides", []):
        if entry.get("guide") == guide_id:
            for chapter in entry.get("chapters", []):
                args = [str(a) for a in chapter.get("args", [])]
                found += [[int(x) for x in args[i + 1].split(",")] for i, a in enumerate(args[:-1]) if a == "--chain"]
    return found


def manifest_excludes(root: Path, guide_id: str) -> dict[int, str]:
    """The quests the guide's drafted chapters leave out on purpose (`--exclude` with the chapter's `--exclude-reason`): the planner
    leaves them out too and says why in a `#skipquest` line."""
    try:
        manifest = json.loads((root / "tools" / "drafts.json").read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}
    found: dict[int, str] = {}
    for entry in manifest.get("guides", []):
        if entry.get("guide") != guide_id:
            continue
        for chapter in entry.get("chapters", []):
            args = [str(a) for a in chapter.get("args", [])]
            reason = guide_draft.HARDCORE_NOTE
            for i, a in enumerate(args[:-1]):
                if a == "--exclude-reason":
                    reason = args[i + 1]
            for i, a in enumerate(args[:-1]):
                if a == "--exclude" and args[i + 1].isdigit():
                    found[int(args[i + 1])] = reason
    return found


def manifest_requires(root: Path, guide_id: str) -> list[int]:
    """The quests the guide's entry in tools/drafts.json requires (`"require": [questID, ...]`): the planned route must do them, whatever they cost."""
    try:
        manifest = json.loads((root / "tools" / "drafts.json").read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return []
    found: list[int] = []
    for entry in manifest.get("guides", []):
        if entry.get("guide") == guide_id and isinstance(entry.get("require"), list):
            found += [q for q in entry["require"] if isinstance(q, int) and not isinstance(q, bool)]
    return found


def start_of(job_project: guidefile.Project, guide: guidefile.Guide, world, override: str | None) -> Coord | None:
    """Where the character begins: --start, else the first place the guide as it is sends it to."""
    if override:
        m, x, y = override.split(",")
        return Coord(int(m), float(x), float(y))
    options = Namespace(faction=None, race=None, cls=None, profession=[], no_tracks=True)
    routes = guide_travel.guide_routes(job_project, guide, options, lambda faction: world)
    for rs in routes[0].steps if routes else []:
        target = rs.first_target()
        if target is not None:
            return target
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
    skip_zones: dict = {}
    try:
        rules_file = json.loads((options.root / "tools" / "hardcore_rules.json").read_text(encoding="utf-8"))
        rules = rules_file.get("rules", [])
        for zone in rules_file.get("skip_zones", []):
            if isinstance(zone, dict) and isinstance(zone.get("zone"), int):
                skip_zones[zone["zone"]] = str(zone.get("reason") or "not leveling content")
    except (OSError, ValueError):
        rules = []
    for rule in rules:
        if isinstance(rule, dict) and isinstance(rule.get("id"), int) and guide_draft.rule_applies(rule, cls):
            reason = str(rule.get("reason") or "HARDCORE: not routed")
            # a skip whose reason is not about HARDCORE (a battleground quest is not leveling content) holds for every route
            if rule.get("action") == "skip" and (hardcore or not reason.startswith("HARDCORE")):
                exclude[rule["id"]] = reason
            elif rule.get("action") == "note" and rule.get("text") and hardcore:
                notes[rule["id"]] = str(rule["text"])
    exclude.update(manifest_excludes(options.root, guide.id))
    for qid in options.exclude:
        exclude[qid] = "excluded on the command line"
    chains = guide_lint.class_chains(project, pack, cls, race)
    mandatory = tuple(q for c in chains if not c.pending and (c.level or 0) <= options.cap for q in c.quests)
    settings = engine.Settings(
        cap=options.cap,
        hardcore=hardcore,
        hub_radius=options.hub_radius,
        zone_friction=options.friction * 60,
        class_push=options.class_push * 60,
        class_grace=options.class_grace,
        group_yards=options.group_yards,
        quest_log_limit=options.quest_log,
        chapter_min_steps=options.chapter_steps,
        completeness=options.completeness,
        completeness_trip=options.completeness_trip,
        walk_by_map=options.walk_by_map,
        instant_quests=options.instant_quests,
        skip_unprofitable=not options.no_skip,
        profit_threshold=options.threshold,
        ferry_seconds=engine.Settings.ferry_seconds if options.ferry is None else options.ferry * 60,
        gateways=(1454, 1458) if guide.faction == "Horde" else (1453, 1455, 1457),
    )
    world = guide_travel.World(pack, project.borders, guide.faction)
    hints = manifest_chains(options.root, guide.id) + [list(c) for c in options.chain]
    required = tuple(dict.fromkeys(manifest_requires(options.root, guide.id) + [q for ids in options.require for q in ids]))
    job = Job(
        options.root, project, pack, pack_dir, guide, hardcore, character, race, cls, world, settings, params, mandatory, exclude, notes, chains,
        tuple(tuple(c) for c in hints), start_of(project, guide, world, options.start), skip_zones, required,
    )
    return job


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
        required=job.required,
        chains=job.chains,
        home=job.start,
        skip_zones=job.skip_zones,
        log=(lambda text: None) if quiet else (lambda text: out("  " + text)),
    )
    return pl


def start_hub(job: Job, pl: engine.Planner) -> tuple[int | None, str]:
    """Where the route starts: the hub of the guide's first step, else where the race's first quest is given."""
    if job.start is not None:
        found = pl.hub_near(job.start)
        if found is not None:
            return found, "the guide's first step"
    return engine.start_hub_for(pl), "the race's first quest"


def run_preset(job: Job, preset: str, options, out: Out, base: engine.Planner | None = None) -> tuple[engine.Planner, Outcome]:
    overrides = dict(PRESET_SETTINGS[preset])
    for name in ("width", "branch", "horizon", "parts"):
        if getattr(options, name) is not None:
            overrides[name] = getattr(options, name)
    pl = planner_for(job, out, overrides, quiet=base is not None)
    start, _ = start_hub(job, pl)
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
    out(f"quests       {total} in the pack; {len(pl.quests)} can be routed for this character; "
        f"{sum(1 for q in pl.quests.values() if q.kept)} kept for the planner")
    reasons = sorted(pl.dropped.items(), key=lambda kv: -len(kv[1]))
    out("              left out: " + "; ".join(f"{len(ids)} {reason}" for reason, ids in reasons[:7]))
    begin, why = start_hub(job, pl)
    out(f"hubs          {len(pl.hubs)} of about {s.hub_radius:.0f} yards; {len(pl.gateways)} continent gateways; the route starts at "
        f"{pl.hubs[begin].label if begin is not None else 'nowhere (no quest can be routed)'} ({why})")
    rules = [
        "a quest is accepted only where the game would offer it (level, prerequisites, chains, exclusive quests)",
        f"a change of zone costs {s.zone_friction / 60:.0f} min on top of the travel; a trip between continents is the walk to "
        f"the capital's boat or zeppelin + {s.ferry_seconds / 60:.0f} min + the walk from the other capital",
        f"quests slower than grinding are left out (threshold {s.profit_threshold:g}x) unless they are class quests or needed by a kept quest"
        if s.skip_unprofitable
        else "no quest is left out for being slow",
        (f"HARDCORE: no elite or boss objectives, no dungeon quests (what needs one goes with it), no quest more than {s.hardcore_over} level above the "
         f"character, {len(job.exclude)} skips (tools/hardcore_rules.json and the guide's own list)")
        if s.hardcore
        else f"a normal route: quests up to {pl.accept_over} levels above you are accepted and worked on up to {pl.work_over}; group quests (elite kills), "
             f"dungeon quests and the quests that need one of those first are tagged optional",
        f"the quest log holds at most {s.quest_log_limit} quests; no quest is accepted while it is full (--quest-log N; Forever's is 40, confirmed "
        f"by the user in the game, 2026-10-21; Classic's is 25)",
        (f"a quest the route picked up and did not finish is finished when its objectives are at most {s.completeness_trip:g} s of walking away and it pays "
         f"at least {s.completeness:.0%} of the route's pace (--completeness, --completeness-trip); the rest are taken out and listed with the reason")
        if s.completeness > 0
        else "a quest the route picked up and did not finish is taken out when the route is written, and listed with the reason (completeness is off here: --completeness F "
             "finishes the ones that are a short walk away and pay at least F of the route's pace)",
        (f"required quests (--require, \"require\" in tools/drafts.json): {', '.join(str(q) for q in job.required)}. Each is done "
         f"whatever it costs, with the quests it needs (all of them are pushed like a class chain's); none is left out for being slow, taken out when the "
         f"route is written, or kept out by a full quest log, and one that only has to be handed in, in another zone, is handed in next (the route leaves for it)")
        if job.required
        else "no quest is required (--require ID,... or \"require\" in the guide's entry of tools/drafts.json makes the route do the quests it names)",
        f"{len(job.mandatory)} class quests are mandatory: each is done or accounted for with a #skipquest reason; there is no deadline, "
        f"but each costs the route {s.class_push / 60:.0f} min for every level it is undone past the level it opens at"
        + (f" (+{s.class_grace})" if s.class_grace else "")
        + ", so it is picked up when the route passes the giver and a far one gets its trip soon after it opens",
    ]
    for n, rule in enumerate(rules):
        for line in labelled("rules         " if n == 0 else "              ", rule):
            out(line)


def report_search(out: Out, pl: engine.Planner, outcome: Outcome) -> None:
    plan = outcome.plan
    p = plan.stats
    s = pl.s
    out.section(f"THE SEARCH: {outcome.preset}")
    grain = ", ".join(str(n) for n in s.parts)
    how = {
        "greedy": "nearest hub with something to do, a zone finished before the next; one path, no alternatives considered",
        "lookahead": f"at every step the {s.branch} best hubs are each tried by playing {s.horizon} visits on greedily; the best is kept",
        "beam": f"routes are compared by how far they have got ({grain} parts to a level): the {s.width} best of each part are kept "
                f"({s.branch} hubs tried from each); a route is dropped when another reaches the same situation sooner",
        "thorough": f"as beam, once for each grain of progress ({grain} parts to a level), {s.width} routes wide and "
                    f"{s.branch} hubs from each; the finalists are then walked with uncertain assumptions",
    }[outcome.preset]
    out("technique     " + how)
    out(f"work          {outcome.wall:.1f} s; {p.get('nodes', 0):,} situations made" + (f"; {p['pruned']:,} dropped (worse than another route to the same situation, "
        f"beyond the beam, or hopeless against the best finished route)" if "pruned" in p else ""))
    if "baseline_seconds" in p:
        base = p["baseline_seconds"]
        better = (base - plan.total) / base * 100 if base else 0
        out(f"baseline      the greedy route takes {hms(base)} (with the planner's charges); this one {hms(plan.total)}: "
            f"{better:.1f}% {'faster' if better >= 0 else 'slower'}")
    if "finals" in p:
        if not p["finals"]:
            out("finished      NO route of its own: no partial route reached the cap with every class quest done, so this is the greedy route "
                "(the class quests may not all be doable, or the search dropped every route as hopeless; --class-push 0 shows whether the "
                "class quests are the cause)")
        elif p.get("chosen") == "greedy":
            out(f"finished      {p['finals']:,} complete routes reached the cap during the search, none faster than the greedy one once tidied: "
                f"this is the greedy route")
        else:
            out(f"finished      {p['finals']:,} complete routes reached the cap during the search; the best {len(plan.alternatives) + 1} with different "
                f"orders of zones are kept to compare")
    if len(p.get("grains", ())) > 1:
        report_grains(out, p["grains"])
    if p.get("removed"):
        names = ", ".join(pl.quests[q].name for q in p["removed"][:6] if q in pl.quests)
        out(f"tidied        {len(p['removed'])} quests the search had accepted but never finished were taken out of the route (a guide may not leave them in the log): {names}"
            + (" ..." if len(p["removed"]) > 6 else ""))
    if p.get("completed"):
        names = ", ".join(pl.quests[q].name for q in p["completed"][:6] if q in pl.quests)
        unplaced = len(p.get("completed_unplaced", ()))
        for line in labelled(
            "completed     ",
            f"{len(p['completed'])} more quests the search left unfinished were finished instead (completeness {pl.s.completeness:.2f}, trips up to "
            f"{pl.s.completeness_trip:g} s): the route stops at their objectives right after the pick-up: {names}" + (" ..." if len(p["completed"]) > 6 else "")
            + (f"; {unplaced} with an objective that has no position in the data, which the planner works where the quest is picked up, with no walk"
               if unplaced else ""),
        ):
            out(line)
    if plan.trace:
        out("progress      best estimated total time as the search moved up the levels (level | routes kept | estimate):")
        picks = plan.trace[:: max(1, len(plan.trace) // 8)]
        out("              " + "   ".join(f"{lv:g}: {n}, {hms(e)}" for lv, n, e in picks))
    out(f"result        {'reaches level ' + str(s.cap) if plan.complete else 'does NOT complete'}: {hms(plan.seconds)} of play"
        f" (+ {hms(plan.penalty)} of zone-change cost"
        + (f" and {hms(plan.late)} for class quests done late" if plan.late else "")
        + f" the planner charged), {len(plan.visits)} hub visits")


def spread_of(grains: list) -> tuple[float, float] | None:
    """How far apart the best routes of the grains are, as they would be written: (seconds, percent of the shortest); None when fewer
    than two grains finished a route."""
    totals = [g["total"] for g in grains if g.get("total") is not None]
    if len(totals) < 2:
        return None
    low, high = min(totals), max(totals)
    return high - low, ((high - low) / low * 100 if low else 0.0)


def report_grains(out: Out, grains: list) -> None:
    """The roughness of the search made visible: every grain of progress was searched on its own, and its best route, written out the way a
    guide would have it, says what that grain found. How far apart they are is the least the best route found can be off by: nobody
    knows how far it is from the best there is."""
    out("grains        each grain of progress searched on its own: its best route as it would be written (tidied), and the work it took")
    out(f"              {'parts':>5} {'routes finished':>16} {'best route':>11} {'seconds':>8}")
    shortest = min((g["total"] for g in grains if g.get("total") is not None), default=None)
    for g in grains:
        total = hms(g["total"]) if g.get("total") is not None else "none"
        mark = "   <- the shortest" if shortest is not None and g.get("total") == shortest else ""
        out(f"              {g['parts']:>5} {g['finals']:>16,} {total:>11} {g['seconds']:>8.1f}{mark}")
    spread = spread_of(grains)
    if spread is None:
        out("              fewer than two grains finished a route: nothing to compare them by")
        return
    seconds, percent = spread
    out(f"              the grains disagree by {hms(seconds)}, {percent:.0f}%: trust the best route no more than that")
    if percent > SPREAD_WARNING:
        warning = (
            f"WARNING: the grains are more than {SPREAD_WARNING:.0f}% apart. The search is rough on this guide: a shorter route than the best found "
            f"may exist, and a route that is not clearly better than the others is not to be trusted (try other --parts or --width and compare)."
        )
        for line in labelled("              ", warning):
            out(line)


def grinds_of(pl: engine.Planner, plan: engine.Plan) -> list[dict]:
    """The grind steps of a route: where the planner stops to kill for a level that opens quests (the `.level N` steps that say how much)."""
    found: list[dict] = []
    clock, level = 0.0, 1
    for v in plan.visits:
        if v.hub is None:
            target = v.actions[0].index
            found.append(
                dict(at=clock, level_from=level, level_to=target, xp=v.xp, seconds=v.seconds, kills=pl.grind_kills(level, target, v.xp))
            )
        clock += v.seconds
        level = v.level
    return found


def report_grinds(out: Out, pl: engine.Planner, plan: engine.Plan) -> None:
    grinds = grinds_of(pl, plan)
    if not grinds:
        out("grinding      the route never stops to grind for a level")
        return
    total = sum(v.seconds for v in plan.visits)
    xp_total = sum(pl.model.to_next(n) for n in range(1, plan.final.level))
    xp, seconds = sum(g["xp"] for g in grinds), sum(g["seconds"] for g in grinds)
    text = (
        f"{len(grinds)} grind step(s) ask the player to kill for a level: {xp:,.0f} experience ({share(xp, xp_total).strip()} of the route's), "
        f"{hms(seconds)} ({share(seconds, total).strip()} of its play time). Each is a `.level N` line with a note that says how much (an estimate):"
    )
    for line in labelled("grinding      ", text):
        out(line)
    for g in grinds:
        out(
            f"              at {hms(g['at'])}: level {g['level_from']} to {g['level_to']}, about {engine.approx(g['xp']):,} experience, "
            f"about {max(1, engine.approx(g['kills'])):,} kills, {mins(g['seconds'])}"
        )


def report_left_out(out: Out, pl: engine.Planner, plan: engine.Plan, limit: int = 12) -> None:
    """What tidy took out of the route, with the reason and the numbers (`Planner._left_out`): nothing is dropped silently. Each is also a #skipquest
    line of the guide and a record in plan.json."""
    records = plan.stats.get("left_out", [])
    if not records:
        out("unfinished    none: the search left no quest unfinished")
        return
    codes: dict[str, int] = {}
    for r in records:
        codes[r["code"]] = codes.get(r["code"], 0) + 1
    names = {"price": "near but not worth the trip", "far": "objectives too far", "handin": "hand-in too far", "level": "could not be worked",
             "unfinished": "stop added, still unfinished"}
    near_first = {"price": 0, "unfinished": 1, "handin": 2, "far": 3, "level": 4}  # the ones a setting would get back come first
    summary = ", ".join(f"{n} {names.get(code, code)}" for code, n in sorted(codes.items(), key=lambda kv: (-kv[1], near_first.get(kv[0], 5))))
    unplaced = sum(1 for r in records if r.get("unplaced"))
    out(f"unfinished    {len(records)} quests the search picked up on the way and did not finish are not in the route ({summary})"
        + (f"; {unplaced} with an objective that has no position in the data:" if unplaced else ":"))
    shown = sorted(records, key=lambda r: (near_first.get(r["code"], 5), -r["ratio"]))[:limit]
    for r in shown:
        for line in labelled(
            "              ",
            f"{r['quest']} {r['name']} (level {r['level']}, picked up at level {r['picked_level']}, {r['hub'].split(': ', 1)[-1]}): {r['why']}",
        ):
            out(line)
    if len(records) > len(shown):
        out(f"              ... {len(records) - len(shown)} more (all of them in plan.json, and as #skipquest lines in the guide)")


def route_log_peak(route) -> int:
    """The most quests a written route holds in the quest log at once, counted on the guide's own steps (an accept adds one, a hand-in takes one out)."""
    active: set = set()
    peak = 0
    for rs in route.steps:
        for d in rs.directives:
            quest = d.args.get("quest")
            if d.name == "accept" and quest:
                active.add(quest)
                peak = max(peak, len(active))
            elif d.name == "turnin" and quest:
                active.discard(quest)
    return peak


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
    done, levels = plan.final.done, plan.levels_done()
    fallback = [q for q in done if q not in pl.model.quest_xp]
    reward = lambda q: pl.reward(q, levels.get(q, 1))
    xp_fallback, xp_done = sum(reward(q) for q in fallback), sum(reward(q) for q in done)
    out(f"  quest XP    {len(fallback)} of the {len(done)} quests done ({share(xp_fallback, xp_done).strip()} of their experience) have no entry in "
        f"QuestieDB's Classic seed and get {pl.model.p['quest_xp_fraction_of_level']:.0%} of the level: the more a route leans on them, the less "
        f"certain it is (--param quest_xp_fraction_of_level=0.05 shows by how much)")


def report_quests(out: Out, pl: engine.Planner, job: Job, plan: engine.Plan) -> None:
    out.section("THE QUESTS")
    done = plan.final.done
    optional = [q for q in done if pl.quests[q].optional]
    why = [f"{n} {one if n == 1 else many}" for key, one, many in (("elite", "group quest", "group quests"), ("dungeon", "dungeon quest", "dungeon quests"),
                                                                    ("follows", "following one of those", "following one of those"))
           if (n := sum(1 for q in optional if pl.quests[q].group == key))]
    out(f"done          {len(done)} quests turned in" + (f", {len(optional)} of them tagged optional ({', '.join(why)})" if optional else ""))
    held, held_level, held_clock = plan.log_peak()
    out(f"quest log     the most quests held at once: {held} (at level {held_level}, {hms(held_clock)} in); the log holds {pl.s.quest_log_limit} "
        f"(--quest-log N; Forever's is {engine.Settings.quest_log_limit}, confirmed by the user in the game)")
    report_left_out(out, pl, plan)
    slow = pl.dropped.get("slower than grinding", [])
    out(f"left out      {len(slow)} quests were slower than grinding; the slowest, by experience per minute against grinding at the level it is done at:")
    scored = sorted((pl.quests[q] for q in slow), key=lambda q: q.rate / max(pl.model.grind_xp_per_second(max(q.req, q.level - 1, 1)), 1e-9))
    for q in scored[:8]:
        grind = pl.model.grind_xp_per_second(min(pl.s.cap, max(q.req, q.level - 1, 1)))
        out(f"              {q.id:>6} {q.name[:34]:<34} L{q.level:<3} {q.rate * 60:6.0f} XP/min vs grinding {grind * 60:5.0f}")
    other = {k: len(v) for k, v in pl.dropped.items() if k != "slower than grinding"}
    out("not routable  " + "; ".join(f"{n} {k}" for k, n in sorted(other.items(), key=lambda kv: -kv[1])[:8]))
    if job.mandatory:
        levels = plan.levels_done()
        parts = [f"{q} " + (f"at {levels[q]} (opens {pl.quests[q].req})" if q in levels else "skipped") for q in job.mandatory]
        for line in labelled("class quests  ", f"{len(job.mandatory)} mandatory; done at level (the level it opens at): " + ", ".join(parts)):
            out(line)
        late = [q for q in levels if q in job.mandatory and levels[q] - pl.quests[q].req > CLASS_LATE]
        if late:
            out(f"              {len(late)} of them still come more than {CLASS_LATE} levels after they open (the route found it cheaper than "
                f"the {pl.s.class_push / 60:.0f} min a level that is charged; --class-push)")
        for qid, reason in pl.skipquests(plan).items():
            if qid in job.mandatory:
                out(f"              #skipquest {qid} ({pl.quests[qid].name if qid in pl.quests else '?'}): {reason}")
    if job.required:
        levels = plan.levels_done()
        parts = [
            f"{q} {pl.quests[q].name} at level {levels[q]} (opens {pl.quests[q].req}, a level {pl.quests[q].level} quest)" if q in levels
            else f"{q} {pl.quests[q].name} NOT DONE"
            for q in job.required if q in pl.quests
        ]
        needed = len(pl.required) - len(pl.asked)
        for line in labelled(
            "required      ",
            f"{len(job.required)} required by the guide"
            + (f" and {needed} quest{'s' if needed != 1 else ''} {'they need' if needed != 1 else 'it needs'}, all routed and none left out" if needed else "")
            + "; done at level (the level it opens at): " + "; ".join(parts),
        ):
            out(line)
    if pl.s.hardcore:
        highest = max((pl.quests[q].level - 0 for q in done), default=0)
        out(f"HARDCORE      no elite or boss objective and no dungeon quest in the pool (those are left out before the search); the highest quest level routed is {highest}")


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
    held = route_log_peak(ev.route)
    out(f"quest log     the written route holds at most {held} quests at once (the log holds {pl.s.quest_log_limit})"
        + ("" if held <= pl.s.quest_log_limit else ": ERROR, more than the log holds"))
    out(f"lint          {len(ev.lint_errors)} error(s), {ev.lint_warnings} warning(s)")
    for line in ev.lint_errors[:8]:
        out("              " + line[:WIDTH - 14])
    estimate, full = plan.seconds, sim.seconds
    out(f"fidelity      the planner estimated {hms(estimate)}; the full simulation of the written route says {hms(full)} "
        f"({(full - estimate) / estimate * 100:+.1f}%). Both price travel with the same numbers (signpost_tools/pricing.py: a change of zone "
        f"is the walk between the places, a change of continent the boat and the walks to and from it); they still differ in the walking inside "
        f"a hub: the planner adds a few seconds for each place of a visit, the simulation walks the steps' own positions and does not price "
        f"the walk inside a doing step")
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
        cap = max(m["levels"])
        reached = m.get("reached", {}).get(cap, 1.0)
        out(f"  {o.preset:<14} " + "   ".join(cells) + f"   fastest in {m['wins']:.0%} of runs"
            + (f"   REACHED THE CAP IN ONLY {reached:.0%} OF RUNS" if reached < 1.0 else ""))
    best = max((o for o in outcomes if o.monte), key=lambda o: o.monte["wins"], default=None)
    if best is not None:
        out(f"  most often the fastest: {best.preset} ({best.monte['wins']:.0%} of the runs; finalists a few minutes apart win by luck)")
    cap = max((l for o in outcomes if o.monte for l in o.monte["levels"]), default=None)
    typical = min((o for o in outcomes if o.monte and cap in o.monte["p50"]), key=lambda o: o.monte["p50"][cap], default=None)
    if typical is not None and typical.monte["p50"][cap] != float("inf"):
        out(f"  shortest median to level {cap}: {typical.preset} ({hms(typical.monte['p50'][cap])}): the route --install takes if it passes its checks")


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
        o.monte = monte_summary(results, levels, w, runs)


def monte_summary(results: list, levels: list[int], wins: int, runs: int) -> dict:
    """The Monte Carlo runs of one route as percentiles of the time to each level. A run that never reached a level counts as infinitely
    slow there: the median is of all the runs, not of the lucky ones, and a route that fails more often cannot win on its survivors."""

    def at(level):
        return [r.levels[level][0] if level in r.levels else float("inf") for r in results]

    return dict(
        levels=levels,
        p10={l: guide_sim.percentile(at(l), 10) for l in levels},
        p50={l: guide_sim.percentile(at(l), 50) for l in levels},
        p90={l: guide_sim.percentile(at(l), 90) for l in levels},
        wins=wins / runs,
        reached={l: sum(1 for r in results if l in r.levels) / max(1, len(results)) for l in levels},
        runs=runs,
    )


def report_compare(out: Out, pls: dict, outcomes: list[Outcome]) -> None:
    out.section("COMPARISON OF THE TECHNIQUES")
    base = next((o for o in outcomes if o.preset == "greedy"), outcomes[0])
    base_total = base.plan.total
    out(f"  {'technique':<11} {'work':>8} {'situations':>11} {'play time':>9} {'+ charges':>11} {'vs greedy':>9} {'legs':>5} {'visits':>6} {'quests':>6}  complete")
    for o in outcomes:
        pl = pls[o.preset]
        legs = legs_of(pl, o.plan)
        total = o.plan.total
        out(f"  {o.preset:<11} {o.wall:>7.1f}s {o.plan.stats.get('nodes', 0):>11,} {hms(o.plan.seconds):>9} {hms(total):>11} "
            f"{(total - base_total) / base_total * 100:>+8.1f}% {len(legs):>5} {len(o.plan.visits):>6} {len(o.plan.final.done):>6}  {'yes' if o.plan.complete else 'NO'}")


def report_steps(out: Out, ev: Evaluation, limit: int) -> None:
    out.section(f"THE FIRST {limit} STEPS OF THE ROUTE (as the simulator walks them)" if limit else "ALL THE STEPS OF THE ROUTE (as the simulator walks them)")
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


def passes(o: Outcome, cap: int) -> bool:
    """A route that may be installed: it reaches the cap in the planner and in the full simulation with every class quest done or
    accounted for, the game would offer every quest where it accepts it, and the lint finds no error."""
    ev = o.evaluation
    return (
        ev is not None
        and o.plan.complete
        and ev.sim.level >= cap
        and not [v for v in ev.sim.violations if v.reason.severity == "error"]
        and not ev.lint_errors
    )


def choose(outcomes: list[Outcome], finalists: list[Outcome], cap: int) -> Outcome | None:
    """The route to install: of those that pass their checks, the one with the shortest median time to the cap over the Monte Carlo runs
    (every technique's route and thorough's finalists meet the same luck; a run that never reached the cap counts as infinitely slow, so
    a route that fails often has no median), then the shorter 90th percentile, then the lower planner total; without a Monte Carlo, the
    lowest total. ("Fastest in most runs" is not used: finalists a few minutes apart win by luck.)"""
    pool = list({id(o): o for o in [*outcomes, *finalists] if passes(o, cap)}.values())
    measured = [o for o in pool if o.monte and cap in o.monte.get("p50", {})]  # a median of infinity (half the runs failed) sorts last
    if measured:
        return min(measured, key=lambda o: (o.monte["p50"][cap], o.monte.get("p90", {}).get(cap, float("inf")), o.plan.total))
    return min(pool, key=lambda o: o.plan.total, default=None)


def planner_of(pls: dict, o: Outcome) -> engine.Planner:
    """The planner a technique's outcome came from (thorough's finalists are named "thorough alt N")."""
    return pls.get(o.preset) or pls[o.preset.split(" ")[0]]


def command_of(argv: list[str] | None) -> str:
    """The command line that made the route, without the paths of this machine."""
    tokens = list(sys.argv[1:] if argv is None else argv)
    kept, i = [], 0
    while i < len(tokens):
        if tokens[i] in ("--root", "--pack", "--out"):
            i += 2
            continue
        kept.append(tokens[i])
        i += 1
    return " ".join(kept)


def install_problem(job: Job, options) -> str | None:
    """Why this install should not go ahead without --force: it would shorten the guide, or overwrite uncommitted changes."""
    top = job.guide.levels[1]
    if options.cap < top:
        return (f"--install: {job.guide.name} covers levels 1 to {top} and this route stops at {options.cap}, which would shorten it "
                f"(plan to --cap {top} or more, or use --force)")
    try:
        status = subprocess.run(["git", "status", "--porcelain", "--", "Guides", "Signpost.toc", "Signpost_Camelot.toc", "tools/drafts.json"],
                                cwd=job.root, capture_output=True, text=True)
    except OSError:
        return None  # no git here: nothing to check against
    if status.returncode == 0 and status.stdout.strip():
        return ("--install: the guide files have uncommitted changes that the install would overwrite or delete; "
                "commit or stash them, or use --force")
    return None


def install_route(job: Job, chosen: Outcome, out: Out, command: str) -> bool:
    note = f"the {chosen.preset} route for {job.guide.name}: tools/route_planner.py {command} (docs/PLANNER.md)"

    def say(text: str = "") -> None:
        out(text, always=True)

    try:
        result = route_install.install(job.root, chosen.evaluation.root, job.guide.id, job.guide.faction, note, job.settings.cap,
                                       guide_draft.BASELINE_NOTE)
    except ValueError as error:
        say()
        say(f"not installed: {error} (nothing was changed)")
        return False
    except OSError as error:
        say()
        say(f"INSTALL FAILED part-way: {error}; look at `git status` before anything else")
        return False
    say()
    say("== INSTALLED " + "=" * (WIDTH - 16))
    say(f"the {chosen.preset} route ({hms(chosen.plan.seconds)} of play, {hms(chosen.evaluation.sim.seconds)} simulated in full) is now "
        f"{job.guide.name}'s guide: {len(result.chapters)} chapters, levels 1 to {job.settings.cap}, {chosen.evaluation.todos} .todo steps")
    say(f"  chapters written   {', '.join(result.chapters[:6])}" + (" ..." if len(result.chapters) > 6 else ""))
    if result.removed:
        say(f"  chapters replaced  {', '.join(result.removed)}")
    say(f"  changed            {', '.join(sorted({p.name for p in result.files if p.suffix != '.lua' or 'Chapters' not in p.parts}))}")
    say("  StyLua             " + {True: "ran on the Lua files", False: "FAILED: run StyLua on Guides/ before committing",
                                    None: "not found: run StyLua on Guides/ before committing"}[result.formatted])
    say("  next               read `git diff`; run tools/check.ps1 and, with the data pack, `python tools/guide_lint.py --strict` and")
    say("                     `python tools/guide_sim.py --check`; then commit")
    return True


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
        late=outcome.plan.late,
        complete=outcome.plan.complete,
        levels={str(l): t for l, t in level_times(outcome.plan).items()},
        legs=[dict(zone=pl.world.geo.name(leg["zone"]) if leg["zone"] is not None else None, seconds=leg["seconds"], levels=[leg["level_in"], leg["level_out"]],
                   hubs=[pl.hubs[h].label for h in leg["hubs"]]) for leg in legs],
        quests_done=sorted(outcome.plan.final.done),
        optional=[dict(quest=q, name=pl.quests[q].name, group=pl.quests[q].group) for q in sorted(outcome.plan.final.done) if pl.quests[q].optional],
        required=[
            dict(quest=q, name=pl.quests[q].name, opens=pl.quests[q].req, level=pl.quests[q].level, done_at=outcome.plan.levels_done().get(q))
            for q in job.required if q in pl.quests
        ],
        required_needed=sorted(pl.required - pl.asked),
        quest_log_limit=pl.s.quest_log_limit,
        quest_log_peak=outcome.plan.log_peak()[0],
        completeness=pl.s.completeness,
        completeness_trip=pl.s.completeness_trip,
        left_out=outcome.plan.stats.get("left_out", []),
        completed=outcome.plan.stats.get("completed", []),
        completed_unplaced=outcome.plan.stats.get("completed_unplaced", []),
        grinds=grinds_of(pl, outcome.plan),
        grains=outcome.plan.stats.get("grains", []),
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
    parser.add_argument("--ferry", type=float, help="minutes for the boat or zeppelin between continents (default: the price the simulation uses too, 7; tools/signpost_tools/pricing.py)")
    parser.add_argument("--hub-radius", type=float, default=150.0, help="yards a hub spans (default 150)")
    parser.add_argument("--class-push", type=float, default=20.0,
                        help="minutes a class quest costs the route for each level it is undone past the level it opens at (default 20)")
    parser.add_argument("--class-grace", type=int, default=0, help="levels past the one it opens at before that cost starts (default 0)")
    parser.add_argument("--group-yards", type=float, default=250.0,
                        help="yards within which neighbouring steps of one kind are written as one: pick up, doing, hand in (default 250)")
    parser.add_argument("--completeness", type=float, default=engine.Settings.completeness, metavar="F",
                        help="finish a quest the route picked up and did not finish, when its objectives are a short walk away (--completeness-trip) and it pays at "
                             "least F times the route's pace in experience per second (0.6: at least 60%%); 0 switches it off, the quest is then taken out and "
                             "listed with the reason (default %(default)g, the user's choice of 2026-10-21; docs/PLANNER.md, Completeness)")
    parser.add_argument("--completeness-trip", type=float, default=engine.Settings.completeness_trip, metavar="SECONDS",
                        help="the longest walk from where a quest was picked up to its objectives, and (unless the route goes there anyway) to where it is "
                             "handed in, that --completeness will make (default %(default)g, the user's choice of 2026-10-21)")
    parser.add_argument("--walk-by-map", action="store_true",
                        help="charge the walk between the places of one hub by the map's distance, not a flat 8 s (Settings.local_walk) for each change of place "
                             "(an experiment: docs/PLANNER.md, Measurements)")
    parser.add_argument("--quest-log", type=int, default=engine.Settings.quest_log_limit, metavar="N",
                        help="quests the log holds at once; no quest is accepted while it is full (default %(default)s: Forever's, confirmed by the user "
                             "in the game; Classic's is 25)")
    parser.add_argument("--chapter-steps", type=int, default=engine.Settings.chapter_min_steps, metavar="N",
                        help="a change of zone starts a new chapter when the new zone lasts at least this many steps once the steps are joined (default %(default)s)")
    parser.add_argument("--threshold", type=float, default=1.0, help="times the grinding rate a quest must give to be kept (default 1)")
    parser.add_argument("--no-skip", action="store_true", help="do not leave out quests for being slower than grinding")
    parser.add_argument("--instant-quests", action="store_true",
                        help="keep quests that have no objective and are handed in where they were accepted (free experience: the data probably lacks them)")
    parser.add_argument("--width", type=int, help="routes the beam keeps for each part of a level (default by technique)")
    parser.add_argument("--parts", type=lambda t: tuple(int(x) for x in t.split(",")), metavar="N[,N...]",
                        help="parts of a level the beam compares routes by, one run for each number (default by technique: beam 2, thorough 2,4,8)")
    parser.add_argument("--branch", type=int, help="hubs tried from each situation (default by technique)")
    parser.add_argument("--horizon", type=int, help="visits a lookahead plays out (default 12)")
    parser.add_argument("--param", action="append", default=[], help="a simulator assumption: name=value or name.part=value")
    parser.add_argument("--exclude", type=int, action="append", default=[], metavar="QUEST", help="never route this quest")
    parser.add_argument("--chain", type=lambda t: [int(x) for x in t.split(",")], action="append", default=[], metavar="Q1,Q2,...",
                        help="quests of a chain the data does not link, in order (the guide manifest's hints are used already)")
    parser.add_argument("--require", type=lambda t: [int(x) for x in t.split(",")], action="append", default=[], metavar="ID[,ID...]",
                        help="quests the route must do whatever they cost, with the quests they need (as the guide's `require` list in tools/drafts.json does): "
                             "never left out for being slow, taken out by the tidy that writes the route, or kept out by a full quest log; an error if one "
                             "cannot be offered to the character (docs/PLANNER.md, Required quests)")
    parser.add_argument("--start", metavar="MAP,X,Y", help="where the character begins (default: the first place the guide sends it to)")
    parser.add_argument("--runs", type=int, default=300, help="Monte Carlo runs for the thorough technique (default 300)")
    parser.add_argument("--seed", type=int, default=1)
    parser.add_argument("--decisions", type=int, default=8, help="changes of zone to explain with alternatives (0: none)")
    parser.add_argument("--steps", type=int, default=25, help="steps of the route to show (0: all)")
    parser.add_argument("--no-check", action="store_true", help="skip writing the route as guide steps and checking it")
    parser.add_argument("--out", type=Path, help="where to write the plan (default plans/<guide>)")
    parser.add_argument("--no-write", action="store_true", help="write nothing to plans/")
    parser.add_argument("--install", action="store_true",
                        help="install the best route that passes its checks as the guide's chapters (the guide file, both TOCs and "
                             "tools/drafts.json change): the step you take on purpose, after reading the report")
    parser.add_argument("--force", action="store_true", help="with --install: also when it would shorten the guide or overwrite uncommitted changes")
    parser.add_argument("--quiet", action="store_true", help="print only the summary")
    parser.add_argument("--root", type=Path, default=REPO_ROOT, help="the Signpost checkout")
    parser.add_argument("--pack", type=Path, help="the data pack folder (default ../Signpost_Data)")
    options = parser.parse_args(argv)
    if options.install:
        if options.no_check:
            parser.error("--install needs the checks (the route must pass them): drop --no-check")
        if not options.guide:
            parser.error("--install needs a guide: python tools/route_planner.py troll --install")
        if options.mode != "auto":
            parser.error("--install: the route has to be planned in the guide's own mode (HARDCORE or normal): drop --mode")
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
    if options.install and not options.force:
        problem = install_problem(job, options)
        if problem:
            out(problem, always=True)
            return 2

    presets = list(PRESETS) if options.preset == "all" else [options.preset]
    try:
        first_pl = planner_for(job, out, quiet=True)
    except engine.RequiredQuestError as error:
        out(str(error), always=True)
        out("(--require, or \"require\" in the guide's entry of tools/drafts.json, names these quests)", always=True)
        return 2
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
    finalists: list[Outcome] = []
    if "thorough" in presets and not options.no_check:
        thorough = next(o for o in outcomes if o.preset == "thorough")
        alternatives = [
            Outcome(f"thorough alt {i}", alt, 0.0, evaluate(job, pls["thorough"], alt, f"alt{i}"))
            for i, alt in enumerate(thorough.plan.alternatives, 1)
        ]
        # every route that was checked meets the same luck: thorough's finalists and the other techniques' routes
        finalists = [thorough, *alternatives, *[o for o in outcomes if o is not thorough and o.evaluation is not None]]
        monte_carlo(job, finalists, options.runs, options.seed)
        thorough.monte = finalists[0].monte
    chosen = choose(outcomes, finalists, job.settings.cap) if options.install else None
    if chosen is not None:
        shown = chosen  # the report describes the route that is installed
    pl = planner_of(pls, shown)
    report_route(out, pl, shown.plan)
    report_time(out, pl, shown.plan)
    report_grinds(out, pl, shown.plan)
    report_quests(out, pl, job, shown.plan)
    if options.decisions and shown.plan.decisions:
        explain_decisions(out, pl, shown.plan, options.decisions)
    if shown.evaluation is not None:
        report_validation(out, pl, shown.plan, shown.evaluation)
        if options.steps >= 0:
            report_steps(out, shown.evaluation, options.steps)
    if finalists:
        report_monte(out, finalists)
    if len(outcomes) > 1:
        report_compare(out, pls, outcomes)
    if not options.no_write and shown.evaluation is not None:
        out_dir = options.out or options.root / "plans" / job.guide.id
        for outcome in outcomes:
            if outcome.evaluation is not None:
                write_outputs(job, outcome, pls[outcome.preset], out_dir, out)
        out.section("FILES")
        out(f"  {out_dir}/<technique>/ holds report.txt, plan.json and the route as guide chapters (Guides/Chapters/*.lua, Guides/Plan.lua)")
        if not options.install:
            out("  nothing was changed in the guides: the chapters are a candidate to read, compare and then install on purpose (--install)")
    if options.install:
        if chosen is None:
            out("", always=True)
            out("not installed: no route passes its checks (it reaches the cap, no availability error, no lint error)", always=True)
            return 1
        if not install_route(job, chosen, out, command_of(argv)):
            return 1
    out("", always=True)
    out(f"{shown.preset}: {hms(shown.plan.seconds)} to level {shown.plan.final.level} under the stated assumptions"
        + (f"; {hms(shown.evaluation.sim.seconds)} when the written route is simulated in full" if shown.evaluation else ""), always=True)
    return 0 if shown.plan.complete else 1


if __name__ == "__main__":
    sys.exit(main())
