"""Draft a guide chapter from the data pack (PLAN §7, "Quest selection and order"): the bookkeeping, not the judgment.

    python tools/guide_draft.py --race Tauren --class DRUID --zone 1412 --zone 1456 --levels 1-12 \\
        --id mulgore-1-12 --name Mulgore --out Guides/Chapters/mulgore-1-12.lua

Steps, in the order PLAN §7 gives:
  1. the candidate pool: every quest the race, class and faction may take in the zones asked for (masks, side, level,
     not repeatable, no profession requirement), with the reason each other quest was dropped;
  2. the availability rules (tools/signpost_tools/availability.py) decide when a quest may be taken: the level it needs,
     prerequisites and chains (a prerequisite that is another class's or race's quest never counts), quests that close each
     other, quests a quest hands over when it is turned in. A quest whose prerequisites the route never does is not routed;
  3. town loops: from where the walker stands, the nearest place with something to do (accept, turn in, an objective
     area); a step holds what can be done at that one place: one NPC for quests, one area for objectives (kills and
     collecting are steps of their own, never part of an NPC's);
  4. the walker's level is tools/guide_sim.py's: experience from the quests it turns in and the kills it makes. A quest above
     the level the route has asked for gets a `.level N` line before its `.accept`, so the step shows why a quest is not
     offered yet; when nothing can be done until the walker has levelled, a `.level N` step says so.
Treat the order as a first draft: the author reorders, drops and tags.

Group (elite) quests are tagged `.optional` in a normal guide and left out of a HARDCORE one (`--hardcore`, which also
applies the sourced skip list in tools/hardcore_rules.json: each skip becomes a `#skipquest <id> >> <reason>` line, each
note a `.note`). Further quests to leave out are named with --exclude; a hand-picked chapter (the arrival quests of a new race) names the
quests it holds with --only. Travel between zones is not generated here: a `.todo`
marks each zone change, and tools/guide_travel.py proposes the travel steps. Output is DSL for a chapter file
(docs/GUIDE-FORMAT.md). tools/rebuild_drafts.py drafts a whole guide, chapter after chapter, handing each the level,
experience and finished quests of the one before.
"""

from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass, field
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import guide_sim  # noqa: E402
import guide_travel  # noqa: E402
from signpost_tools import availability, guidefile  # noqa: E402
from signpost_tools.availability import CLASS_BITS, CLASS_SORTS, EVENT_SORTS, RACE_BITS  # noqa: E402
from signpost_tools.guidefile import Coord  # noqa: E402

ZONE_STICKINESS = 3000.0  # yards of extra cost for leaving the zone the walker is in, so a zone is finished first
# Forever is not Classic (CLAUDE.md): every drafted chapter says what its source is and is not.
BASELINE_NOTE = (
    "-- Built on the data pack: QuestieDB's Classic-era baseline plus its Forever layers (new quests, zones, class chains). "
    "The layers give IDs, levels and races, not complete objectives or restrictions: docs/FOREVER-API-NOTES.md."
)
SAME_PLACE = 2.0  # map percent: objective areas this close are one place (a few dozen yards in a zone)
NPC_PLACE = 0.35  # map percent: quest givers this close are one NPC's place (a few yards); a step is one NPC
NEAR_BAND = 40.0  # map percent beyond which two places on one map are a trip of their own
MAX_OBJECTIVE_SPOTS = 3  # spawn areas considered per objective
MAX_DROP_SOURCES = 4  # an item with more drop sources than this is pinned at the nearest few only
HARDCORE_NOTE = "HARDCORE: not routed"
PERMANENT = {"locked", "impossible", "faction", "race", "class"}  # availability reasons that do not pass with time


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
    optional: bool = False  # a group (elite) quest in a normal guide: the step does not wait for it


@dataclass
class Draft:
    steps: list[list[str]] = field(default_factory=list)
    notes: list[str] = field(default_factory=list)
    dropped: dict[str, list[int]] = field(default_factory=dict)
    unreachable: list[int] = field(default_factory=list)
    unplaced: list[str] = field(default_factory=list)
    kept: int = 0
    skipped: dict[int, str] = field(default_factory=dict)  # routed out on purpose: quest -> reason
    # where the walk ends, for the next chapter of the guide
    level: int = 1
    xp: float = 0.0
    gated: int = 0  # the highest `.level N` the route has asked for
    done: set[int] = field(default_factory=set)  # every quest turned in, this chapter's and the earlier ones'


