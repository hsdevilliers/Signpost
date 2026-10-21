"""The data pack's learned layer (PLAN §6 step 7): what Core/Learn.lua recorded in SignpostDB.learned, plus the NPC
positions and zone crossings the /signpost debug recorder kept in SignpostDB.eventLog.

`learned_layer` turns SignpostDB tables (one per SavedVariables source) into layer tables in the pack's schema
(Data/Schema.lua): NPC and object positions ({ uiMapID, x, y }; sightings averaged into up to three spots), quest
givers and enders, flight masters, walked zone crossings, boat and zeppelin rides, innkeepers, the vendors of items the
route uses, and the trainers of each profession with what they teach and charge (professions[line].services) and the
recipes of the trade skill windows (professions[line].recipes; the schema is in Data/Schema.lua). `merge_learned` writes
them as layers/learned.json. datapack.build merges that layer last, so learned positions override the other sources;
links (quest givers and enders, vendors, trainers, a profession's services and recipes) are written together with what
the other layers already know, so learning one never drops another.

Only IDs, the names of NPCs, objects, flight nodes, spells and recipes, trainer prices and requirements, and
coordinates. A player's or pet's GUID is skipped before its name is looked at, and nothing about an item is kept but
which vendors sell it, and only for the items the route touches: items the other layers know (quest starters and
objectives), profession reagents, and the items guide steps buy or collect.
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


# Transports and inns ------------------------------------------------------------------------------------------------
#
# Core/Learn.lua records a boat or zeppelin ride as `rides = { { from = { map, x, y }, to = { map, x, y }, kind?, side?,
# fromArea?, toArea?, secs?, c, t }, ... }` (where the player was last standing on the ground before the transport carried
# them away, and where they were first on the ground after: the docks, within a few yards) and an innkeeper as
# `inns[npcID] = { map, x, y, n?, c, t }` (n: the bind location's name once the hearthstone was set there).

DOCK_SPOT = 2.0  # map percent: rides whose two ends are this close are one transport route
KINDS = ("boat", "zeppelin")
# Words in the area names recorded at the docks that say what the transport is (none of them is a guess about Forever:
# the area's own name says "Zeppelin", "Harbor" ...). Anything else leaves the kind to the player's `/signpost ride <kind>`.
KIND_WORDS = (
    ("zeppelin", "zeppelin"),
    ("harbor", "boat"),
    ("harbour", "boat"),
    ("pier", "boat"),
    ("wharf", "boat"),
    ("ferry", "boat"),
)
SIDE_NAMES = ("Horde", "Alliance")  # the player's faction token, as UnitFactionGroup returns it


def _kind_of(kind: object, *areas: object) -> str | None:
    """boat or zeppelin: the recorded kind (the player said it), else a word of an area name, else None."""
    if isinstance(kind, str) and kind.lower() in KINDS:
        return kind.lower()
    for area in areas:
        if isinstance(area, str):
            for word, found in KIND_WORDS:
                if word in area.lower():
                    return found
    return None


def _ride_samples(dbs: list[dict], maps: dict) -> list[dict]:
    """Every recorded ride with both ends as map points on zone maps, oriented lower end first (a boat runs both ways)."""
    samples = []
    for db in dbs:
        for ride in _listed(_learned(db).get("rides")):
            if not isinstance(ride, dict):
                continue
            a, b = _point(ride.get("from")), _point(ride.get("to"))
            if not (a and b) or _continental(a[0], maps) or _continental(b[0], maps):
                continue
            areas = [ride.get("fromArea"), ride.get("toArea")]
            if a > b:
                a, b, areas = b, a, areas[::-1]
            if a[0] == b[0] and math.hypot(a[1] - b[1], a[2] - b[2]) <= DOCK_SPOT:
                continue  # one spot: not a ride between two docks
            side = ride.get("side") if ride.get("side") in SIDE_NAMES else None
            samples.append(
                {"a": a, "b": b, "w": float(_id(ride.get("c")) or 1), "kind": _kind_of(ride.get("kind")), "areas": areas, "side": side}
            )
    return samples


def transports(dbs: list[dict], maps: dict) -> tuple[list[dict], list[str]]:
    """travel.transports from recorded rides: one record per pair of docks (rides there and back are one), the ends weighted
    means, the kind the player named (or an area name says), the side the recorders had (both when they differ). A route whose
    kind nobody named is left out, with a problem line that says how to name it: the step would say "boat" or "zeppelin"."""
    groups: list[dict] = []
    for sample in sorted(_ride_samples(dbs, maps), key=lambda s: (-s["w"], s["a"], s["b"])):
        for g in groups:
            if (
                g["a"][0] == sample["a"][0]
                and g["b"][0] == sample["b"][0]
                and math.hypot(g["sax"] / g["w"] - sample["a"][1], g["say"] / g["w"] - sample["a"][2]) <= DOCK_SPOT
                and math.hypot(g["sbx"] / g["w"] - sample["b"][1], g["sby"] / g["w"] - sample["b"][2]) <= DOCK_SPOT
            ):
                break
        else:
            g = {"a": sample["a"], "b": sample["b"], "w": 0.0, "sax": 0.0, "say": 0.0, "sbx": 0.0, "sby": 0.0, "kinds": {}, "areas": [], "sides": set()}
            groups.append(g)
        w = sample["w"]
        g["w"] += w
        g["sax"] += sample["a"][1] * w
        g["say"] += sample["a"][2] * w
        g["sbx"] += sample["b"][1] * w
        g["sby"] += sample["b"][2] * w
        if sample["kind"]:
            g["kinds"][sample["kind"]] = g["kinds"].get(sample["kind"], 0.0) + w
        g["areas"] += sample["areas"]
        g["sides"].add(sample["side"])
    result: list[dict] = []
    problems: list[str] = []
    for g in sorted(groups, key=lambda g: (g["a"][0], g["b"][0], g["sax"] / g["w"], g["say"] / g["w"])):
        names = [(maps.get(g[end][0]) or {}).get("n") or f"map {g[end][0]}" for end in ("a", "b")]
        kind = max(g["kinds"], key=lambda k: (g["kinds"][k], k)) if g["kinds"] else _kind_of(None, *g["areas"])
        if kind is None:
            problems.append(
                f"ride {names[0]} <-> {names[1]}: boat or zeppelin? (type /signpost ride boat or /signpost ride zeppelin "
                "before boarding; the route is left out until a ride says it)"
            )
            continue
        if len(g["kinds"]) > 1:
            problems.append(f"ride {names[0]} <-> {names[1]}: recorded as both {' and '.join(sorted(g['kinds']))}; took {kind}")
        sides = {side for side in g["sides"] if side}
        side = next(iter(sides)) if len(sides) == 1 and None not in g["sides"] else "both"
        result.append(
            {
                "kind": kind,
                "from": [g["a"][0], _round(g["sax"] / g["w"]), _round(g["say"] / g["w"])],
                "to": [g["b"][0], _round(g["sbx"] / g["w"]), _round(g["sby"] / g["w"])],
                "side": side,
                "src": "learned",
            }
        )
    return result, problems


def _inns(dbs: list[dict]) -> dict[int, dict]:
    """travel.inns from recorded innkeepers: the latest position the player stood at, and the bind location's name from the
    latest record that has one (a later sighting without it does not erase it)."""
    places: dict[int, tuple[float, Point]] = {}
    names: dict[int, tuple[float, str]] = {}
    for db in dbs:
        for npc, record in _keyed(_learned(db).get("inns")).items():
            npc, point = _id(npc), _point(record)
            if not (npc and point and isinstance(record, dict)):
                continue
            when = _when(record.get("t"))
            if npc not in places or when >= places[npc][0]:
                places[npc] = (when, point)
            name = record.get("n")
            if isinstance(name, str) and name and (npc not in names or when >= names[npc][0]):
                names[npc] = (when, name)
    return {
        npc: {"p": list(point)} | ({"n": names[npc][1]} if npc in names else {})
        for npc, (_, point) in sorted(places.items())
    }


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


# Profession services and recipes ------------------------------------------------------------------------------------
#
# Core/LearnProfessions.lua records, with each trainer, the services its window listed (trainers[npc].services) and, per
# recipe, what the trade skill window listed (recipes[spell]). The layer files them under the profession's skill line:
# professions[line].trainers, .services[npc] and .recipes[spell] (Data/Schema.lua). What the other layers hold for the
# same trainers and recipes is kept; the learned fields win field by field, and a trainer's services and a recipe's
# difficulty observations are unioned with them. Only the fields below are read, so nothing else in a SavedVariables
# file (a stray name, a line of text) can reach the archive or the pack.

# Enum.TradeskillRelativeDifficulty, in the order a recipe passes them
DIFFICULTIES = ("optimal", "medium", "easy", "trivial")
COLOURS = ("orange", "yellow", "green", "grey")  # where each difficulty starts, in the same order
MAX_SKILL = 1000  # no profession skill is above this
MAX_LEVEL = 200
MAX_COPPER = 2**31
MAX_TEXT = 100  # bytes: a spell, recipe or rank name is shorter
MAX_REAGENTS = 12  # items per recipe, as the recorder's LIMITS.reagentsPerRecipe


def _count(value: object, maximum: int) -> int | None:
    """A whole number from 0 to `maximum`, else None."""
    if isinstance(value, bool):
        return None
    if isinstance(value, float) and value.is_integer():
        value = int(value)
    return value if isinstance(value, int) and 0 <= value <= maximum else None


def _text(value: object) -> str | None:
    """A name: a non-empty string that is no longer than a name is."""
    if isinstance(value, str) and value and len(value.encode("utf-8", "surrogateescape")) <= MAX_TEXT:
        return value
    return None


def _service(raw: object) -> dict | None:
    """One trainer service reduced to the fields the pack keeps: spell `id`, `item` it gives, `n` name, `r` rank text,
    `cost` in copper, `lvl` required level, `need` required skill, and `line` (the profession's skill line, which the
    layer files it under and drops). None when it names neither a spell nor a name."""
    if not isinstance(raw, dict):
        return None
    service: dict[str, object] = {}
    for key in ("id", "item", "line"):
        ident = _id(raw.get(key))
        if ident:
            service[key] = ident
    for key in ("n", "r"):
        text = _text(raw.get(key))
        if text:
            service[key] = text
    cost = _count(raw.get("cost"), MAX_COPPER)
    if cost is not None:
        service["cost"] = cost
    for key, maximum in (("lvl", MAX_LEVEL), ("need", MAX_SKILL)):
        value = _count(raw.get(key), maximum)
        if value:
            service[key] = value
    return service if "id" in service or "n" in service else None


def _service_key(service: dict) -> tuple:
    """A service is its spell, else its name and rank."""
    if "id" in service:
        return ("s", service["id"])
    return ("n", service.get("n", ""), service.get("r", ""))


def merge_services(*readings: object) -> list[dict]:
    """The services of several readings of one trainer, oldest first: each service once, as its newest reading has it
    (a window filtered to some services does not take the others away)."""
    merged: dict[tuple, dict] = {}
    for reading in readings:
        for raw in _listed(reading):
            service = _service(raw)
            if service:
                merged[_service_key(service)] = service
    return sorted(merged.values(), key=lambda s: (s.get("id", 0), s.get("n", ""), s.get("r", "")))


def _reagents(value: object) -> dict[int, int]:
    reagents: dict[int, int] = {}
    pairs = sorted(((_id(key), _count(count, 1000)) for key, count in _keyed(value).items()), key=lambda p: p[0] or 0)
    for item, number in pairs:
        if item and number and len(reagents) < MAX_REAGENTS:
            reagents[item] = number
    return reagents


def _observations(value: object) -> list[tuple[int, str]]:
    """(skill, difficulty) pairs from a recipe's `obs`; whatever is not one of those is dropped."""
    pairs = []
    for raw in _listed(value):
        if isinstance(raw, dict):
            skill, cat = _count(raw.get("skill"), MAX_SKILL), raw.get("cat")
            if skill and cat in DIFFICULTIES:
                pairs.append((skill, cat))
    return pairs


