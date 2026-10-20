"""Simulate a guide's route: time to each level, per chapter, travel share, respawn waits and level gates (PLAN Phase 9).

    python tools/guide_sim.py                              every guide, every variant
    python tools/guide_sim.py --guide horde-troll-hunter-1-60 --steps
    python tools/guide_sim.py --param kill_seconds=20 --param respawn_seconds.normal=240
    python tools/guide_sim.py --sensitivity                scale each parameter by 0.5 and 2 and report what moves
    python tools/guide_sim.py --skip-quest 788 --skip-quest 5441   what-if: leave quests out, compare time, level and risk
    python tools/guide_sim.py --pace                       compare with the time played recorded in game (Core/Pace.lua)
    python tools/guide_sim.py --json                       machine-readable output

The route is walked as `tools/guide_travel.py --simulate` walks it (zones, flight paths, hearth, a travel clock), and each
step then gets its own time: interacting with an NPC, killing, looting, collecting, using objects. Objectives that need
more kills than there are spawns in reach wait for respawns, with a respawn time per creature kind (normal, elite, rare);
there is no crowding factor (PLAN Phase 9, user ruling 2026-10-20). Quest and kill XP raise the level; a quest that needs a
level the character has not reached stalls the route while it grinds for the missing XP.

Every number is an assumption (tools/sim_params.json): the output compares routes and shows where they spend time, it does
not predict a player's clock. Quest XP comes from the Classic seed in QuestieDB's checkout when the private pack has it
(Forever's XP tuning is unknown), else from a fraction of the level's XP requirement; QuestieDB has no respawn field.
"""

from __future__ import annotations

import argparse
import copy
import json
import math
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import guide_travel  # noqa: E402
from signpost_tools import guidefile  # noqa: E402

REPO_ROOT = Path(__file__).resolve().parent.parent
PARAMS_FILE = REPO_ROOT / "tools" / "sim_params.json"
XP_FILE = Path("cache") / "questiedb" / "support" / "Forever" / "QuestXP" / "xpDB-classic.lua"
_XP_ROW = re.compile(r"\[(\d+)\]\s*=\s*\{\s*(\d+)\s*,\s*(\d+)\s*\}")
# Creature rank (classification) to respawn kind: 0 normal, 1 elite, 2 rare elite, 3 boss, 4 rare.
RANK_KIND = {0: "normal", 1: "elite", 2: "rare", 3: "elite", 4: "rare"}
# Levels from which a creature stops giving XP (the "gray" level) fall this far below the character's level (classic).
ZERO_DIFFERENCE = ((7, 5), (9, 6), (11, 7), (15, 8), (19, 9), (29, 11), (39, 12), (44, 13), (49, 14), (54, 15), (59, 16))


# Parameters ----------------------------------------------------------------------------------------------------------


def load_params(path: Path = PARAMS_FILE, overrides: list[str] | None = None) -> dict:
    params = json.loads(Path(path).read_text(encoding="utf-8"))
    params["xp_to_level"] = {int(level): xp for level, xp in params["xp_to_level"].items()}
    for text in overrides or []:
        key, _, value = text.partition("=")
        if not _:
            raise ValueError(f"--param expects name=value, not {text!r}")
        set_param(params, key.strip(), float(value))
    return params


def set_param(params: dict, key: str, value: float) -> None:
    head, _, tail = key.partition(".")
    if head not in params or head.startswith("_") or head == "xp_to_level":
        raise ValueError(f"unknown parameter {key!r}")
    if tail:
        if not isinstance(params[head], dict) or tail not in params[head]:
            raise ValueError(f"unknown parameter {key!r}")
        params[head][tail] = value
    elif isinstance(params[head], dict):
        raise ValueError(f"{key!r} has parts ({', '.join(params[head])}): name one as {key}.<part>")
    else:
        params[head] = value


def tunable(params: dict) -> list[str]:
    """The parameters a sensitivity run scales: every number, and each respawn time as one group."""
    skip = {"xp_to_level", "over_levelled_gap", "under_levelled_gap", "risk_gap", "quest_xp_penalty_after", "slowest_factor", "fastest_factor"}
    return [key for key, value in params.items() if not key.startswith("_") and key not in skip and isinstance(value, (int, float)) or key == "respawn_seconds"]


