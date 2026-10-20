"""Draft a guide chapter from the data pack (PLAN §7, "Quest selection and order"): the bookkeeping, not the judgment.

    python tools/guide_draft.py --race Tauren --class DRUID --zone 1412 --zone 1456 --levels 1-12 \\
        --id mulgore-1-12 --name Mulgore --out Guides/Chapters/mulgore-1-12.lua

Steps, in the order PLAN §7 gives:
  1. the candidate pool: every quest the race, class and faction may take in the zones asked for (masks, side, level,
     not repeatable, no profession requirement), with the reason each other quest was dropped;
  2. prerequisites and chains decide when a quest is available (a prerequisite outside the pool counts as done;
     mutually exclusive quests keep the first one reached);
  3. town loops: from where the walker stands, the nearest place with something to do (accept, turn in, an objective
     area), everything that can be done at that place in one step, until nothing is left;
  4. a placeholder level estimate (one level per --quests-per-level finished quests) keeps required levels met until quest
     XP is in the pack (PLAN §2, "Quest XP"). Treat the order as a first draft: the author reorders, drops and tags.

Group (elite) quests and the hardcore skip list are not in the pack: name them with --exclude (each becomes a
`#skipquest <id> >> <reason>` line) and review the draft. Travel between zones is not generated here: a `.todo` marks each
zone change, and tools/guide_travel.py proposes the travel steps. Output is DSL for a chapter file (docs/GUIDE-FORMAT.md).
"""

from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass, field
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import guide_travel  # noqa: E402
from signpost_tools import guidefile  # noqa: E402
from signpost_tools.guidefile import Coord  # noqa: E402

# The data pack's masks are bit (id - 1) of the client's race and class IDs.
RACE_BITS = {
    "human": 1, "orc": 2, "dwarf": 4, "nightelf": 8, "scourge": 16, "undead": 16, "tauren": 32, "gnome": 64, "troll": 128
}  # fmt: skip
CLASS_BITS = {
    "WARRIOR": 1, "PALADIN": 2, "HUNTER": 4, "ROGUE": 8, "PRIEST": 16, "SHAMAN": 64, "MAGE": 128, "WARLOCK": 256, "DRUID": 1024
}  # fmt: skip
# The pack's `sort` values of seasonal and event quests (the client's quest categories with the sign dropped): Seasonal 22,
# Special 284, Darkmoon Faire 364, Ahn'Qiraj War Effort 365, Lunar Festival 366, Invasion 368, Midsummer 369.
EVENT_SORTS = {22, 284, 364, 365, 366, 368, 369}
# Reasons that make a quest unavailable to the route: a quest that depends on one of these cannot be reached either. The
# other reasons (other race, class or faction, repeatable, a profession skill, grey) count as "done before or irrelevant".
BLOCKING = {
    "above the level range",
    "does not start in the zones",
    "belongs to another zone",
    "turn-in outside the zones (route by hand)",
    "excluded by the author",
    "needs a profession skill",
    "objective lies outside the zones (route by hand)",
    "hardcore: needs an elite or boss kill",
    "hardcore: quest level too far above the chapter",
}
ZONE_STICKINESS = 3000.0  # yards of extra cost for leaving the zone the walker is in, so a zone is finished first
# Forever is not Classic (CLAUDE.md): every drafted chapter says what its source is and is not.
BASELINE_NOTE = (
    "-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). "
    "The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md."
)
SAME_PLACE = 2.0  # map percent: positions this close are one place (a few dozen yards in a zone)
NEAR_BAND = 40.0  # map percent beyond which two places on one map are a trip of their own
MAX_OBJECTIVE_SPOTS = 3  # spawn areas considered per objective
MAX_DROP_SOURCES = 4  # an item with more drop sources than this is pinned at the nearest few only


@dataclass
class Objective:
    index: int  # the quest log's number (from 1): the pack's order, see GUIDE-FORMAT ".complete"
    kind: str  # kill, item, object, explore
    ident: int
    spots: list[Coord] = field(default_factory=list)


@dataclass
class Quest:
    id: int
    name: str
    level: int
    required: int
    starts: list[Coord]
    ends: list[Coord]
    objectives: list[Objective]
    pre_any: list[int]
    pre_all: list[int]
    exclusive: list[int]
    class_mask: int | None
    race_mask: int | None