def compact_observations(pairs: list[tuple[int, str]]) -> list[dict]:
    """One entry per skill value (the last one given wins), then only the lowest and the highest skill seen in each
    difficulty: all that the colour thresholds can be read from, and at most eight entries however long one plays."""
    by_skill: dict[int, str] = {}
    for skill, cat in pairs:
        by_skill[skill] = cat
    keep: set[int] = set()
    for cat in DIFFICULTIES:
        skills = [skill for skill, name in by_skill.items() if name == cat]
        if skills:
            keep.update((min(skills), max(skills)))
    return [{"skill": skill, "cat": by_skill[skill]} for skill in sorted(keep)]


def skill_bounds(obs: object) -> dict[str, tuple[int | None, int | None]]:
    """Where each colour starts, as far as a recipe's observations say: {"yellow": (lowest, highest), ...} with None
    where nothing is known. A recipe is orange from the skill it can first be made at, yellow from `yellow` on, green
    from `green`, grey from `grey`; a difficulty seen at some skill means that colour had started by then, and an
    earlier difficulty seen at a skill means the colour had not started yet. (Exact when both numbers are equal.)"""
    pairs = _observations(obs)
    bounds: dict[str, tuple[int | None, int | None]] = {}
    for index, colour in enumerate(COLOURS):
        earlier = [skill for skill, cat in pairs if DIFFICULTIES.index(cat) < index]
        from_here = [skill for skill, cat in pairs if DIFFICULTIES.index(cat) >= index]
        bounds[colour] = (max(earlier) + 1 if earlier else None, min(from_here) if from_here else None)
    return bounds