def scaled(params: dict, key: str, factor: float) -> dict:
    result = copy.deepcopy(params)
    if key == "respawn_seconds":
        result[key] = {kind: seconds * factor for kind, seconds in result[key].items()}
    else:
        result[key] = result[key] * factor
    return result


def read_quest_xp(pack_dir: Path | None) -> dict[int, int]:
    """Quest XP from QuestieDB's Classic seed (data only: the file is read as text, never run)."""
    if pack_dir is None:
        return {}
    path = Path(pack_dir) / XP_FILE
    if not path.is_file():
        return {}
    return {int(quest): int(xp) for quest, _level, xp in _XP_ROW.findall(path.read_text(encoding="utf-8", errors="replace"))}


# The model ------------------------------------------------------------------------------------------------------------


class Model:
    def __init__(self, params: dict, quests: dict, npcs: dict, items: dict, quest_xp: dict[int, int] | None = None) -> None:
        self.p = params
        self.quests, self.npcs, self.items = quests, npcs, items
        self.quest_xp = quest_xp or {}

    def to_next(self, level: int) -> float:
        table = self.p["xp_to_level"]
        return float(table.get(level, table[max(table)]))

    def level_factor(self, quest_level: int, level: int) -> float:
        """How much slower (more than 1) or faster the quest's mobs are than same-level ones for this character."""
        factor = 1 + self.p["level_diff_slowdown"] * (quest_level - level)
        return min(self.p["slowest_factor"], max(self.p["fastest_factor"], factor))

    def kill_xp(self, mob_level: int, level: int) -> float:
        base = self.p["kill_xp_base"] + self.p["kill_xp_per_level"] * mob_level
        if mob_level >= level:
            return base * (1 + 0.05 * min(mob_level - level, 4))
        gray = next((gap for top, gap in ZERO_DIFFERENCE if level <= top), 17)
        return max(0.0, base * (1 - (level - mob_level) / gray))

    def reward_xp(self, quest_id: int, level: int) -> float:
        record = self.quests.get(quest_id) or {}
        quest_level = record.get("l") or level
        xp = self.quest_xp.get(quest_id)
        if xp is None:
            xp = self.to_next(quest_level) * self.p["quest_xp_fraction_of_level"]
        over = level - quest_level - self.p["quest_xp_penalty_after"]
        if over > 0:
            xp *= max(0.1, 1 - self.p["quest_xp_penalty_per_level"] * over)
        return xp

    def quest_xp_total(self, quest_id: int) -> float:
        """The XP of doing a quest at its own level: the reward plus the kills its objectives need."""
        level = (self.quests.get(quest_id) or {}).get("l") or 1
        return self.reward_xp(quest_id, level) + self.objective(quest_id, None, level)[2]

    def rank_kind(self, npc: int | None) -> str:
        record = self.npcs.get(npc) or {}
        return RANK_KIND.get(record.get("rank", 0), "normal")

    def note_risk(self, result: Result, quest_id: int, level: int) -> None:
        """A hardcore risk mark: a quest whose objective is an elite or rare, or that is well above the character."""
        record = self.quests.get(quest_id) or {}
        quest_level = record.get("l") or level
        if any(
            objective.get("k") == "kill" and self.rank_kind(objective.get("id")) != "normal"
            for objective in record.get("o") or []
        ):
            result.risk.append(("elite", quest_id, quest_level, level))
        elif quest_level - level >= self.p["risk_gap"]:
            result.risk.append(("above", quest_id, quest_level, level))

    def grind_xp_per_second(self, level: int) -> float:
        """Experience per second killing same-level mobs for the missing XP of a level gate."""
        seconds = self.p["kill_seconds"] + self.p["loot_seconds"] + self.p["walk_between_mobs_seconds"] + self.p["grind_overhead_seconds"]
        return self.kill_xp(level, level) / seconds

    def objective(self, quest_id: int, index: int | None, level: int) -> tuple[float, float, float]:
        """(seconds, respawn wait among them, XP) for one objective of a quest at this character level."""
        record = self.quests.get(quest_id) or {}
        objectives = record.get("o") or []
        picks = [objectives[index - 1]] if index and 0 < index <= len(objectives) else objectives
        if not picks:
            picks = [{"k": "kill"}]  # an objective the pack does not describe: assume a few kills
        seconds = wait = xp = 0.0
        quest_level = record.get("l") or level
        factor = self.level_factor(quest_level, level)
        for objective in picks:
            kind = objective.get("k")
            if kind == "item":
                source = (self.items.get(objective.get("id")) or {}).get("drops") or []
                npc = source[0] if source else None
                if source:
                    kills = self.p["default_items"] / max(self.p["drop_rate"], 0.01)
                else:
                    kills = 0.0  # a ground item or a container: collecting it is not a fight
                    seconds += self.p["default_items"] * self.p["object_seconds"]
            elif kind == "kill":
                npc, kills = objective.get("id"), float(self.p["default_kills"])
            elif kind == "object":
                seconds += self.p["object_seconds"] * self.p["default_items"] / 2
                continue
            elif kind == "spell":
                seconds += self.p["spell_seconds"]
                continue
            else:  # explore
                seconds += self.p["explore_seconds"]
                continue
            if kills <= 0:
                continue
            each = (self.p["kill_seconds"] + self.p["loot_seconds"] + self.p["walk_between_mobs_seconds"]) * factor
            known = (self.npcs.get(npc) or {}).get("sp")
            spawns = max(1.0, float(min(known, self.p["spawns_in_reach"]) if known else self.p["spawns_in_reach"]))
            rounds = math.ceil(kills / spawns)
            respawn = self.p["respawn_seconds"][self.rank_kind(npc)]
            waiting = (rounds - 1) * max(0.0, respawn - min(kills, spawns) * each)
            seconds += kills * each + waiting
            wait += waiting
            xp += kills * self.kill_xp(quest_level, level)
        return seconds, wait, xp


