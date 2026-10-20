"""The data pack's learned layer (PLAN §6 step 7): what Core/Learn.lua recorded in SignpostDB.learned, plus the NPC
positions and zone crossings the /signpost debug recorder kept in SignpostDB.eventLog.

`learned_layer` turns SignpostDB tables (one per SavedVariables source) into layer tables in the pack's schema
(Data/Schema.lua): NPC and object positions ({ uiMapID, x, y }; sightings averaged into up to three spots), quest
givers and enders, flight masters, walked zone crossings, the vendors of items the route uses and the trainers of each
profession. `merge_learned` writes them as layers/learned.json. datapack.build merges that layer last, so learned
positions override the other sources; links (quest givers and enders, vendors, trainers) are written together with
what the other layers already know, so learning one never drops another.

Only IDs, the names of NPCs, objects and flight nodes, and coordinates. A player's or pet's GUID is skipped before its
name is looked at, and nothing about an item is kept but which vendors sell it, and only for the items the route
touches: items the other layers know (quest starters and objectives), profession reagents, and the items guide steps
buy or collect.
"""

from __future__ import annotations

import json
import math
import re
from pathlib import Path

from . import datapack

# GUID kinds that name a world entity (as Core/Learn.lua); players and pets are never read.
ENTITY_TABLES = {"Creature": "npcs", "Vehicle": "npcs", "GameObject": "objects"}
SAME_SPOT = 1.0  # map percent: sightings this close are one spot
MAX_SPOTS = 3  # spots kept per NPC or object
CROSSING_SPOT = 1.5  # map percent: crossings whose two ends are this close are one crossing
CROSSING_MAX_AGE = 5.0  # seconds between the last position in the old zone and the first in the new one
MAX_GROUND_SPEED = 16.0  # yards a second; more is a flight, a transport, a teleport or a loading screen
CONTINENT = 2  # Enum.UIMapType: crossings are between maps below continents
SIDES = {0: "both", 1: "Horde", 2: "Alliance"}  # the taxi API's faction numbers -> Data/Schema.lua `side`
_ROUTE_ITEM = re.compile(r"(?:^|\s)\.(?:buy|collect)\s+(\d+)")

Point = tuple[int, float, float]


# Values -------------------------------------------------------------------------------------------------------------


def _number(value: object) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)


def _id(value: object) -> int | None:
    if isinstance(value, bool):
        return None
    if isinstance(value, float) and value.is_integer():
        value = int(value)
    if isinstance(value, str) and value.isdigit():
        value = int(value)
    return value if isinstance(value, int) and value > 0 else None


def _round(value: float) -> float:
    """Two decimals, halves up, as Core/Util.lua's Util.Round."""
    return math.floor(value * 100 + 0.5) / 100


def _keyed(value: object) -> dict:
    """A Lua table keyed by ID (the SavedVariables parser makes a list of one whose keys happen to be 1..n)."""
    if isinstance(value, dict):
        return value
    if isinstance(value, list):
        return {index + 1: item for index, item in enumerate(value)}
    return {}


def _listed(value: object) -> list:
    """A Lua array (an empty one parses as a dict)."""
    if isinstance(value, list):
        return value
    if isinstance(value, dict):
        return [value[key] for key in sorted(k for k in value if isinstance(k, int))]
    return []


def _ids(value: object) -> list[int]:
    return [ident for ident in (_id(item) for item in _listed(value)) if ident]


def _when(value: object) -> float:
    return float(value) if _number(value) else 0.0


def _point(record: object) -> Point | None:
    """(uiMapID, x, y) from a record with map/x/y fields (x and y in map percent)."""
    if not isinstance(record, dict):
        return None
    map_id, x, y = _id(record.get("map")), record.get("x"), record.get("y")
    if map_id and _number(x) and _number(y) and 0 <= x <= 100 and 0 <= y <= 100:
        return map_id, float(x), float(y)
    return None


def _learned(db: dict) -> dict:
    value = db.get("learned")
    return value if isinstance(value, dict) else {}