def _recipe(raw: object) -> dict | None:
    """One recipe reduced to the fields the pack keeps: `n` name, `item` it makes, `reagents` { item: count }, `obs`
    difficulty observations, and `line` (the skill line the layer files it under and drops). None when it has no name,
    item or reagents."""
    if not isinstance(raw, dict):
        return None
    record: dict[str, object] = {}
    name = _text(raw.get("n"))
    if name:
        record["n"] = name
    for key in ("item", "line"):
        ident = _id(raw.get(key))
        if ident:
            record[key] = ident
    reagents = _reagents(raw.get("reagents"))
    if reagents:
        record["reagents"] = reagents
    if not any(key in record for key in ("n", "item", "reagents")):
        return None
    obs = compact_observations(_observations(raw.get("obs")))
    if obs:
        record["obs"] = obs
    return record


def _merge_recipe(older: dict, newer: dict) -> dict:
    """The newer reading's fields where it has them, else the older one's; the observations of both."""
    merged = {**older, **{key: value for key, value in newer.items() if key != "obs"}}
    obs = compact_observations(_observations(older.get("obs")) + _observations(newer.get("obs")))
    if obs:
        merged["obs"] = obs
    return merged


def _learned_recipes(dbs: list[dict]) -> dict[int, dict]:
    """{spell: recipe} from every source: the newest reading's fields, the observations of all of them."""
    readings: dict[int, list[tuple[float, dict]]] = {}
    for db in dbs:
        for key, raw in _keyed(_learned(db).get("recipes")).items():
            spell, record = _id(key), _recipe(raw)
            if spell and record:
                readings.setdefault(spell, []).append((_when(raw.get("t")), record))
    recipes = {}
    for spell, items in readings.items():
        ordered = [record for _, record in sorted(items, key=lambda item: item[0])]
        merged = ordered[0]
        for record in ordered[1:]:
            merged = _merge_recipe(merged, record)
        recipes[spell] = merged
    return recipes