# The walk -------------------------------------------------------------------------------------------------------------


@dataclass
class Stall:
    step: guidefile.RouteStep
    reason: str
    needs: int
    seconds: float


@dataclass
class ChapterTime:
    name: str
    levels: tuple[int, int]
    seconds: float = 0.0
    travel: float = 0.0
    wait: float = 0.0
    stall: float = 0.0
    level_in: int = 1
    level_out: int = 1


@dataclass
class Result:
    guide: str
    variant: str
    seconds: float = 0.0
    travel: float = 0.0
    wait: float = 0.0
    stall: float = 0.0
    level: int = 1
    levels: dict[int, tuple[float, str]] = field(default_factory=dict)  # level -> (clock when reached, chapter)
    chapters: list[ChapterTime] = field(default_factory=list)
    stalls: list[Stall] = field(default_factory=list)
    gaps: list[tuple[str, int, int, int]] = field(default_factory=list)  # (kind, quest, quest level, character level)
    steps: list[tuple[str, float, float, int]] = field(default_factory=list)  # (step id, seconds, clock, level)
    todo: int = 0
    risk: list[tuple[str, int, int, int]] = field(default_factory=list)  # (reason, quest, quest level, character level)
    skipped: int = 0


def run(
    route: guidefile.Route,
    world: guide_travel.World,
    model: Model,
    start_level: int | None = None,
    skip: frozenset = frozenset(),
) -> Result:
    """Walk the route; `skip` is a what-if: the quests whose accept, objectives and turn-in are left out."""
    travel = guide_travel.simulate(route, world)
    p = model.p
    first = route.chapters[0].levels[0] if route.chapters else 1
    level = start_level or max(1, first)
    xp = 0.0
    clock = 0.0
    result = Result(route.guide.id, route.variant.label())
    chapters: dict[int, ChapterTime] = {}
    previous = 0.0
    for state in travel.steps:
        rs = state.step
        chapter = chapters.get(rs.chapter)
        if chapter is None:
            source = route.chapters[rs.chapter]
            chapter = chapters[rs.chapter] = ChapterTime(source.name, source.levels, level_in=level, level_out=level)
        walk = max(0.0, state.clock - previous - guide_travel.STEP_SECONDS)
        previous = state.clock
        spent = walk
        waited = 0.0
        gained = 0.0
        needs = 0
        todo = False
        for d in rs.directives:
            if d.args.get("quest") in skip and d.name in ("accept", "turnin", "complete"):
                continue
            if d.name == "todo":
                todo = True
            elif d.name == "level":
                needs = max(needs, d.args["level"])
            elif d.name == "accept":
                record = model.quests.get(d.args["quest"]) or {}
                needs = max(needs, record.get("r") or 0)
        # a step is done together: its objectives run side by side in one area, so the longest wait counts once
        longest_wait = 0.0
        for d in rs.directives:
            if d.args.get("quest") in skip and d.name in ("accept", "turnin", "complete"):
                result.skipped += 1
                continue
            if d.name == "accept":
                model.note_risk(result, d.args["quest"], level)
            if d.name in ("accept", "turnin"):
                spent += p["interact_seconds"]
                if d.name == "turnin":
                    gained += model.reward_xp(d.args["quest"], level)
                    record = model.quests.get(d.args["quest"]) or {}
                    if record.get("l"):
                        gap = record["l"] - level
                        if gap >= p["over_levelled_gap"]:
                            result.gaps.append(("over", d.args["quest"], record["l"], level))
                        elif -gap >= p["under_levelled_gap"]:
                            result.gaps.append(("under", d.args["quest"], record["l"], level))
            elif d.name == "complete":
                seconds, wait, objective_xp = model.objective(d.args["quest"], d.args["objective"], level)
                spent += seconds - wait
                longest_wait = max(longest_wait, wait)
                gained += objective_xp
        spent += longest_wait
        waited += longest_wait
        if todo:
            result.todo += 1
        stalled = 0.0
        if needs > level:
            missing = sum(model.to_next(n) for n in range(level, needs)) - xp
            if missing > 0:
                rate = model.grind_xp_per_second(level)
                stalled = missing / rate
                result.stalls.append(Stall(rs, f"needs level {needs}", needs, stalled))
                xp += missing
        xp += gained * (1 + p["rested_fraction"])
        clock += spent + stalled
        while xp >= model.to_next(level) and level < max(p["xp_to_level"]) + 1:
            xp -= model.to_next(level)
            level += 1
            result.levels[level] = (clock, chapter.name)
        chapter.seconds += spent + stalled
        chapter.travel += walk
        chapter.wait += waited
        chapter.stall += stalled
        chapter.level_out = level
        result.travel += walk
        result.wait += waited
        result.stall += stalled
        result.steps.append((rs.id, spent + stalled, clock, level))
    result.seconds, result.level = clock, level
    result.chapters = [chapters[key] for key in sorted(chapters)]
    return result