def _with(learned_ids: set[int] | list[int], known: object) -> list[int]:
    """Learned IDs first (ascending), then the ones the other layers know, each once."""
    result = sorted(set(learned_ids))
    result += [ident for ident in _ids(known) if ident not in result]
    return result


def entity(guid: object) -> tuple[str, int] | None:
    """("npcs" | "objects", id) for a creature, vehicle or game object GUID; None for players, pets and the rest."""
    if not isinstance(guid, str):
        return None
    parts = guid.split("-")
    if len(parts) < 6 or parts[0] not in ENTITY_TABLES:
        return None
    ident = _id(parts[5])
    return (ENTITY_TABLES[parts[0]], ident) if ident else None


# Positions ----------------------------------------------------------------------------------------------------------


def cluster(points: list[tuple[int, float, float, float]], radius: float = SAME_SPOT, limit: int = MAX_SPOTS) -> list:
    """Weighted mean positions of sightings within `radius` map percent of each other, the most seen spot first."""
    spots: list[list] = []  # [map, sum x, sum y, weight]
    for map_id, x, y, weight in sorted(points, key=lambda p: (-p[3], p[0], p[1], p[2])):
        for spot in spots:
            if spot[0] == map_id and math.hypot(spot[1] / spot[3] - x, spot[2] / spot[3] - y) <= radius:
                spot[1] += x * weight
                spot[2] += y * weight
                spot[3] += weight
                break
        else:
            spots.append([map_id, x * weight, y * weight, weight])
    spots.sort(key=lambda s: (-s[3], s[0], s[1] / s[3], s[2] / s[3]))
    return [[s[0], _round(s[1] / s[3]), _round(s[2] / s[3])] for s in spots[:limit]]


class _Sightings:
    def __init__(self) -> None:
        self.points: dict[tuple[str, int], list] = {}
        self.names: dict[tuple[str, int], tuple[float, str]] = {}

    def add(self, key: tuple[str, int], point: Point, weight: float, name: object, when: float) -> None:
        self.points.setdefault(key, []).append((*point, weight))
        if isinstance(name, str) and name and (key not in self.names or when >= self.names[key][0]):
            self.names[key] = (when, name)

    def tables(self) -> dict[str, dict]:
        tables: dict[str, dict] = {"npcs": {}, "objects": {}}
        for key, points in sorted(self.points.items()):
            record: dict[str, object] = {"p": cluster(points)}
            if key in self.names:
                record["n"] = self.names[key][1]
            tables[key[0]][key[1]] = record
        return tables


def _sightings(dbs: list[dict]) -> _Sightings:
    sightings = _Sightings()
    for db in dbs:
        learned = _learned(db)
        for table in ("npcs", "objects"):
            for ident, record in _keyed(learned.get(table)).items():
                ident, point = _id(ident), _point(record)
                if ident and point:
                    weight = _id(record.get("c")) or 1
                    sightings.add((table, ident), point, weight, record.get("n"), _when(record.get("t")))
        for entry in _listed(db.get("eventLog")):
            snapshot = entry.get("s") if isinstance(entry, dict) else None
            npc = snapshot.get("npc") if isinstance(snapshot, dict) else None
            if not isinstance(npc, dict):
                continue
            key, point = entity(npc.get("guid")), _point(npc.get("pos"))
            if key and point:
                sightings.add(key, point, 1, npc.get("name"), _when(entry.get("time")))
    return sightings


# Zone crossings -----------------------------------------------------------------------------------------------------


def _continental(map_id: int, maps: dict) -> bool:
    kind = (maps.get(map_id) or {}).get("t")
    return _number(kind) and kind <= CONTINENT