LAST: tuple[Draft, argparse.Namespace] | None = None  # the last main() result, for tools/rebuild_drafts.py


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
    quests = pack.table("quests")
    rules = availability.Rules(quests, availability.Character(spec.faction, spec.race_bit, spec.class_bit))
    # the level the walk has when the chapter begins decides which quests are too low to bother with
    floor = max(spec.min_level, getattr(spec, "start_level", None) or 0)
    for qid, record in sorted(quests.items()):
        if not isinstance(record, dict):
            continue

        def drop(reason: str) -> None:
            dropped.setdefault(reason, []).append(qid)

        races, classes = record.get("races"), record.get("classes")
        if not isinstance(classes, int) and record.get("sort") in CLASS_SORTS:
            classes = CLASS_BITS[CLASS_SORTS[record["sort"]]]
        if not guide_travel.usable(guide_travel.side_of(record.get("side")), spec.faction):
            drop("other faction")
        elif isinstance(races, int) and not races & spec.race_bit:
            drop("other race")
        elif isinstance(classes, int) and not classes & spec.class_bit:
            drop("other class")
        elif getattr(spec, "only", None) and qid not in spec.only:
            drop("not named by --only")
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
        elif (record.get("l") or 0) and record["l"] + spec.grey < floor:
            drop("below the level range")
        elif rules.never(qid):
            drop("a prerequisite is closed to this character")
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
                drop("HARDCORE: quest level too far above the chapter")
                continue
            elite = any(_elite_objective(pack, o.kind, o.ident) for o in objectives)
            if spec.hardcore and elite:
                drop("HARDCORE: needs an elite or boss kill")
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
                optional=elite,
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

    rules = availability.Rules(pack.table("quests"), availability.Character(spec.faction, spec.race_bit, spec.class_bit))
    model = guide_sim.make_model(pack)
    progress = guide_sim.Progress(model, getattr(spec, "start_level", None) or spec.min_level, getattr(spec, "start_xp", 0.0))
    gated = getattr(spec, "gated", 0)  # the highest `.level N` the route has asked for so far

    # a chain the pack lacks the links of (new Forever chains): each quest waits for the one before it
    after: dict[int, list[int]] = {}
    for chain in getattr(spec, "chain", None) or []:
        for earlier, later in zip(chain, chain[1:]):
            after.setdefault(later, []).append(earlier)

    done: set[int] = set(spec.done)  # turned in by earlier chapters: not drafted again, and they satisfy prerequisites
    for qid in sorted(done & set(pool)):
        pool.pop(qid)
    active: dict[int, set[int]] = {}  # quest -> objective indexes still open
    gone: set[int] = set()  # quests made unavailable by an exclusive one
    for qid in done:  # a quest an earlier chapter turned in closes the quests that exclude it
        gone.update(other for other in _ids((pack.table("quests").get(qid) or {}).get("exclusive")) if other in pool)
    pos = spec.start
    zone_of = world.geo.zone

    def closed(p: int) -> bool:
        """A quest this character will never do from here: another race's or class's, or closed by an exclusive one."""
        return any(r.code in PERMANENT for r in rules.unmet(p, 99, done, active))

    def waiting(q: Quest) -> bool:
        """A quest that has to come after another one of this route: the quest that hands it over when it is turned in
        (the game stops offering it while that one is in the log), or the one before it in a chain."""
        handed = any(p in pool and p not in done and p not in gone and not closed(p) for p in rules.parents.get(q.id, ()))
        return handed or any(p not in done for p in after.get(q.id, ()))

    def reasons(q: Quest) -> list[str]:
        return [r.code for r in rules.unmet(q.id, progress.level, done, active) if r.severity == "error"]

    def available(q: Quest) -> bool:
        if q.id in done or q.id in active or q.id in gone:
            return False
        return not waiting(q) and not reasons(q)

    def place_of(q: Quest, coords: list[Coord], here: Coord | None) -> Coord | None:
        if not coords:
            return None
        return min(coords, key=lambda c: _near(world, here, c)) if here else coords[0]

    def at(coord: Coord, other: Coord) -> bool:
        return coord.map == other.map and abs(coord.x - other.x) <= SAME_PLACE and abs(coord.y - other.y) <= SAME_PLACE

    def at_npc(coord: Coord, other: Coord) -> bool:
        return coord.map == other.map and abs(coord.x - other.x) <= NPC_PLACE and abs(coord.y - other.y) <= NPC_PLACE

    def line(directive: str, q: Quest, gate: bool = True) -> str:
        text = f"  {directive}"
        if gate:
            text += class_gate(q.class_mask, spec.class_token, spec.gate_class)
        return f"{text} -- {_clean(q.name)}"

    # an objective whose quest is well above the level the walk has reached waits: the first steps of a chapter are not
    # sent to kill level 6 gnolls at level 1 just because they stand near the hub (the margin is off without --hardcore)
    margin = spec.hardcore_over if spec.hardcore else 99

    def soon(q: Quest) -> bool:
        return q.level <= progress.level + margin

    guard = 0
    last_zone = zone_of(pos.map) if pos else None
    while guard < 5000:
        guard += 1
        # what can be done where: (kind rank, place, quest, objective)
        targets: list[tuple[int, Coord, Quest, Objective | None]] = []
        deferred: list[Quest] = []
        for q in pool.values():
            if q.id in active:
                if not active[q.id]:
                    place = place_of(q, q.ends, pos)
                    if place:
                        targets.append((0, place, q, None))
                    else:
                        # the pack does not say where it ends: the step says so, and the quest is turned in all the same
                        result.unplaced.append(f"quest {q.id} ({q.name}): no turn-in position in the pack")
                        reason = _clean(f"{q.name}: the turn-in has no position in the pack")
                        result.steps.append([f'  .todo "{reason}"', line(f".turnin {q.id}", q)])
                        progress.gain(model.reward_xp(q.id, progress.level))
                        active.pop(q.id)
                        done.add(q.id)
                    continue
                if active[q.id] and not soon(q):
                    deferred.append(q)
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
                            progress.gain(model.objective(q.id, objective.index, progress.level)[2])
                            active[q.id].discard(objective.index)
            elif available(q):
                targets.append((1, place_of(q, q.starts, pos), q, None))
        if not targets:
            # nothing to do until the walker has levelled: the quests that wait only for their level, and the objectives
            # of quests still above it, say how far
            by_level = [
                q.required
                for q in pool.values()
                if q.id not in done and q.id not in active and q.id not in gone and not waiting(q) and reasons(q) == ["level"]
            ]
            by_objective = [q.level - margin for q in deferred]
            wanted = [n for n in by_level + by_objective if n > progress.level]
            if wanted and progress.level < spec.max_level:
                target = min(wanted)
                result.notes.append(f"level {target} is needed here (kills and travel between quests): quests wait for it")
                result.steps.append([f"  .level {target} -- reach it first: kill or grind on the way"])
                progress.grind_to(target)
                gated = max(gated, target)
                continue
            break

        def cost(target: tuple[int, Coord, Quest, Objective | None]) -> tuple[float, int]:
            far = _near(world, pos, target[1]) if pos else 0.0
            stay = 0.0 if zone_of(target[1].map) == last_zone else ZONE_STICKINESS
            return far + stay, target[0]

        kind, place = min(targets, key=cost)[:2]
        working = kind == 2  # a step for an objective area: kills and collecting are steps of their own, not part of an NPC's
        step: list[str] = []
        if zone_of(place.map) != last_zone and last_zone is not None:
            result.notes.append(f"travel from {world.label(last_zone)} to {world.label(zone_of(place.map))}: run tools/guide_travel.py")
            result.steps.append([f'  .todo "travel to {_clean(world.label(zone_of(place.map)))}"'])
        last_zone = zone_of(place.map)
        step.append(f"  .goto {place.dsl()}")
        optional_here: dict[int, str] = {}
        # everything doable here, until nothing new turns up (a turn-in can open the next link of a chain)
        while True:
            changed = False
            for q in list(pool.values()):
                if q.id in active and not active[q.id] and any(at_npc(place, e) for e in q.ends):
                    step.append(line(f".turnin {q.id}", q))
                    if q.optional:
                        optional_here[q.id] = q.name
                    progress.gain(model.reward_xp(q.id, progress.level))
                    active.pop(q.id)
                    done.add(q.id)
                    gone.update(x for x in q.exclusive if x in pool)
                    changed = True
            for q in list(pool.values()):
                if available(q) and any(at_npc(place, s) for s in q.starts):
                    if q.required > 1 and q.required > gated:
                        step.append(f"  .level {q.required}")  # the step says why the quest is not offered until then
                        gated = q.required
                    step.append(line(f".accept {q.id}", q))
                    if q.optional:
                        optional_here[q.id] = q.name
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
                    near = at if working else at_npc  # beside an NPC only what is at that NPC (a "talk to" objective)
                    for objective in q.objectives:
                        if objective.index in active[q.id] and any(near(place, s) for s in objective.spots):
                            step.append(line(f".complete {q.id},{objective.index}", q))
                            if q.optional:
                                optional_here[q.id] = q.name
                            progress.gain(model.objective(q.id, objective.index, progress.level)[2])
                            active[q.id].discard(objective.index)
                            changed = True
            if not changed:
                break
        for qid, name in optional_here.items():
            step.append(f"  .optional {qid} -- group quest: {_clean(name)}")
        pos = place
        result.steps.append(step)
    result.unreachable = sorted(q.id for q in pool.values() if q.id not in done and q.id not in active and q.id not in gone)
    for qid in sorted(active):
        result.notes.append(f"quest {qid} ({pool[qid].name}) was accepted but never finished: check its objectives")
    result.level, result.xp, result.gated, result.done = progress.level, progress.xp, gated, done
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
    out = [f"pool: {result.kept} quests; {len(result.steps)} steps; the walk ends at level {result.level}"]
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