def _recipes(dbs: list[dict], known: dict) -> tuple[dict[int, dict[int, dict]], int, list[str]]:
    """professions[skillLine].recipes: the pack's recipes of each profession a learned recipe belongs to, with the
    learned ones over them. Also how many learned recipes were filed, and the ones that name no profession."""
    owner = {}
    for line, profession in known.items():
        for key in (profession.get("recipes") if isinstance(profession, dict) else None) or {}:
            if _id(key):
                owner.setdefault(_id(key), line)
    by_line: dict[int, dict[int, dict]] = {}
    filed, problems = 0, []
    for spell, learned_record in sorted(_learned_recipes(dbs).items()):
        line = learned_record.get("line") or owner.get(spell)
        if not line:
            problems.append(f"learned recipe {spell}: no skill line (the profession of its window was not named)")
            continue
        record = {key: value for key, value in learned_record.items() if key != "line"}
        recipes = by_line.setdefault(line, dict((known.get(line) or {}).get("recipes") or {}))
        base = recipes.get(spell)
        recipes[spell] = _merge_recipe(base, record) if isinstance(base, dict) else record
        filed += 1
    return by_line, filed, problems


def _trainers(
    dbs: list[dict], known: dict, recipe_lines: dict[int, set[int]]
) -> tuple[dict[int, dict], int, list[str]]:
    """professions[skillLine].trainers and .services: by the skill line Core/Learn.lua read at the trainer or at one of
    its services, else by the recipes (the pack's, and the learned ones in `recipe_lines`: { line: {spells} }) that its
    spells teach. A service names its own profession, else it belongs to the trainer's one. Also how many services
    were filed."""
    learned: dict[int, dict] = {}
    for db in dbs:
        for npc, record in _keyed(_learned(db).get("trainers")).items():
            npc = _id(npc)
            if not (npc and isinstance(record, dict)):
                continue
            entry = learned.setdefault(npc, {"spells": set(), "skills": set(), "readings": []})
            entry["spells"].update(_ids(record.get("spells")))
            if _id(record.get("skill")):
                entry["skills"].add(_id(record.get("skill")))
            if "services" in record:
                entry["readings"].append((_when(record.get("t")), record["services"]))
    recipes = {line: set(spells) for line, spells in recipe_lines.items()}
    for skill_line, profession in known.items():
        table = profession.get("recipes") if isinstance(profession, dict) else None
        recipes.setdefault(skill_line, set()).update(ident for ident in (_id(key) for key in table or {}) if ident)
    teachers: dict[int, set[int]] = {}
    filed: dict[int, dict[int, list[dict]]] = {}
    problems = []
    for npc, entry in sorted(learned.items()):
        services = merge_services(*(reading for _, reading in sorted(entry["readings"], key=lambda r: r[0])))
        entry["spells"].update(service["id"] for service in services if "id" in service)
        entry["skills"].update(service["line"] for service in services if "line" in service)
        skills = entry["skills"] or {line for line, spells in recipes.items() if spells & entry["spells"]}
        if not skills:
            problems.append(
                f"learned trainer {npc} ({len(entry['spells'])} services): no profession in the pack teaches them "
                "(class trainers wait for the classes table)"
            )
        for skill_line in skills:
            teachers.setdefault(skill_line, set()).add(npc)
        for service in services:
            line = service.get("line") or (next(iter(skills)) if len(skills) == 1 else None)
            if line:
                kept = {key: value for key, value in service.items() if key != "line"}
                filed.setdefault(line, {}).setdefault(npc, []).append(kept)
    professions = {}
    for line, npcs in sorted(teachers.items()):
        base = known.get(line) or {}
        professions[line] = {"trainers": _with(npcs, base.get("trainers"))}
        if line in filed:
            services = {npc: _listed(listed) for npc, listed in _keyed(base.get("services")).items()}
            for npc, listed in filed[line].items():
                services[npc] = merge_services(services.get(npc), listed)
            professions[line]["services"] = services
    return professions, sum(len(listed) for by_npc in filed.values() for listed in by_npc.values()), problems