def walked(prev: object, pos: object, maps: dict) -> tuple[Point, Point] | None:
    """The two ends of a crossing from a recorder snapshot (last position in the old zone, first in the new one), if
    the border was walked: recent, in the same world, close enough for a run or ride, not on a taxi or in an instance.
    (The recorder has no speed reading, so unlike Core/Learn.lua it cannot tell a slow boat from a ride.)"""
    if not (isinstance(prev, dict) and isinstance(pos, dict)):
        return None
    a, b = _point(prev), _point(pos)
    if not (a and b) or a[0] == b[0]:
        return None
    if prev.get("taxi") or pos.get("taxi") or any(p.get("instanceType") not in (None, "none") for p in (prev, pos)):
        return None
    if not (_number(prev.get("t")) and _number(pos.get("t"))):
        return None
    elapsed = pos["t"] - prev["t"]
    if not 0 <= elapsed <= CROSSING_MAX_AGE or prev.get("instance") != pos.get("instance"):
        return None
    if not all(_number(p.get(k)) for p in (prev, pos) for k in ("wx", "wy")):
        return None
    if math.hypot(pos["wx"] - prev["wx"], pos["wy"] - prev["wy"]) > MAX_GROUND_SPEED * max(elapsed, 1.0):
        return None
    if _continental(a[0], maps) or _continental(b[0], maps):
        return None
    return a, b


def _crossing_samples(dbs: list[dict], maps: dict) -> list[tuple[Point, Point, float]]:
    samples = []
    for db in dbs:
        for crossing in _listed(_learned(db).get("crossings")):
            if not isinstance(crossing, dict):
                continue
            a, b = _point(crossing.get("from")), _point(crossing.get("to"))
            if a and b and a[0] != b[0] and not (_continental(a[0], maps) or _continental(b[0], maps)):
                samples.append((a, b, float(_id(crossing.get("c")) or 1)))
        for entry in _listed(db.get("eventLog")):
            if not isinstance(entry, dict) or entry.get("e") != "ZONE_CHANGED_NEW_AREA":
                continue
            snapshot = entry.get("s")
            ends = walked(snapshot.get("prev"), snapshot.get("pos"), maps) if isinstance(snapshot, dict) else None
            if ends:
                samples.append((*ends, 1.0))
    return samples


def crossings(samples: list[tuple[Point, Point, float]], maps: dict) -> list[dict]:
    """One crossing per border spot. Walking A->B and B->A over the same spot is one crossing, kept with `from` on the
    lower uiMapID; ends are weighted means. Named "<map>/<map>" when the maps table knows both names."""
    oriented = [(a, b, w) if a[0] < b[0] else (b, a, w) for a, b, w in samples]
    groups: list[list] = []  # [map a, map b, sum ax, sum ay, sum bx, sum by, weight]
    for a, b, weight in sorted(oriented, key=lambda s: (-s[2], s[0], s[1])):
        for g in groups:
            if (
                g[0] == a[0]
                and g[1] == b[0]
                and math.hypot(g[2] / g[6] - a[1], g[3] / g[6] - a[2]) <= CROSSING_SPOT
                and math.hypot(g[4] / g[6] - b[1], g[5] / g[6] - b[2]) <= CROSSING_SPOT
            ):
                g[2] += a[1] * weight
                g[3] += a[2] * weight
                g[4] += b[1] * weight
                g[5] += b[2] * weight
                g[6] += weight
                break
        else:
            groups.append([a[0], b[0], a[1] * weight, a[2] * weight, b[1] * weight, b[2] * weight, weight])
    result = []
    for g in sorted(groups, key=lambda g: (g[0], g[1], g[2] / g[6], g[3] / g[6])):
        crossing: dict[str, object] = {
            "from": [g[0], _round(g[2] / g[6]), _round(g[3] / g[6])],
            "to": [g[1], _round(g[4] / g[6]), _round(g[5] / g[6])],
            "src": "learned",
        }
        names = [(maps.get(m) or {}).get("n") for m in (g[0], g[1])]
        if all(isinstance(name, str) and name for name in names):
            crossing["name"] = "/".join(names)
        result.append(crossing)
    return result


# Links --------------------------------------------------------------------------------------------------------------