# Reports --------------------------------------------------------------------------------------------------------------


def hours(seconds: float) -> str:
    minutes = int(round(seconds / 60))
    return f"{minutes // 60}h{minutes % 60:02d}"


def report(result: Result, with_steps: bool = False) -> list[str]:
    share = result.travel / result.seconds * 100 if result.seconds else 0.0
    out = [
        f"== {result.guide} [{result.variant}]",
        f"   total {hours(result.seconds)} to level {result.level}; travel {share:.0f}%, respawn waits {hours(result.wait)}, "
        f"level-gate grinding {hours(result.stall)}; {result.todo} .todo step(s) cost nothing here",
        "   time to each level: " + ", ".join(f"{level}: {hours(clock)}" for level, (clock, _) in sorted(result.levels.items())),
        "   chapters:",
    ]
    for chapter in result.chapters:
        out.append(
            f"     {chapter.name:<44} {hours(chapter.seconds):>7}  L{chapter.level_in}->{chapter.level_out}  "
            f"travel {hours(chapter.travel)} wait {hours(chapter.wait)} grind {hours(chapter.stall)}"
        )
    if result.stalls:
        out.append(f"   level gates that stalled the route ({len(result.stalls)}):")
        for stall in sorted(result.stalls, key=lambda item: -item.seconds)[:8]:
            out.append(f"     {stall.step.id}: {stall.reason}, {hours(stall.seconds)} of grinding")
    over = [gap for gap in result.gaps if gap[0] == "over"]
    under = [gap for gap in result.gaps if gap[0] == "under"]
    if over:
        out.append("   over-levelled quests (the quest is well above the character): " + ", ".join(f"{q} (L{ql} at L{cl})" for _, q, ql, cl in over[:10]))
    if under:
        out.append("   under-levelled quests (far below the character: little XP): " + ", ".join(f"{q} (L{ql} at L{cl})" for _, q, ql, cl in under[:10]))
    if result.risk:
        out.append(f"   hardcore risk: score {risk_score(result)} ({len(result.risk)} marks; elite = 3, each level above the character beyond the gap = 1):")
        for reason, quest, quest_level, level in sorted(result.risk, key=lambda m: -mark_weight(m))[:8]:
            out.append(f"     {quest}: {reason} (quest L{quest_level} at character L{level})")
    if result.skipped:
        out.append(f"   what-if: {result.skipped} directive(s) of the skipped quests left out")
    if with_steps:
        out.append(f"   {'step':<36} {'minutes':>8} {'clock':>8} level")
        for step_id, seconds, clock, level in result.steps:
            out.append(f"   {step_id:<36} {seconds / 60:>8.1f} {hours(clock):>8} {level:>5}")
    return out