def _profession_layer(dbs: list[dict], known: dict) -> tuple[dict[int, dict], list[str], set[int], dict[str, int]]:
    """The layer's professions table (trainers, services and recipes), the problems found, the reagent items of its
    recipes and the counts: recipes and trainerServices filed."""
    recipes, recipe_count, recipe_problems = _recipes(dbs, known)
    spells = {line: {spell for spell in by_spell if isinstance(spell, int)} for line, by_spell in recipes.items()}
    professions, service_count, problems = _trainers(dbs, known, spells)
    for line, by_spell in recipes.items():
        professions.setdefault(line, {})["recipes"] = by_spell
    reagents = {
        item
        for by_spell in recipes.values()
        for record in by_spell.values()
        for item in (record.get("reagents") if isinstance(record, dict) else None) or {}
        if isinstance(item, int)
    }
    counts = {"recipes": recipe_count, "trainerServices": service_count}
    return professions, problems + recipe_problems, reagents, counts


def _fold_services(folded: dict[str, dict], old: object, new: object) -> None:
    """The archive's trainers with their services merged across the archived and the fresh record, the later record's
    reading of a service winning. `folded` is what _fold_keyed made of the two; its records are replaced, not edited."""
    tables = [{str(key): record for key, record in _keyed(table).items()} for table in (old, new)]
    for key in list(folded):
        readings = [
            (_when(records[key].get("t")), records[key]["services"])
            for records in tables
            if isinstance(records.get(key), dict) and "services" in records[key]
        ]
        services = merge_services(*(reading for _, reading in sorted(readings, key=lambda r: r[0])))
        record = {name: value for name, value in folded[key].items() if name != "services"}
        if services:
            record["services"] = services
        folded[key] = record