def _quests(dbs: list[dict], known: dict) -> dict[int, dict]:
    links: dict[int, dict[str, dict[str, set[int]]]] = {}
    for db in dbs:
        for quest_id, record in _keyed(_learned(db).get("quests")).items():
            quest_id = _id(quest_id)
            if not (quest_id and isinstance(record, dict)):
                continue
            for part, field in (("start", "s"), ("finish", "e")):
                who = record.get(part)
                for kind in ("npc", "obj") if isinstance(who, dict) else ():
                    ident = _id(who.get(kind))
                    if ident:
                        links.setdefault(quest_id, {}).setdefault(field, {}).setdefault(kind, set()).add(ident)
    quests = {}
    for quest_id, fields in sorted(links.items()):
        record = {}
        for field, kinds in fields.items():
            base = (known.get(quest_id) or {}).get(field)
            merged = dict(base) if isinstance(base, dict) else {}
            for kind, ids in kinds.items():
                merged[kind] = _with(ids, merged.get(kind))
            record[field] = merged
        quests[quest_id] = record
    return quests


def route_items(base: dict, guide_dirs: list[Path]) -> set[int]:
    """The items the route touches: those the other layers hold, profession reagents, and `.buy`/`.collect` items."""
    items = {ident for ident in (_id(key) for key in base.get("items") or {}) if ident}
    for profession in (base.get("professions") or {}).values():
        recipes = profession.get("recipes") if isinstance(profession, dict) else None
        for recipe in recipes.values() if isinstance(recipes, dict) else ():
            reagents = recipe.get("reagents") if isinstance(recipe, dict) else None
            items.update(ident for ident in (_id(key) for key in reagents or {}) if ident)
    for folder in guide_dirs:
        for path in sorted(Path(folder).rglob("*.lua")) if Path(folder).is_dir() else ():
            text = path.read_text(encoding="utf-8", errors="replace")
            items.update(int(match) for match in _ROUTE_ITEM.findall(text))
    return items


def _vendors(dbs: list[dict], known: dict, route: set[int]) -> tuple[dict[int, dict], int]:
    """items[itemID].vendors for the route's items; also how many learned item IDs the route does not touch."""
    sellers: dict[int, set[int]] = {}
    outside: set[int] = set()
    for db in dbs:
        for npc, record in _keyed(_learned(db).get("vendors")).items():
            npc = _id(npc)
            if not (npc and isinstance(record, dict)):
                continue
            for item in _ids(record.get("items")):
                if item in route:
                    sellers.setdefault(item, set()).add(npc)
                else:
                    outside.add(item)
    items = {
        item: {"vendors": _with(npcs, (known.get(item) or {}).get("vendors"))} for item, npcs in sorted(sellers.items())
    }
    return items, len(outside)


def _trainers(dbs: list[dict], known: dict) -> tuple[dict[int, dict], list[str]]:
    """professions[skillLine].trainers: by the skill line Core/Learn.lua read at the trainer, else by recipes."""
    learned: dict[int, dict[str, set[int]]] = {}
    for db in dbs:
        for npc, record in _keyed(_learned(db).get("trainers")).items():
            npc = _id(npc)
            if not (npc and isinstance(record, dict)):
                continue
            entry = learned.setdefault(npc, {"spells": set(), "skills": set()})
            entry["spells"].update(_ids(record.get("spells")))
            if _id(record.get("skill")):
                entry["skills"].add(_id(record.get("skill")))
    recipes = {}
    for skill_line, profession in known.items():
        table = profession.get("recipes") if isinstance(profession, dict) else None
        recipes[skill_line] = {ident for ident in (_id(key) for key in table or {}) if ident}
    teachers: dict[int, set[int]] = {}
    problems = []
    for npc, entry in sorted(learned.items()):
        skills = entry["skills"] or {line for line, spells in recipes.items() if spells & entry["spells"]}
        if not skills:
            problems.append(
                f"learned trainer {npc} ({len(entry['spells'])} services): no profession in the pack teaches them "
                "(class trainers wait for the classes table)"
            )
        for skill_line in skills:
            teachers.setdefault(skill_line, set()).add(npc)
    professions = {
        line: {"trainers": _with(npcs, (known.get(line) or {}).get("trainers"))}
        for line, npcs in sorted(teachers.items())
    }
    return professions, problems