@dataclass
class Draft:
    steps: list[list[str]] = field(default_factory=list)
    notes: list[str] = field(default_factory=list)
    dropped: dict[str, list[int]] = field(default_factory=dict)
    unreachable: list[int] = field(default_factory=list)
    unplaced: list[str] = field(default_factory=list)
    kept: int = 0
    skipped: dict[int, str] = field(default_factory=dict)  # routed out on purpose: quest -> reason


def _ids(value: object) -> list[int]:
    if isinstance(value, int) and not isinstance(value, bool):
        return [value]
    return [item for item in value or [] if isinstance(item, int) and not isinstance(item, bool)]


def _first_in_zones(coords: list[Coord], world: guide_travel.World, zones: set[int] | None) -> list[Coord]:
    """Coordinates inside the zones asked for (all of them when zones is None)."""
    if zones is None:
        return list(coords)
    inside = [c for c in coords if any(world.within(c.map, zone) for zone in zones)]
    return inside or []


def _spots(coords: list[Coord], world: guide_travel.World, zones: set[int] | None) -> list[Coord]:
    return _first_in_zones(coords, world, zones)[:MAX_OBJECTIVE_SPOTS]


def _objective_spots(
    pack: guide_travel.Pack, world: guide_travel.World, zones: set[int] | None, kind: str, ident: int
) -> list[Coord]:
    table = {"kill": "npcs", "object": "objects"}.get(kind)
    if table:
        record = pack.table(table).get(ident)
        return _spots(guide_travel.coords_of(record.get("p")) if isinstance(record, dict) else [], world, zones)
    if kind == "item":
        record = pack.table("items").get(ident)
        if not isinstance(record, dict):
            return []
        coords: list[Coord] = []
        for source_table, key in (("npcs", "drops"), ("objects", "objDrops")):
            for source in _ids(record.get(key))[: MAX_DROP_SOURCES * 2]:
                entry = pack.table(source_table).get(source)
                coords += _spots(guide_travel.coords_of(entry.get("p")) if isinstance(entry, dict) else [], world, zones)
        return coords
    return []


def _elite_npc(pack: guide_travel.Pack, npc: int) -> bool:
    record = pack.table("npcs").get(npc)
    return isinstance(record, dict) and record.get("rank") in (1, 2, 3)  # elite, rare elite, boss


def _elite_objective(pack: guide_travel.Pack, kind: str, ident: int) -> bool:
    """A kill of an elite, or an item only elites drop: no object gives it either (an NPC the pack does not know counts
    as ordinary)."""
    if kind == "kill":
        return _elite_npc(pack, ident)
    if kind == "item":
        record = pack.table("items").get(ident)
        sources = _ids(record.get("drops")) if isinstance(record, dict) else []
        if not isinstance(record, dict) or record.get("objDrops"):
            return False
        return bool(sources) and all(_elite_npc(pack, source) for source in sources)
    return False


def candidates(pack: guide_travel.Pack, world: guide_travel.World, spec: argparse.Namespace) -> tuple[dict[int, Quest], dict]:
    """The pool, and why the others were dropped (reason -> quest IDs)."""
    zones = set(spec.zone)
    dropped: dict[str, list[int]] = {}
    pool: dict[int, Quest] = {}
    for qid, record in sorted(pack.table("quests").items()):
        if not isinstance(record, dict):
            continue

        def drop(reason: str) -> None:
            dropped.setdefault(reason, []).append(qid)

        races, classes = record.get("races"), record.get("classes")
        if not guide_travel.usable(guide_travel.side_of(record.get("side")), spec.faction):
            drop("other faction")
        elif isinstance(races, int) and not races & spec.race_bit:
            drop("other race")
        elif isinstance(classes, int) and not classes & spec.class_bit:
            drop("other class")
        elif spec.class_only and not isinstance(classes, int):
            drop("not a class quest (--class-only)")
        elif record.get("repeatable"):
            drop("repeatable")
        elif record.get("sort") in EVENT_SORTS:
            drop("seasonal or event")
        elif record.get("skill"):
            drop("needs a profession skill")
        elif (record.get("r") or 0) > spec.max_level:
            drop("above the level range")
        elif (record.get("l") or 0) and record["l"] + spec.grey < spec.min_level:
            drop("below the level range")
        else:
            zone = record.get("zone")
            if isinstance(zone, int) and not any(world.within(zone, wanted) for wanted in zones):
                drop("belongs to another zone")
                continue
            starts = _first_in_zones(world.quest_coords(qid, "s"), world, zones)
            if not starts:
                drop("does not start in the zones")
                continue
            ends = world.quest_coords(qid, "e")
            if ends and not _first_in_zones(ends, world, zones):
                drop("turn-in outside the zones (route by hand)")
                continue
            objectives = []
            outside = False
            for number, objective in enumerate(record.get("o") or [], 1):
                if isinstance(objective, dict) and isinstance(objective.get("id"), int):
                    kind = str(objective.get("k"))
                    spots = _objective_spots(pack, world, zones, kind, objective["id"])
                    if not spots and _objective_spots(pack, world, None, kind, objective["id"]):
                        outside = True  # it exists, but only in another zone
                    objectives.append(Objective(number, kind, objective["id"], spots))
            if outside:
                drop("objective lies outside the zones (route by hand)")
                continue
            if spec.hardcore and (record.get("l") or 0) > spec.max_level + spec.hardcore_over:
                drop("hardcore: quest level too far above the chapter")
                continue
            if spec.hardcore and any(_elite_objective(pack, o.kind, o.ident) for o in objectives):
                drop("hardcore: needs an elite or boss kill")
                continue
            pool[qid] = Quest(
                qid,
                str(record.get("n") or f"quest {qid}"),
                record.get("l") or record.get("r") or 1,
                record.get("r") or 1,
                starts,
                ends,
                objectives,
                _ids(record.get("preSingle")),
                _ids(record.get("preGroup")),
                _ids(record.get("exclusive")),
                classes if isinstance(classes, int) else None,
                races if isinstance(races, int) else None,
            )
    return pool, dropped