def _fold_recipes(old: object, new: object) -> dict[str, dict]:
    """The archive's recipes: per spell the later record's fields over the earlier one's, the observations of both."""
    folded: dict[str, dict] = {}
    for table in (old, new):
        for key, raw in _keyed(table).items():
            spell, record = _id(key), _recipe(raw)
            if not (spell and record):
                continue
            record["t"] = raw["t"] if _number(raw.get("t")) else 0
            previous = folded.get(str(spell))
            if previous is None:
                folded[str(spell)] = record
            else:
                older, newer = (previous, record) if record["t"] >= previous["t"] else (record, previous)
                folded[str(spell)] = _merge_recipe(older, newer)
    return folded


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
    tables["professions"], trainer_problems, reagents, profession_stats = _profession_layer(
        dbs, base.get("professions") or {}
    )
    # the reagents of the recipes learned count as route items, like those of the recipes the pack holds
    tables["items"], outside = _vendors(dbs, base.get("items") or {}, route_items(base, list(guide_dirs)) | reagents)
    flight_masters, taxi_problems = _flight_masters(dbs)
    rides, ride_problems = transports(dbs, maps)
    inns = _inns(dbs)
    tables["travel"] = {
        "flightMasters": flight_masters,
        "crossings": crossings(_crossing_samples(dbs, maps), maps),
        "transports": rides,
        "inns": inns,
    }
    stats = {table: len(tables[table]) for table in ("npcs", "objects", "quests", "items", "professions")}
    stats.update(profession_stats)
    stats["flightMasters"] = len(flight_masters)
    stats["crossings"] = len(tables["travel"]["crossings"])
    stats["transports"] = len(rides)
    stats["inns"] = len(inns)
    stats["vendorItemsOutsideRoute"] = outside
    return tables, trainer_problems + taxi_problems + ride_problems, stats


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
    _fold_services(learned["trainers"], old_learned.get("trainers"), new_learned.get("trainers"))
    learned["recipes"] = _fold_recipes(old_learned.get("recipes"), new_learned.get("recipes"))
    learned["rides"] = _fold_crossings(old_learned.get("rides"), new_learned.get("rides"))  # two ends, a count: as a crossing
    learned["inns"] = _fold_keyed(old_learned.get("inns"), new_learned.get("inns"))
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