def mark_weight(mark: tuple[str, int, int, int]) -> int:
    reason, _quest, quest_level, level = mark
    return 3 if reason == "elite" else max(1, quest_level - level)


def risk_score(result: Result) -> int:
    return sum(mark_weight(mark) for mark in result.risk)


def what_if(base: Result, variant: Result) -> list[str]:
    delta = variant.seconds - base.seconds
    return [
        f"   what-if against the route as written: {hours(abs(delta))} {'longer' if delta > 0 else 'shorter'} "
        f"({delta / base.seconds * 100:+.1f}%), level {base.level} -> {variant.level}, "
        f"risk {risk_score(base)} -> {risk_score(variant)}"
    ]


def sensitivity(runs: list, params: dict, factors=(0.5, 2.0)) -> list[str]:
    """Scale each parameter and report the change in each route's total, and whether the ranking of routes flips."""
    base = [run_one(*job, params) for job in runs]
    order = [r.guide + r.variant for r in sorted(base, key=lambda r: r.seconds)]
    out = [f"sensitivity: totals at the base parameters: " + ", ".join(f"{r.guide} [{r.variant}] {hours(r.seconds)}" for r in base)]
    for key in tunable(params):
        for factor in factors:
            results = [run_one(*job, scaled(params, key, factor)) for job in runs]
            moved = ", ".join(
                f"{(r.seconds - b.seconds) / b.seconds * 100:+.0f}%" if b.seconds else "n/a" for r, b in zip(results, base)
            )
            ranking = [r.guide + r.variant for r in sorted(results, key=lambda r: r.seconds)]
            flip = "  RANKING FLIPS" if len(runs) > 1 and ranking != order else ""
            out.append(f"  {key} x{factor:g}: {moved}{flip}")
    return out


# Calibration (PLAN Phase 9, stage 3) ----------------------------------------------------------------------------------


def read_pace(source: Path | None = None) -> dict[str, dict[int, float]]:
    """{character: {level: seconds played when it was reached}} from SignpostCharDB.pace (Core/Pace.lua)."""
    from signpost_tools import svfiles

    found: dict[str, dict[int, float]] = {}
    for sv in svfiles.find_files(source):
        if sv.variable != svfiles.CHAR_VAR or not sv.path.is_file():
            continue
        records = svfiles.load_db(sv).get("pace")
        records = records if isinstance(records, dict) else {}
        levels = {
            int(level): float(item["played"])
            for level, item in records.items()
            if isinstance(item, dict) and isinstance(item.get("played"), (int, float)) and str(level).isdigit()
        }
        if levels:
            found[sv.owner] = levels
    return found


def calibrate(result: Result, played: dict[int, float]) -> tuple[list[tuple[int, float, float, float]], float | None]:
    """(level, simulated clock, played, ratio) for the levels both have, and the median ratio: ONE overall pace
    multiplier (more than 1: the player is slower than the model). Levels the character reached before the guide's
    first step (its starting level) are left out."""
    rows = []
    for level, seconds in sorted(played.items()):
        if level in result.levels and result.levels[level][0] > 0:
            clock = result.levels[level][0]
            rows.append((level, clock, seconds, seconds / clock))
    if not rows:
        return rows, None
    ratios = sorted(row[3] for row in rows)
    middle = len(ratios) // 2
    median = ratios[middle] if len(ratios) % 2 else (ratios[middle - 1] + ratios[middle]) / 2
    return rows, median