def main(argv: list[str] | None = None, carry: dict | None = None) -> int:
    """`carry` is what the chapter before ends with (tools/rebuild_drafts.py): done (quests turned in), level, xp, gated."""
    global LAST
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
    parser.add_argument("--exclude-reason", default=HARDCORE_NOTE, help="the #skipquest reason")
    parser.add_argument(
        "--hardcore",
        nargs="?",
        const=str(Path(__file__).resolve().parent / "hardcore_rules.json"),
        metavar="RULES",
        help="draft a HARDCORE guide, applying the rules (default tools/hardcore_rules.json): skips become #skipquest, "
        "notes become .note; elite quests and quests far above the chapter are left out",
    )
    parser.add_argument(
        "--hardcore-over",
        type=int,
        default=1,
        help="with --hardcore: drop quests whose level is more than this above the chapter's top level (default 1)",
    )
    parser.add_argument("--start-level", type=int, help="the walker's level when the chapter begins (default: the chapter's first level)")
    parser.add_argument("--start-xp", type=float, default=0.0, help="experience into that level")
    parser.add_argument("--gated", type=int, default=0, help="the highest `.level N` the route has asked for before this chapter")
    parser.add_argument("--grey", type=int, default=8, help="drop quests this many levels below the walker (default 8)")
    parser.add_argument(
        "--class-only", action="store_true", help="draft only the quests limited to the class (class quest chapters)"
    )
    parser.add_argument(
        "--done", type=int, action="append", default=[], metavar="QUEST", help="a quest an earlier chapter already routes"
    )
    parser.add_argument(
        "--chain",
        action="append",
        default=[],
        type=lambda text: [int(item) for item in text.split(",")],
        metavar="Q1,Q2,...",
        help="quests of a chain in order, for chains whose links the pack lacks (repeatable)",
    )
    parser.add_argument(
        "--only",
        type=int,
        action="append",
        default=[],
        metavar="QUEST",
        help="draft only these quests (for a hand-picked chapter, e.g. the arrival quests of a new race)",
    )
    parser.add_argument(
        "--note",
        action="append",
        default=[],
        metavar="QUEST=TEXT",
        help="a `.note` after the quest's `.accept` (repeatable), e.g. to mark a route unverified",
    )
    parser.add_argument("--no-gate-class", dest="gate_class", action="store_false", help="no .class gate on class quests")
    parser.add_argument("--pack", type=Path, help="the data pack folder (default ../Signpost_Data)")
    parser.add_argument("--out", type=Path, help="write the chapter file here (default: print)")
    spec = parser.parse_args(argv)
    spec.min_level, spec.max_level = spec.levels
    spec.name = _clean(spec.name)
    spec.skip_reasons = {qid: spec.exclude_reason for qid in spec.exclude}
    spec.notes = {}
    if carry:
        spec.done = sorted(set(spec.done) | set(carry.get("done", ())))
        spec.start_level = spec.start_level or carry.get("level")
        spec.start_xp = spec.start_xp or carry.get("xp", 0.0)
        spec.gated = max(spec.gated, carry.get("gated", 0))
    if spec.hardcore:
        try:
            rules = json.loads(Path(spec.hardcore).read_text(encoding="utf-8")).get("rules", [])
        except (OSError, ValueError) as exc:
            parser.error(f"--hardcore: {exc}")
        for rule in rules:
            if not isinstance(rule, dict) or not isinstance(rule.get("id"), int):
                continue
            if rule.get("action") == "skip":
                spec.skip_reasons.setdefault(rule["id"], str(rule.get("reason") or HARDCORE_NOTE))
            elif rule.get("action") == "note" and rule.get("text"):
                spec.notes[rule["id"]] = str(rule["text"])

    for item in spec.note:
        qid, _, text = item.partition("=")
        if not qid.strip().isdigit() or not text.strip():
            parser.error(f"--note {item!r}: expected QUEST=TEXT")
        spec.notes[int(qid)] = text.strip()

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
    LAST = (result, spec)
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