def _near(world: guide_travel.World, a: Coord, b: Coord) -> float:
    """Percent-ish distance for ordering: yards on one continent, a large number otherwise."""
    yards = world.geo.distance(a, b)
    if yards is not None:
        return yards
    if a.map == b.map:
        return ((a.x - b.x) ** 2 + (a.y - b.y) ** 2) ** 0.5 * 10
    return 1e6


def class_gate(mask: int | None, class_token: str, gate_class: bool = True) -> str:
    """The `.class` gate for a quest with this class mask, or "" for none: the one class, the few, or all but the few."""
    if mask is None or not gate_class:
        return ""
    names = [name for name, bit in CLASS_BITS.items() if mask & bit]
    if not names or len(names) == len(CLASS_BITS):
        return ""
    if len(names) > len(CLASS_BITS) // 2:
        return " .class " + ",".join("!" + name for name in CLASS_BITS if name not in names)
    return " .class " + ",".join(names)


# The pack's masks for "any Horde race" and "any Alliance race": the Classic races of each side, and with Forever's
# Skyborne bit of that side (1 << 33 Horde, 1 << 32 Alliance; QuestieDB's raceKeys.ALL_HORDE and ALL_ALLIANCE).
FACTION_MASKS = {178, 77, 178 | 1 << 33, 77 | 1 << 32}


def start_place(pool: dict[int, Quest], world: guide_travel.World, spec: argparse.Namespace) -> Coord | None:
    """Where a character of this race begins: the giver of the lowest-level quest only this race gets (its own first quest,
    not a class quest and not one every Horde or Alliance character may take), inside the first zone asked for. Without
    one, the lowest-level quest in that zone; without that, the first quest there is. Starting at the lowest quest ID
    instead sent a character standing in the Valley of Trials to Orgrimmar for a quest that breadcrumbs from there."""
    zone = spec.zone[0]

    def inside(q: Quest) -> list[Coord]:
        return [c for c in q.starts if world.within(c.map, zone)]

    own = [
        q
        for q in pool.values()
        if q.race_mask is not None
        and q.race_mask not in FACTION_MASKS
        and q.class_mask is None
        and q.required <= spec.min_level  # a race-only quest that needs level 3 is a village quest, not the start
        and inside(q)
    ]
    chosen = own or [q for q in pool.values() if inside(q)] or list(pool.values())
    # lowest required level, then lowest quest level (a level-6 quest a village away is not where a level-1 character begins)
    first = min(chosen, key=lambda q: (q.required, q.level, q.id), default=None)
    if first is None:
        return None
    return (inside(first) or first.starts)[0]


def _clean(text: str) -> str:
    return text.replace("]]", "] ]").replace("\n", " ").strip()