def _flight_masters(dbs: list[dict]) -> tuple[dict[int, dict], list[str]]:
    """travel.flightMasters from learned flight nodes: the most recent node per flight master."""
    latest: dict[int, tuple[float, dict]] = {}
    problems = set()
    for db in dbs:
        taxi = _learned(db).get("taxi")
        for name, record in (taxi.items() if isinstance(taxi, dict) else ()):
            point = _point(record)
            if not (isinstance(name, str) and name and point):
                continue
            npc = _id(record.get("npc"))
            if not npc:
                problems.add(f"flight node {name!r}: learned without its flight master's NPC ID")
                continue
            entry: dict[str, object] = {"node": name, "p": list(point)}
            faction = record.get("faction")
            if isinstance(faction, int) and not isinstance(faction, bool) and faction in SIDES:
                entry["side"] = SIDES[faction]
            when = _when(record.get("t"))
            if npc not in latest or when >= latest[npc][0]:
                latest[npc] = (when, entry)
    return {npc: entry for npc, (_, entry) in sorted(latest.items())}, sorted(problems)


# The layer ----------------------------------------------------------------------------------------------------------


def learned_layer(dbs: list[dict], base: dict, guide_dirs: list[Path] = ()) -> tuple[dict, list[str], dict[str, int]]:
    """Layer tables, problems and counts from SignpostDB tables. `base` is the merge of the other layers
    (datapack.merge_layers), for the links learned ones are added to, map names and types, and the route's items."""
    maps = base.get("maps") or {}
    tables = _sightings(dbs).tables()
    tables["quests"] = _quests(dbs, base.get("quests") or {})
    tables["items"], outside = _vendors(dbs, base.get("items") or {}, route_items(base, list(guide_dirs)))
    tables["professions"], trainer_problems = _trainers(dbs, base.get("professions") or {})
    flight_masters, taxi_problems = _flight_masters(dbs)
    tables["travel"] = {"flightMasters": flight_masters, "crossings": crossings(_crossing_samples(dbs, maps), maps)}
    stats = {table: len(tables[table]) for table in ("npcs", "objects", "quests", "items", "professions")}
    stats["flightMasters"] = len(flight_masters)
    stats["crossings"] = len(tables["travel"]["crossings"])
    stats["vendorItemsOutsideRoute"] = outside
    return tables, trainer_problems + taxi_problems, stats


# The archive: what each source has ever recorded ------------------------------------------------------------------------
#
# Core/Learn.lua caps its tables and evicts the oldest entries, and the event log is truncated, so a layer rebuilt from
# one SavedVariables read would forget what an earlier read held. Each import therefore folds its sources into
# layers/learned-sources.json (local only, like the layers) and the layer is built from the whole archive. A source is
# one SavedVariables file, named by a label that stays the same between imports; folding a source into itself keeps the
# record with the larger count (the counters only grow within one file), so importing the same file twice changes
# nothing, and importing fewer sources than last time drops nothing.

ARCHIVE_NAME = "learned-sources.json"
ARCHIVE_TABLES = ("npcs", "objects", "quests", "taxi", "trainers", "vendors")
ARCHIVE_EVENTS = 5000  # event log entries kept per source, newest first


def _rank(record: object) -> tuple[float, float]:
    """Which of two records of one thing is the fuller: more sightings, then the later one."""
    record = record if isinstance(record, dict) else {}
    return tuple(float(record[key]) if _number(record.get(key)) else 0.0 for key in ("c", "t"))


def _union(old: object, new: object) -> list:
    return sorted({*_listed(old), *_listed(new)}, key=str)


def _fold_keyed(old: object, new: object) -> dict:
    merged = {str(key): record for key, record in _keyed(old).items()}
    for key, record in _keyed(new).items():
        key = str(key)
        if not isinstance(record, dict):
            continue
        previous = merged.get(key)
        if not isinstance(previous, dict):
            merged[key] = record
            continue
        better = dict(record if _rank(record) >= _rank(previous) else previous)
        for field in ("items", "spells"):  # what a vendor sells and a trainer teaches only ever grows
            if field in record or field in previous:
                better[field] = _union(previous.get(field), record.get(field))
        merged[key] = better
    return merged