def calibration_report(result: Result, owner: str, played: dict[int, float]) -> list[str]:
    rows, factor = calibrate(result, played)
    out = [f"   pace of {owner} against {result.guide}:"]
    if not rows:
        return out + ["     no level in common (the character has recorded levels the route does not reach)"]
    for level, clock, seconds, ratio in rows:
        out.append(f"     level {level}: model {hours(clock)}, played {hours(seconds)}, ratio {ratio:.2f}")
    out.append(f"     overall pace multiplier (median of {len(rows)}): {factor:.2f}; the model's times x {factor:.2f}")
    return out


# Command line ---------------------------------------------------------------------------------------------------------


def run_one(route, world, quests, npcs, items, quest_xp, params, skip=frozenset()) -> Result:
    return run(route, world, Model(params, quests, npcs, items, quest_xp), skip=skip)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--root", type=Path, default=REPO_ROOT)
    parser.add_argument("--pack", type=Path)
    parser.add_argument("--params", type=Path, default=PARAMS_FILE, help="the parameters file")
    parser.add_argument("--param", action="append", default=[], help="override one: name=value or name.part=value")
    parser.add_argument("--guide", action="append")
    parser.add_argument("--faction")
    parser.add_argument("--race")
    parser.add_argument("--class", dest="cls")
    parser.add_argument("--profession", action="append", default=[])
    parser.add_argument("--no-tracks", action="store_true")
    parser.add_argument("--no-xp-file", action="store_true", help="ignore QuestieDB's quest XP seed")
    parser.add_argument("--skip-quest", type=int, action="append", default=[], help="what-if: leave this quest out (repeatable)")
    parser.add_argument("--steps", action="store_true", help="list every step's time")
    parser.add_argument(
        "--pace",
        nargs="?",
        const="",
        metavar="DIR",
        help="compare with the time played recorded by Core/Pace.lua (SavedVariables of the dev client, or DIR)",
    )
    parser.add_argument("--sensitivity", action="store_true")
    parser.add_argument("--json", action="store_true")
    options = parser.parse_args(argv)
    guide_travel.safe_stdout()

    project = guidefile.load_project(options.root)
    pack_dir = options.pack or guide_travel.default_pack_dir(options.root)
    pack = guide_travel.load_pack(pack_dir)
    if not pack.present:
        print("guide_sim needs the data pack (quests, positions, maps): " + pack.describe())
        return 1
    try:
        params = load_params(options.params, options.param)
    except (ValueError, OSError) as exc:
        parser.error(str(exc))
    quest_xp = {} if options.no_xp_file else read_quest_xp(pack_dir)
    quests, npcs, items = pack.table("quests"), pack.table("npcs"), pack.table("items")
    worlds: dict[str, guide_travel.World] = {}

    def world_for(faction: str) -> guide_travel.World:
        if faction not in worlds:
            worlds[faction] = guide_travel.World(pack, project.borders, faction)
        return worlds[faction]

    jobs = []
    for gid, guide in sorted(project.guides.items()):
        if options.guide and gid not in options.guide:
            continue
        for route in guide_travel.guide_routes(project, guide, options, world_for):
            jobs.append((route, world_for(route.variant.faction), quests, npcs, items, quest_xp))
    if not jobs:
        print("no guides")
        return 0
    print(pack.describe() + f"; quest XP: {len(quest_xp)} from QuestieDB's Classic seed" if quest_xp else pack.describe() + "; quest XP: estimated from level")
    if options.sensitivity:
        print("\n".join(sensitivity(jobs, params)))
        return 0
    results = [run_one(*job, params) for job in jobs]
    skip = frozenset(options.skip_quest)
    variants = [run_one(*job, params, skip) for job in jobs] if skip else []
    if options.json:
        print(json.dumps([{"guide": r.guide, "variant": r.variant, "seconds": r.seconds, "travel": r.travel, "wait": r.wait,
                           "stall": r.stall, "level": r.level, "levels": {str(k): v[0] for k, v in r.levels.items()}} for r in results], indent=2))
        return 0
    paces = read_pace(Path(options.pace) if options.pace else None) if options.pace is not None else {}
    for number, result in enumerate(results):
        print("\n".join(report(variants[number] if skip else result, options.steps)))
        if skip:
            print("\n".join(what_if(result, variants[number])))
        for owner, played in paces.items():
            print("\n".join(calibration_report(result, owner, played)))
    if options.pace is not None and not paces:
        print("no pace recorded yet (Core/Pace.lua writes SignpostCharDB.pace at each level-up, on /reload or logout)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