def draft(pack: guide_travel.Pack, world: guide_travel.World, spec: argparse.Namespace) -> Draft:
    pool, dropped = candidates(pack, world, spec)
    result = Draft(dropped=dropped)
    for qid in sorted(set(spec.skip_reasons) & set(pool)):
        pool.pop(qid)
        result.skipped[qid] = spec.skip_reasons[qid]
        result.dropped.setdefault("excluded by the author", []).append(qid)
    result.kept = len(pool)
    blocking = {qid for reason in BLOCKING for qid in result.dropped.get(reason, [])}

    done: set[int] = set(spec.done)  # routed by an earlier chapter: not drafted again, and they satisfy prerequisites
    for qid in sorted(done & set(pool)):
        pool.pop(qid)
    active: dict[int, set[int]] = {}  # quest -> objective indexes still open
    gone: set[int] = set()  # quests made unavailable by an exclusive one
    pos = spec.start
    zone_of = world.geo.zone

    assumed = [0]  # levels the walker is assumed to gain beyond the quest estimate when the route stalls on a gate

    def level() -> int:
        return min(spec.max_level, spec.min_level + len(done) // spec.quests_per_level + assumed[0])

    def available(q: Quest) -> bool:
        if q.id in done or q.id in active or q.id in gone or q.required > level():
            return False
        if any((p in pool and p not in done) or p in blocking for p in q.pre_all):
            return False
        if q.pre_any and not any(p in done or (p not in pool and p not in blocking) for p in q.pre_any):
            return False
        return True

    def place_of(q: Quest, coords: list[Coord], here: Coord | None) -> Coord | None:
        if not coords:
            return None
        return min(coords, key=lambda c: _near(world, here, c)) if here else coords[0]

    def at(coord: Coord, other: Coord) -> bool:
        return coord.map == other.map and abs(coord.x - other.x) <= SAME_PLACE and abs(coord.y - other.y) <= SAME_PLACE

    def line(directive: str, q: Quest, gate: bool = True) -> str:
        text = f"  {directive}"
        if gate:
            text += class_gate(q.class_mask, spec.class_token, spec.gate_class)
        return f"{text} -- {_clean(q.name)}"

    # an objective whose quest is well above the level the walk has reached waits: the first steps of a chapter are not
    # sent to kill level 6 gnolls at level 1 just because they stand near the hub (the margin is off without --hardcore)
    margin = spec.hardcore_over if spec.hardcore else 99

    def soon(q: Quest) -> bool:
        return q.level <= level() + margin

    guard = 0
    last_zone = zone_of(pos.map) if pos else None
    while guard < 5000:
        guard += 1
        # what can be done where: (kind rank, place, quest, objective)
        targets: list[tuple[int, Coord, Quest, Objective | None]] = []
        deferred = False
        for q in pool.values():
            if q.id in active:
                if not active[q.id]:
                    place = place_of(q, q.ends, pos)
                    if place:
                        targets.append((0, place, q, None))
                    else:
                        result.unplaced.append(f"quest {q.id} ({q.name}): no turn-in position in the pack")
                        active.pop(q.id)
                        done.add(q.id)
                    continue
                if active[q.id] and not soon(q):
                    deferred = True
                    continue
                for objective in q.objectives:
                    if objective.index in active[q.id]:
                        place = place_of(q, objective.spots, pos)
                        if place:
                            targets.append((2, place, q, objective))
                        else:
                            what = f"{objective.kind} {objective.ident}"
                            result.unplaced.append(f"quest {q.id} ({q.name}) objective {objective.index} ({what}): no position")
                            reason = _clean(f"{q.name}: objective {objective.index} ({what}) has no position in the pack")
                            result.steps.append([f'  .todo "{reason}"', f"  .complete {q.id},{objective.index} -- {_clean(q.name)}"])
                            active[q.id].discard(objective.index)
            elif available(q):
                targets.append((1, place_of(q, q.starts, pos), q, None))
        if not targets:
            gated = [q for q in pool.values() if q.id not in done and q.id not in active and q.id not in gone and q.required > level()]
            if (gated or deferred) and level() < spec.max_level:
                assumed[0] += 1
                result.notes.append(f"level {level()} assumed here (kills and travel between quests): quests need it")
                result.steps.append([f"  .level {level()} -- assumed: grind or kill on the way until then"])
                continue
            break
        def cost(target: tuple[int, Coord, Quest, Objective | None]) -> tuple[float, int]:
            far = _near(world, pos, target[1]) if pos else 0.0
            stay = 0.0 if zone_of(target[1].map) == last_zone else ZONE_STICKINESS
            return far + stay, target[0]

        place = min(targets, key=cost)[1]
        step: list[str] = []
        if zone_of(place.map) != last_zone and last_zone is not None:
            result.notes.append(f"travel from {world.label(last_zone)} to {world.label(zone_of(place.map))}: run tools/guide_travel.py")
            result.steps.append([f'  .todo "travel to {_clean(world.label(zone_of(place.map)))}"'])
        last_zone = zone_of(place.map)
        step.append(f"  .goto {place.dsl()}")
        # everything doable here, until nothing new turns up (a turn-in can open the next link of a chain)
        while True:
            changed = False
            for q in list(pool.values()):
                if q.id in active and not active[q.id] and any(at(place, e) for e in q.ends):
                    step.append(line(f".turnin {q.id}", q))
                    active.pop(q.id)
                    done.add(q.id)
                    gone.update(x for x in q.exclusive if x in pool)
                    changed = True
            for q in list(pool.values()):
                if available(q) and any(at(place, s) for s in q.starts):
                    step.append(line(f".accept {q.id}", q))
                    if q.id in spec.notes:
                        step.append(f"  .note {_clean(spec.notes[q.id])}")
                    active[q.id] = {o.index for o in q.objectives}
                    for other in q.exclusive:
                        if other in pool and other not in done and other not in active:
                            gone.add(other)
                            result.skipped.setdefault(other, f"alternative to quest {q.id}, which is routed")
                            result.notes.append(f"quest {other} is exclusive with {q.id}; {q.id} was routed")
                    changed = True
            for q in list(pool.values()):
                if q.id in active and soon(q):
                    for objective in q.objectives:
                        if objective.index in active[q.id] and any(at(place, s) for s in objective.spots):
                            step.append(line(f".complete {q.id},{objective.index}", q))
                            active[q.id].discard(objective.index)
                            changed = True
            if not changed:
                break
        pos = place
        result.steps.append(step)
    result.unreachable = sorted(q.id for q in pool.values() if q.id not in done and q.id not in active and q.id not in gone)
    for qid in sorted(active):
        result.notes.append(f"quest {qid} ({pool[qid].name}) was accepted but never finished: check its objectives")
    return result


def render(result: Draft, spec: argparse.Namespace, pool_names: dict[int, str]) -> str:
    levels = f"{spec.min_level}-{spec.max_level}"
    lines = [f"#chapter {levels} {spec.name}"]
    for qid, reason in sorted(result.skipped.items()):
        lines.append(f"#skipquest {qid} >> {_clean(reason)}")
    for step in result.steps:
        lines.append("step")
        lines.extend(step)
    return "\n".join(lines) + "\n"


def lua_file(chapter_id: str, text: str, header: list[str]) -> str:
    comments = "\n".join(f"-- {line}" for line in header)
    draft = "-- DRAFT: generated by tools/guide_draft.py; review, reorder and tag before it ships.\n"
    draft += f"{BASELINE_NOTE}\n"
    return f'{draft}{comments}\nlocal ADDON_NAME, ns = ...\n\nns.Chapters:Register("{chapter_id}", [[\n{text}]])\n'


def summary(result: Draft, spec: argparse.Namespace) -> list[str]:
    out = [f"pool: {result.kept} quests; {len(result.steps)} steps"]
    for reason, ids in sorted(result.dropped.items()):
        out.append(f"dropped {len(ids)}: {reason}")
    if result.unreachable:
        out.append(f"never available ({len(result.unreachable)}): {', '.join(map(str, result.unreachable[:30]))}")
    out += [f"unplaced: {item}" for item in result.unplaced[:30]]
    out += result.notes[:30]
    return out


def _levels(text: str) -> tuple[int, int]:
    low, _, high = text.partition("-")
    try:
        return int(low), int(high or low)
    except ValueError:
        raise argparse.ArgumentTypeError("levels are N or N-M")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--race", required=True, help="raceFile token (Tauren, Troll, Orc, Scourge, Skyborne ...)")
    parser.add_argument("--race-bit", type=int, help="the pack's race mask bit, for a race this tool does not know")
    parser.add_argument("--class", dest="class_token", required=True, help="classFile token (DRUID, HUNTER ...)")
    parser.add_argument("--faction", default="Horde", help="Horde or Alliance (default Horde)")
    parser.add_argument("--zone", type=int, action="append", required=True, help="uiMapID of a zone to draft (repeatable)")
    parser.add_argument("--levels", type=_levels, required=True, help="N-M")
    parser.add_argument("--start", help="where the walker starts, map,x,y (default: the first quest giver)")
    parser.add_argument("--id", dest="chapter_id", required=True, help="chapter id (lowercase letters, digits, -)")
    parser.add_argument("--name", required=True, help="chapter name")
    parser.add_argument("--exclude", type=int, action="append", default=[], metavar="QUEST", help="never route this quest")
    parser.add_argument("--exclude-reason", default="hardcore: not routed", help="the #skipquest reason")
    parser.add_argument(
        "--hardcore",
        nargs="?",
        const=str(Path(__file__).resolve().parent / "hardcore_rules.json"),
        metavar="RULES",
        help="apply the hardcore rules (default tools/hardcore_rules.json): skips become #skipquest, notes become .note",
    )
    parser.add_argument(
        "--hardcore-over",
        type=int,
        default=1,
        help="with --hardcore: drop quests whose level is more than this above the chapter's top level (default 1)",
    )
    parser.add_argument("--quests-per-level", type=int, default=5, help="placeholder level estimate (default 5)")
    parser.add_argument("--grey", type=int, default=8, help="drop quests this many levels below the range (default 8)")
    parser.add_argument(
        "--class-only", action="store_true", help="draft only the quests limited to the class (class quest chapters)"
    )
    parser.add_argument(
        "--done", type=int, action="append", default=[], metavar="QUEST", help="a quest an earlier chapter already routes"
    )
    parser.add_argument("--no-gate-class", dest="gate_class", action="store_false", help="no .class gate on class quests")
    parser.add_argument("--pack", type=Path, help="the data pack folder (default ../Signpost_Data)")
    parser.add_argument("--out", type=Path, help="write the chapter file here (default: print)")
    spec = parser.parse_args(argv)
    spec.min_level, spec.max_level = spec.levels
    spec.name = _clean(spec.name)
    spec.skip_reasons = {qid: spec.exclude_reason for qid in spec.exclude}
    spec.notes = {}
    if spec.hardcore:
        try:
            rules = json.loads(Path(spec.hardcore).read_text(encoding="utf-8")).get("rules", [])
        except (OSError, ValueError) as exc:
            parser.error(f"--hardcore: {exc}")
        for rule in rules:
            if not isinstance(rule, dict) or not isinstance(rule.get("id"), int):
                continue
            if rule.get("action") == "skip":
                spec.skip_reasons.setdefault(rule["id"], str(rule.get("reason") or "hardcore: not routed"))
            elif rule.get("action") == "note" and rule.get("text"):
                spec.notes[rule["id"]] = str(rule["text"])

    bit = spec.race_bit or RACE_BITS.get(spec.race.lower())
    if not bit:
        parser.error(f"unknown race {spec.race!r}: pass --race-bit (the pack's mask bit for it)")
    if spec.class_token.upper() not in CLASS_BITS:
        parser.error(f"unknown class {spec.class_token!r}")
    spec.race_bit, spec.class_bit = bit, CLASS_BITS[spec.class_token.upper()]
    spec.class_token = spec.class_token.upper()
    guide_travel.safe_stdout()

    pack_dir = spec.pack or guide_travel.default_pack_dir(Path(__file__).resolve().parent.parent)
    pack = guide_travel.load_pack(pack_dir)
    if not pack.present or not pack.has("quests"):
        print(f"guide_draft: no data pack with quests ({pack.describe()})", file=sys.stderr)
        return 1
    world = guide_travel.World(pack, faction=spec.faction)
    if spec.start:
        try:
            m, x, y = spec.start.split(",")
            spec.start = Coord(int(m), float(x), float(y))
        except ValueError:
            parser.error("--start is map,x,y")
    result = None
    pool, _ = candidates(pack, world, spec)
    if not spec.start:
        spec.start = start_place(pool, world, spec)
    if spec.start is None:
        print("guide_draft: no quest in the pool to start from", file=sys.stderr)
        return 1
    result = draft(pack, world, spec)
    text = render(result, spec, {q.id: q.name for q in pool.values()})
    header = summary(result, spec)
    for item in header:
        print(f"guide_draft: {item}", file=sys.stderr)
    if spec.out:
        spec.out.parent.mkdir(parents=True, exist_ok=True)
        spec.out.write_text(lua_file(spec.chapter_id, text, header), encoding="utf-8", newline="\n")
        print(f"wrote {spec.out}", file=sys.stderr)
    else:
        print(text, end="")
    return 0


if __name__ == "__main__":
    sys.exit(main())