def _crossing_key(crossing: dict) -> tuple | None:
    a, b = _point(crossing.get("from")), _point(crossing.get("to"))
    if not (a and b):
        return None
    return (a[0], round(a[1], 1), round(a[2], 1), b[0], round(b[1], 1), round(b[2], 1))


def _fold_crossings(old: object, new: object) -> list:
    merged: dict[tuple, dict] = {}
    for crossing in [*_listed(old), *_listed(new)]:
        key = _crossing_key(crossing) if isinstance(crossing, dict) else None
        if key and (key not in merged or _rank(crossing) >= _rank(merged[key])):
            merged[key] = crossing
    return [merged[key] for key in sorted(merged)]


def _event(entry: object) -> dict | None:
    """The part of an event log entry the layer reads: an NPC or object at a window, or a zone change with its
    previous position. Nothing else of the entry (and nothing about the player) is kept."""
    if not isinstance(entry, dict):
        return None
    snapshot = entry.get("s") if isinstance(entry.get("s"), dict) else {}
    npc = snapshot.get("npc")
    if isinstance(npc, dict) and entity(npc.get("guid")) and _point(npc.get("pos")):
        kept = {key: npc[key] for key in ("guid", "name", "pos") if key in npc}
        return {"e": entry.get("e"), "time": entry.get("time"), "s": {"npc": kept}}
    if entry.get("e") == "ZONE_CHANGED_NEW_AREA" and _point(snapshot.get("pos")) and _point(snapshot.get("prev")):
        return {"e": entry["e"], "time": entry.get("time"), "s": {"pos": snapshot["pos"], "prev": snapshot["prev"]}}
    return None


def _event_key(event: dict) -> str:
    snapshot = event["s"]
    who = (snapshot.get("npc") or {}).get("guid") or json.dumps(snapshot.get("pos"), sort_keys=True)
    return f"{event.get('e')}|{event.get('time')}|{who}"


def fold_source(old: dict | None, db: dict) -> dict:
    """The archived record of one source with a fresh read of it folded in (see the comment above)."""
    old = old or {}
    old_learned, new_learned = _learned(old), _learned(db)
    learned = {table: _fold_keyed(old_learned.get(table), new_learned.get(table)) for table in ARCHIVE_TABLES}
    learned["crossings"] = _fold_crossings(old_learned.get("crossings"), new_learned.get("crossings"))
    events: dict[str, dict] = {}
    for entry in [*_listed(old.get("eventLog")), *_listed(db.get("eventLog"))]:
        event = _event(entry)
        if event:
            events[_event_key(event)] = event
    newest = sorted(events.values(), key=lambda event: (_when(event.get("time")), _event_key(event)), reverse=True)
    return {"learned": learned, "eventLog": newest[:ARCHIVE_EVENTS]}


def _read_archive(pack: Path) -> dict[str, dict]:
    path = Path(pack) / "layers" / ARCHIVE_NAME
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}
    return {label: db for label, db in value.items() if isinstance(label, str) and isinstance(db, dict)}


def _write_archive(pack: Path, archive: dict[str, dict]) -> None:
    path = Path(pack) / "layers" / ARCHIVE_NAME
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(archive, indent=1, sort_keys=True) + "\n", encoding="utf-8")


def merge_learned(
    pack: Path, dbs: list[dict], origin: str, guide_dirs: list[Path] = (), labels: list[str] | None = None
) -> dict[str, int]:
    """Fold the SignpostDB tables into the archive and write layers/learned.json from all of it; datapack.build then
    merges that layer last. `labels` name the sources (the same label on every import of the same file)."""
    labels = labels or [f"source-{number}" for number in range(1, len(dbs) + 1)]
    archive = _read_archive(pack)
    for label, db in zip(labels, dbs):
        archive[label] = fold_source(archive.get(label), db)
    _write_archive(pack, archive)
    everything = [archive[label] for label in sorted(archive)]
    earlier = [
        (name, layer) for name in datapack.LAYERS if name != "learned" and (layer := datapack.read_layer(pack, name))
    ]
    tables, problems, stats = learned_layer(everything, datapack.merge_layers(earlier), guide_dirs)
    datapack.write_layer(pack, "learned", tables, origin, problems)
    return stats
