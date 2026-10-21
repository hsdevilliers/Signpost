"""Find the zone changes a guide does not cover with travel steps, and propose the steps (PLAN §3.6).

    python tools/guide_travel.py                           every uncovered zone change in every guide, with DSL to paste
    python tools/guide_travel.py --guide <id> --simulate   step by step: zone, flight paths, hearth, expected level
    python tools/guide_travel.py --from 1411,52.0,43.5 --to 1413,62.3,56.0 --faction Horde --fp "Orgrimmar"

The simulation walks the guide's route (gated per race/class/faction, with the default plan's profession tracks merged
unless --no-tracks): the zone of each step's targets, the flight paths taught by `.fp`, the hearth set by `.hs`. A step
whose first target is in another zone than the previous step's last target, with no travel directive between them, is
an uncovered transition (`guide_lint.py --strict` fails on it).

The travel graph comes from the data pack (../Signpost_Data: maps with world rectangles and the client's flight nodes,
the travel table's flight masters, boats, zeppelins, inns and learned crossings) and Guides/Travel/Borders.lua. Costs
are seconds: walking at running speed, flights a fixed cost plus distance, boats and zeppelins a wait plus the
crossing, the hearthstone a cast (once an hour, tracked with a rough clock). Coordinates are only ever copied from that
data; where the graph has none, the proposal is a `.todo` step.
"""

from __future__ import annotations

import argparse
import heapq
import math
import subprocess
import sys
from dataclasses import dataclass, field, replace
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from signpost_tools import datapack, guidefile, pricing  # noqa: E402
from signpost_tools.guidefile import Coord, Directive, Route, RouteStep  # noqa: E402
from signpost_tools.savedvars import LuaParseError, load_savedvars  # noqa: E402

REPO_ROOT = Path(__file__).resolve().parent.parent
# Enum.FlightPathFaction values in C_TaxiMap results (docs/FOREVER-API-NOTES.md).
TAXI_SIDES = {0: "both", 1: "Horde", 2: "Alliance"}
ZONE_TYPE = 3  # Enum.UIMapType.Zone (cities are zones too)
# The service bits of npcs[...].flags in the pack (Data/Schema.lua: vendor 4, flight master 8, trainer 16, innkeeper 128).
FLIGHT_MASTER_FLAG = 8
INNKEEPER_FLAG = 128
NODE_MATCH_YARDS = 100.0  # a flight master and a client flight node this close are the same flight path (as the exporter)

# Costs, in seconds. The numbers and the reasoning for each are in signpost_tools/pricing.py (tools/sim_params.json can override them),
# which the Route Planner and the guide simulator use too: one price for travel. The names stay for the code that imports them.
WALK_SPEED = pricing.PRICES.walk_speed  # yards per second on foot
UNKNOWN_WALK = pricing.PRICES.unknown_walk  # a walk inside a zone between points whose positions are not known
FLIGHT_OVERHEAD = pricing.PRICES.flight_overhead
FLIGHT_SPEED = pricing.PRICES.flight_speed  # yards per second along the straight line (taxi routes wind)
UNKNOWN_FLIGHT = pricing.PRICES.unknown_flight
TRANSPORT_WAIT = pricing.PRICES.transport_wait
TRANSPORT_SPEED = pricing.PRICES.transport_speed
TRANSPORT_ACROSS = pricing.PRICES.transport_across  # a crossing between two world instances (continents)
HEARTH_SECONDS = pricing.PRICES.hearth  # cast and loading screen
# VERIFY(beta): the hearthstone cooldown on Forever (Classic's is 60 minutes).
HEARTH_COOLDOWN = 3600.0
TODO_PENALTY = pricing.PRICES.crossing_penalty  # a crossing whose coordinates are not known yet...
UNKNOWN_CROSS = pricing.PRICES.unknown_crossing  # ...costs this plus the penalty, so known routes win (a search weight, not play time)
# Each step's own time in the clock that tracks the hearthstone cooldown. It prices nothing in a route's total (SimStep.seconds is the
# travel alone): only `.home` after `.home` is judged by this clock, so it runs slow against the ~3 minutes a step takes in the full simulation.
STEP_SECONDS = 45.0


# The data pack --------------------------------------------------------------------------------------------------------


@dataclass
class Pack:
    path: Path | None = None
    meta: dict = field(default_factory=dict)
    tables: dict = field(default_factory=dict)
    problems: list[str] = field(default_factory=list)

    @property
    def present(self) -> bool:
        return self.path is not None

    def table(self, name: str) -> dict:
        value = self.tables.get(name)
        return value if isinstance(value, dict) else {}

    def has(self, name: str) -> bool:
        return bool(self.tables.get(name))

    def describe(self) -> str:
        if not self.present:
            return "no data pack" + (f" ({'; '.join(self.problems)})" if self.problems else "")
        counts = ", ".join(f"{name} {len(self.table(name))}" for name in ("quests", "npcs", "objects", "items", "maps"))
        return f"data pack {self.path} (generated {self.meta.get('generated', '?')}; {counts})"


def default_pack_dir(root: Path) -> Path | None:
    """../Signpost_Data next to the checkout, or next to the main checkout when this is a git worktree."""
    candidates = [Path(root).resolve().parent / "Signpost_Data"]
    try:
        common = subprocess.run(
            ["git", "rev-parse", "--path-format=absolute", "--git-common-dir"],
            cwd=root,
            capture_output=True,
            text=True,
            check=True,
        ).stdout.strip()
        if common:
            candidates.append(Path(common).parent.parent / "Signpost_Data")
    except (OSError, subprocess.CalledProcessError):
        pass
    return next((candidate for candidate in candidates if (candidate / "_meta.lua").is_file()), None)


def _keyed(value: object) -> dict:
    """A generated table as {key: record} (the literal parser turns tables keyed 1..n into lists)."""
    if isinstance(value, list):
        return {index + 1: item for index, item in enumerate(value)}
    if isinstance(value, dict):
        return {int(key) if isinstance(key, str) and key.isdigit() else key: item for key, item in value.items()}
    return {}


def _travel_table(value: object) -> dict:
    value = value if isinstance(value, dict) else {}
    travel = {part: _keyed(value.get(part)) for part in datapack.TRAVEL_KEYED}
    for part in datapack.TRAVEL_LISTS:
        items = value.get(part)
        travel[part] = list(items.values()) if isinstance(items, dict) else list(items or [])
    return travel


def load_pack(path: Path | None) -> Pack:
    """Read the data pack's generated tables (read-only). A missing or incompatible pack is an empty one."""
    if path is None:
        return Pack(problems=["not found next to the checkout"])
    path = Path(path)
    meta_file = path / "_meta.lua"
    if not meta_file.is_file():
        return Pack(problems=[f"{path} has no _meta.lua"])
    try:
        root = load_savedvars(meta_file).get(datapack.GLOBAL)
    except (LuaParseError, OSError) as exc:
        return Pack(problems=[f"{meta_file}: {exc}"])
    root = root if isinstance(root, dict) else {}
    meta = root.get("_meta") if isinstance(root.get("_meta"), dict) else {}
    if meta.get("schema") != datapack.SCHEMA:
        return Pack(problems=[f"{path}: schema {meta.get('schema')!r}, the tools read schema {datapack.SCHEMA}"])
    pack = Pack(path, meta)
    for table, file_name in datapack.TABLE_FILES.items():
        try:
            value = datapack.read_table(path, table)
        except (LuaParseError, OSError) as exc:
            pack.problems.append(f"{file_name}: {exc}")
            continue
        pack.tables[table] = _travel_table(value) if table == "travel" else _keyed(value)
    classes = dict(_keyed(root.get("classes")))
    prefix = f"{datapack.GLOBAL}.classes"
    for file in sorted((path / "classes").glob("*.lua")) if (path / "classes").is_dir() else []:
        try:
            statements = load_savedvars(file)
        except (LuaParseError, OSError) as exc:
            pack.problems.append(f"classes/{file.name}: {exc}")
            continue
        for target, value in statements.items():
            if target == prefix and isinstance(value, dict):
                classes.update(value)
            elif target.startswith(prefix + "."):
                classes[target[len(prefix) + 1 :]] = value
    pack.tables["classes"] = classes
    return pack


# Coordinates and maps -------------------------------------------------------------------------------------------------


def coord_of(value: object) -> Coord | None:
    """{ map, x, y } (or { map = , x = , y = }); for a list of coordinates, the first."""
    if isinstance(value, dict):
        value = [value.get("map"), value.get("x"), value.get("y")]
    if not isinstance(value, list) or not value:
        return None
    if isinstance(value[0], (list, dict)):
        return coord_of(value[0])
    if len(value) >= 3 and isinstance(value[0], int) and all(isinstance(v, (int, float)) for v in value[1:3]):
        return Coord(value[0], float(value[1]), float(value[2]))
    return None


def coords_of(value: object) -> list[Coord]:
    if isinstance(value, list) and value and isinstance(value[0], (list, dict)):
        return [coord for coord in (coord_of(item) for item in value) if coord]
    coord = coord_of(value)
    return [coord] if coord else []


def map_of(value: object) -> int | None:
    if isinstance(value, dict):
        value = value.get("map")
    if isinstance(value, list) and value:
        value = value[0]
    return value if isinstance(value, int) and value > 0 else None


def side_of(value: object) -> str:
    if isinstance(value, int):
        return TAXI_SIDES.get(value, "both")
    return value if value in guidefile.FACTIONS else "both"


def usable(side: str, faction: str) -> bool:
    return faction == "*" or side in ("both", faction)


class Geo:
    """The data pack's map table: names, the map tree, and world rectangles for positions in yards."""

    def __init__(self, maps: dict) -> None:
        self.maps = {key: value for key, value in maps.items() if isinstance(key, int) and isinstance(value, dict)}

    def known(self, map_id: int) -> bool:
        return map_id in self.maps

    def name(self, map_id: int) -> str:
        name = (self.maps.get(map_id) or {}).get("n")
        return name if isinstance(name, str) else f"map {map_id}"

    def label(self, map_id: int | None) -> str:
        if map_id is None:
            return "an unknown zone"
        return f"{self.name(map_id)} ({map_id})" if self.known(map_id) else f"map {map_id}"

    def kind(self, map_id: int) -> int | None:
        return (self.maps.get(map_id) or {}).get("t")

    def parent(self, map_id: int) -> int | None:
        parent = (self.maps.get(map_id) or {}).get("parent")
        return parent if isinstance(parent, int) and parent > 0 else None

    def rect(self, map_id: int) -> tuple | None:
        rect = (self.maps.get(map_id) or {}).get("world")
        if isinstance(rect, list) and len(rect) == 5 and all(isinstance(v, (int, float)) for v in rect):
            return tuple(rect)
        return None

    def instance(self, map_id: int) -> int | None:
        rect = self.rect(map_id)
        return rect[0] if rect else None

    def within(self, map_id: int, ancestor: int) -> bool:
        seen: set[int] = set()
        current: int | None = map_id
        while current is not None and current not in seen:
            if current == ancestor:
                return True
            seen.add(current)
            current = self.parent(current)
        return False

    def zone(self, map_id: int) -> int:
        """The zone a map counts as for travel: a dungeon, micro or orphan map inside a zone (same world instance)
        counts as that zone; any other map is a zone of its own (cities too: Orgrimmar 1454 is not in Durotar)."""
        # VERIFY(beta): C_Map.GetBestMapForUnit inside a city returns the city map (open probe in the API notes).
        current = map_id
        for _ in range(16):
            parent = self.parent(current)
            if (self.kind(current) or 0) <= ZONE_TYPE or parent is None:
                return current
            if (self.kind(parent) or 0) < ZONE_TYPE or self.instance(parent) != self.instance(current):
                return current
            current = parent
        return current

    def world(self, coord: Coord) -> tuple[int, float, float] | None:
        """(instance, world x, world y) of a map position: the rectangle holds the world position of the map's
        top-left (x0, y0) and bottom-right (x1, y1) corners; a map's horizontal axis runs along world y."""
        rect = self.rect(coord.map)
        if rect is None:
            return None
        instance, x0, y0, x1, y1 = rect
        return instance, x0 + (x1 - x0) * coord.y / 100.0, y0 + (y1 - y0) * coord.x / 100.0

    def local(self, map_id: int, point: tuple[int, float, float]) -> Coord | None:
        rect = self.rect(map_id)
        if rect is None or rect[0] != point[0] or rect[3] == rect[1] or rect[4] == rect[2]:
            return None
        _, x0, y0, x1, y1 = rect
        return Coord(map_id, (point[2] - y0) / (y1 - y0) * 100.0, (point[1] - x0) / (x1 - x0) * 100.0)

    def contains(self, map_id: int, point: tuple[int, float, float]) -> bool:
        coord = self.local(map_id, point)
        return coord is not None and 0 <= coord.x <= 100 and 0 <= coord.y <= 100

    def area(self, map_id: int) -> float:
        rect = self.rect(map_id)
        return abs((rect[3] - rect[1]) * (rect[4] - rect[2])) if rect else math.inf

    def distance(self, a: Coord | None, b: Coord | None) -> float | None:
        if a is None or b is None:
            return None
        wa, wb = self.world(a), self.world(b)
        if wa is None or wb is None or wa[0] != wb[0]:
            return None
        return math.hypot(wa[1] - wb[1], wa[2] - wb[2])


# Flight paths, transports, crossings ----------------------------------------------------------------------------------


def _normal_name(name: str) -> str:
    name = " ".join(name.lower().split())
    return name[4:] if name.startswith("the ") else name


def name_keys(name: str) -> set[str]:
    """A flight node matches by its full name ("Orgrimmar, Durotar") or the part before the comma ("Orgrimmar");
    case, extra spaces and a leading "The" do not matter (as in Engine/Travel.lua)."""
    # VERIFY(beta): the flight master's node names (TaxiNodeName / C_TaxiMap) are the map dump's names.
    return {_normal_name(name), _normal_name(name.split(",")[0])}


def names_match(a: str, b: str) -> bool:
    return bool(name_keys(a) & name_keys(b))


@dataclass(frozen=True)
class FlightNode:
    name: str  # the client's name, e.g. "Crossroads, The Barrens"
    side: str  # Horde, Alliance or both
    zone: int | None
    coord: Coord | None  # the flight master's position in that zone
    node_id: int | None = None
    origin: str = "the client's taxi map"
    exact: bool = False  # the position is a flight master record, not the taxi map pin


def _taxi_zone(geo: Geo, name: str, point: tuple[int, float, float]) -> int | None:
    """The zone of a taxi map pin: a zone containing it whose name starts with the node's own name (a city) or with
    the part after the comma ("Tarren Mill, Hillsbrad" -> Hillsbrad Foothills); else the only zone containing it."""
    # VERIFY(beta): the flight master stands in the map this picks (a city's node in the city map, e.g. Undercity's
    # bat handler in 1458); a flight master record in the data pack, once Learn has one, replaces the guess.
    candidates = [map_id for map_id in geo.maps if geo.kind(map_id) == ZONE_TYPE and geo.contains(map_id, point)]
    head, _, tail = name.partition(",")
    for word in (head.strip().lower(), tail.strip().lower()):
        found = [map_id for map_id in candidates if word and geo.name(map_id).lower().startswith(word)]
        if found:
            return min(found, key=geo.area)
    return candidates[0] if len(candidates) == 1 else None


def _by_id(item: tuple) -> tuple:
    return (0, item[0], "") if isinstance(item[0], int) else (1, 0, str(item[0]))


def service_npcs(pack: Pack, flag: int) -> list[tuple[object, dict]]:
    """The pack's NPC records that carry a service flag (flight master, innkeeper, ...), in ID order."""
    found = []
    for npc, record in sorted(pack.table("npcs").items(), key=_by_id):
        flags = record.get("flags") if isinstance(record, dict) else None
        if isinstance(flags, int) and not isinstance(flags, bool) and flags & flag:
            found.append((npc, record))
    return found


def derive_flight_masters(pack: Pack, geo: Geo, nodes: list[FlightNode], covered: set) -> dict[object, dict]:
    """Flight master records ({ node, p, side }, as the travel table's) for the pack's own flight master NPCs that no travel
    record covers: the QuestieDB layer's NPCs carry the flight master flag and a position (a Classic Era baseline, not
    Forever's truth), and the client's taxi map names the node. Each NPC takes the nearest client node of a side it can
    serve within NODE_MATCH_YARDS; a node keeps the nearest of the NPCs that match it. An NPC that matches no node (a
    flight path the client does not list) is left out: a `.fly` needs the node's name."""
    best: dict[int, tuple[float, object, dict]] = {}
    for npc, record in service_npcs(pack, FLIGHT_MASTER_FLAG):
        coord, side = coord_of(record.get("p")), side_of(record.get("side"))
        if npc in covered or coord is None:
            continue
        pick: tuple[float, int] | None = None
        for index, node in enumerate(nodes):
            if not (side == "both" or node.side in ("both", side)):
                continue
            distance = geo.distance(coord, node.coord)
            if distance is not None and distance <= NODE_MATCH_YARDS and (pick is None or distance < pick[0]):
                pick = (distance, index)
        if pick is not None and (pick[1] not in best or pick[0] < best[pick[1]][0]):
            best[pick[1]] = (pick[0], npc, {"node": nodes[pick[1]].name, "p": [coord.map, coord.x, coord.y], "side": side})
    return {npc: record for _, npc, record in best.values()}


def flight_nodes(pack: Pack, geo: Geo) -> list[FlightNode]:
    """Every flight node: the client's taxi map pins (continents), positioned by the flight masters the pack knows: its
    travel table's, else its own flight master NPCs (matched to the nodes by position)."""
    nodes: list[FlightNode] = []
    for map_id in sorted(geo.maps):
        for entry in geo.maps[map_id].get("taxi") or []:
            if not isinstance(entry, dict) or not isinstance(entry.get("n"), str):
                continue
            name = entry["n"]
            if not name or name.lower().startswith("zzold"):  # stale nodes the client still lists
                continue
            zone = coord = None
            x, y = entry.get("x"), entry.get("y")
            if isinstance(x, (int, float)) and isinstance(y, (int, float)):
                point = geo.world(Coord(map_id, float(x), float(y)))
                zone = _taxi_zone(geo, name, point) if point else None
                coord = geo.local(zone, point) if zone is not None and point else None
            nodes.append(FlightNode(name, side_of(entry.get("faction")), zone, coord, entry.get("id")))
    masters = dict(_keyed(pack.table("travel").get("flightMasters")))
    from_npcs = derive_flight_masters(pack, geo, nodes, set(masters))
    masters.update(from_npcs)
    for npc, master in sorted(masters.items(), key=_by_id):
        if not isinstance(master, dict) or not isinstance(master.get("node"), str):
            continue
        coord, side = coord_of(master.get("p")), side_of(master.get("side"))
        origin = f"flight master {npc} ({'data pack NPC record' if npc in from_npcs else 'data pack'})"
        matched = False
        for index, node in enumerate(nodes):
            if names_match(node.name, master["node"]) and (side == "both" or node.side in ("both", side)):
                matched = True
                if coord:
                    zone = geo.zone(coord.map)
                    nodes[index] = FlightNode(node.name, node.side, zone, coord, node.node_id, origin, True)
        if not matched and coord:
            nodes.append(FlightNode(master["node"], side, geo.zone(coord.map), coord, None, origin, True))
    return nodes


def phrases(value: object) -> str:
    """Words from a string, or from a list of phrases read as "a, b and c" (a long sentence of data stays on short lines)."""
    if isinstance(value, str):
        return value
    items = [item for item in value if isinstance(item, str) and item] if isinstance(value, list) else []
    return items[0] if len(items) == 1 else ", ".join(items[:-1]) + " and " + items[-1] if items else ""


@dataclass(frozen=True)
class Transport:
    """A boat or zeppelin between two zones. Its docks are known (the pack's record: someone rode it) or not yet (a ride
    in Guides/Travel/Borders.lua: hand-authored with the zones only, since a dock position is never made up)."""

    kind: str  # boat or zeppelin
    a: Coord | None
    b: Coord | None
    side: str
    zone_a: int | None = None
    zone_b: int | None = None
    label: str = ""  # what the guides call it ("airship"); the step says it instead of the kind
    wait: float = TRANSPORT_WAIT  # seconds at the dock
    wait_text: str = ""  # the wait in the player's words ("7 to 8 minutes")
    from_text: str = ""  # where it leaves, in words ("Valanaar's southwest dock")
    to_text: str = ""  # where it lands
    verify: str = ""  # what nobody has confirmed in the game, in words
    oneway: bool = False  # only from a to b is known
    origin: str = ""

    @property
    def placed(self) -> bool:
        return self.a is not None and self.b is not None


@dataclass(frozen=True)
class Crossing:
    """A walkable border: the last point in zone A and the first in zone B (either may still be unknown)."""

    name: str
    a: Coord | None
    b: Coord | None
    zone_a: int | None
    zone_b: int | None
    origin: str
    side: str = "both"

    @property
    def placed(self) -> bool:
        return self.a is not None and self.b is not None


@dataclass(frozen=True)
class Inn:
    npc: object
    coord: Coord
    side: str


class World:
    """The travel graph's data for one faction (without a pack the graph is empty and zones are the maps as given)."""

    def __init__(self, pack: Pack | None = None, borders: list | None = None, faction: str = "*") -> None:
        self.pack = pack or Pack()
        self.geo = Geo(self.pack.table("maps"))
        self.faction = faction
        self.all_nodes = flight_nodes(self.pack, self.geo)
        self.nodes = [node for node in self.all_nodes if usable(node.side, faction)]
        travel = self.pack.table("travel")
        self.transports = []
        for entry in travel.get("transports") or []:
            if not isinstance(entry, dict):
                continue
            a, b, side = coord_of(entry.get("from")), coord_of(entry.get("to")), side_of(entry.get("side"))
            if a and b and entry.get("kind") in ("boat", "zeppelin") and usable(side, faction):
                self.transports.append(
                    Transport(entry["kind"], a, b, side, zone_a=self.zone(a.map), zone_b=self.zone(b.map), origin="data pack")
                )
        self.inns = []
        listed = _keyed(travel.get("inns"))
        for npc, entry in listed.items():
            coord = coord_of(entry.get("p")) if isinstance(entry, dict) else None
            if coord and usable(side_of(entry.get("side")), faction):
                self.inns.append(Inn(npc, coord, side_of(entry.get("side"))))
        # The pack's own innkeeper NPCs (the QuestieDB layer flags them) cover the inns no travel record lists.
        for npc, record in service_npcs(self.pack, INNKEEPER_FLAG):
            coord = coord_of(record.get("p"))
            if npc not in listed and coord and usable(side_of(record.get("side")), faction):
                self.inns.append(Inn(npc, coord, side_of(record.get("side"))))
        learned = [self._crossing(entry, "data pack") for entry in travel.get("crossings") or []]
        learned = [crossing for crossing in learned if crossing and usable(crossing.side, faction)]
        hand, rides = [], []
        for path, line, entry in borders or []:
            if isinstance(entry, dict) and entry.get("ride") is not None:  # a ride is no walkable crossing, valid or not
                ride = self._ride(entry, entry["ride"], f"{path}:{line}") if isinstance(entry["ride"], dict) else None
                if ride and usable(ride.side, faction):
                    rides.append(ride)
            else:
                hand.append(self._crossing(entry, f"{path}:{line}"))
        self._add_rides(rides)
        # Learned crossings replace hand-authored ones of the same name, and coordinate-less ones for the same zones.
        for crossing in [c for c in hand if c and usable(c.side, faction)]:
            pair = {crossing.zone_a, crossing.zone_b}
            if any(
                (crossing.name and other.name.lower() == crossing.name.lower())
                or (not crossing.placed and other.placed and {other.zone_a, other.zone_b} == pair)
                for other in learned
            ):
                continue
            learned.append(crossing)
        self.crossings = learned

    def _crossing(self, entry: object, origin: str) -> Crossing | None:
        if not isinstance(entry, dict):
            return None
        a, b = coord_of(entry.get("from")), coord_of(entry.get("to"))
        map_a = a.map if a else map_of(entry.get("from"))
        map_b = b.map if b else map_of(entry.get("to"))
        if map_a is None or map_b is None:
            return None
        name = entry.get("name") if isinstance(entry.get("name"), str) else ""
        if isinstance(entry.get("src"), str):
            origin = f"{origin} ({entry['src']})"
        return Crossing(name, a, b, self.zone(map_a), self.zone(map_b), origin, side_of(entry.get("side")))

    def _ride(self, entry: dict, ride: dict, origin: str) -> Transport | None:
        """A hand-authored ride (Guides/Travel/Borders.lua): the zones, the kind, and words for the player. Its docks are
        read as coordinates only if the entry holds them; the tools never make one up."""
        map_a, map_b = map_of(entry.get("from")), map_of(entry.get("to"))
        if ride.get("kind") not in ("boat", "zeppelin") or map_a is None or map_b is None:
            return None

        def words(key: str) -> str:
            return phrases(ride.get(key))

        wait = ride.get("wait")
        usable_wait = isinstance(wait, (int, float)) and not isinstance(wait, bool) and wait >= 0
        return Transport(
            ride["kind"],
            coord_of(entry.get("from")),
            coord_of(entry.get("to")),
            side_of(entry.get("side")),
            zone_a=self.zone(map_a),
            zone_b=self.zone(map_b),
            label=words("label"),
            wait=float(wait) if usable_wait else TRANSPORT_WAIT,
            wait_text=words("waitText"),
            from_text=words("fromText"),
            to_text=words("toText"),
            verify=words("verify"),
            oneway=entry.get("oneWay") is True,
            origin=origin,
        )

    def _add_rides(self, rides: list[Transport]) -> None:
        """A ride someone recorded (the pack's transports, docks and all) replaces the hand-authored one between the same two
        zones, as a learned crossing does; it keeps the hand-authored name, wait and direction, which the record lacks."""
        for ride in rides:
            pair = {ride.zone_a, ride.zone_b}
            found = next((n for n, t in enumerate(self.transports) if t.placed and {t.zone_a, t.zone_b} == pair), None)
            if found is None:
                self.transports.append(ride)
            else:
                recorded = self.transports[found]
                self.transports[found] = replace(
                    recorded, label=ride.label, wait=ride.wait, wait_text=ride.wait_text, oneway=ride.oneway
                )

    def inn_in(self, zone: int | None) -> Coord | None:
        """An innkeeper's position in that zone (the data pack's), when there is exactly one."""
        found = [inn.coord for inn in self.inns if self.zone(inn.coord.map) == zone]
        return found[0] if len(found) == 1 else None

    def zone(self, map_id: int) -> int:
        return self.geo.zone(map_id) if self.geo.known(map_id) else map_id

    def within(self, map_id: int, ancestor: int) -> bool:
        return self.geo.within(map_id, ancestor) if self.geo.known(map_id) else map_id == ancestor

    def label(self, zone: int | None) -> str:
        return self.geo.label(zone)

    def nodes_named(self, name: str, every_faction: bool = False) -> list[FlightNode]:
        return [node for node in (self.all_nodes if every_faction else self.nodes) if names_match(node.name, name)]

    def quest_coords(self, quest_id: int, part: str) -> list[Coord]:
        """Where a quest starts ("s") or ends ("e"): its NPCs' and objects' positions in the data pack."""
        quest = self.pack.table("quests").get(quest_id)
        ends = quest.get(part) if isinstance(quest, dict) else None
        if not isinstance(ends, dict):
            return []
        coords: list[Coord] = []
        for kind, table in (("npc", "npcs"), ("obj", "objects")):
            ids = ends.get(kind)
            for ident in ids if isinstance(ids, list) else [ids] if ids else []:
                record = self.pack.table(table).get(ident)
                coords += coords_of(record.get("p")) if isinstance(record, dict) else []
        return coords


# Simulation ----------------------------------------------------------------------------------------------------------


@dataclass
class KnownFP:
    name: str
    map: int
    zone: int
    step: RouteStep


@dataclass
class Bind:
    name: str
    zone: int | None
    coord: Coord | None
    step: RouteStep


@dataclass
class Transition:
    index: int  # route index of the step that arrives in another zone
    before: RouteStep | None  # the step that put the player in the previous zone
    after: RouteStep
    from_zone: int
    to_zone: int
    from_coord: Coord | None
    to_coord: Coord | None
    fps: list[KnownFP]
    bind: Bind | None
    hearth_ready: bool


@dataclass
class SimStep:
    step: RouteStep
    zone_in: int | None
    zone_out: int | None
    coord_out: Coord | None
    level: int
    fps: list[str]
    bind: str | None
    clock: float
    seconds: float = 0.0  # what the step's travel took: walking, flights, boats (not STEP_SECONDS)


@dataclass
class SimIssue:
    step: RouteStep
    line: int | None  # line in the step's source text
    severity: str
    code: str
    message: str


@dataclass
class Simulation:
    steps: list[SimStep] = field(default_factory=list)
    transitions: list[Transition] = field(default_factory=list)
    issues: list[SimIssue] = field(default_factory=list)


@dataclass
class _Event:
    kind: str | None  # "point" (a target), "arrive" (where a travel directive leaves the player) or None
    zone: int | None
    coord: Coord | None
    directive: Directive
    effect: str | None = None  # fp, hs, fly, home


def fly_destination(world: World, name: str, fps: list[KnownFP]) -> tuple[int | None, Coord | None]:
    """Where `.fly <name>` lands: a flight master record, else the zone the guide's `.fp` gave, else the taxi map."""
    exact = [node for node in world.nodes_named(name) if node.exact]
    if exact:
        return exact[0].zone, exact[0].coord
    taught = [fp for fp in fps if names_match(fp.name, name)]
    guessed = [node for node in world.nodes_named(name) if node.zone is not None]
    if taught:
        zone = taught[-1].zone
        return zone, next((node.coord for node in guessed if node.zone == zone), None)
    if guessed and len({node.zone for node in guessed}) == 1:
        return guessed[0].zone, guessed[0].coord
    return None, None


def _step_events(rs: RouteStep, world: World, fps: list[KnownFP], bind: Bind | None, zone: int | None) -> list[_Event]:
    explicit = any(d.name in ("goto", "path", "fish", "boat", "zeppelin", "fp") for d in rs.directives)
    taught = list(fps)
    events: list[_Event] = []
    for d in rs.directives:
        args = d.args
        if d.name in ("goto", "fish"):
            events.append(_Event("point", world.zone(args["coord"].map), args["coord"], d))
        elif d.name == "fp":
            events.append(_Event("point", world.zone(args["map"]), None, d, "fp"))
            taught.append(KnownFP(args["node"], args["map"], world.zone(args["map"]), rs))
        elif d.name == "path":
            first, *rest = args["points"]
            events.append(_Event("point", world.zone(first.map), first, d))
            events += [_Event("arrive", world.zone(point.map), point, d) for point in rest]
        elif d.name in ("boat", "zeppelin"):
            events.append(_Event("point", world.zone(args["from"].map), args["from"], d))
            events.append(_Event("arrive", world.zone(args["to"].map), args["to"], d))
        elif d.name == "zone":
            events.append(_Event("arrive", world.zone(args["map"]), None, d))
        elif d.name == "fly":
            destination, coord = fly_destination(world, args["node"], taught)
            events.append(_Event("arrive", destination, coord, d, "fly"))
        elif d.name == "home":
            events.append(_Event("arrive", bind.zone if bind else None, bind.coord if bind else None, d, "home"))
        elif d.name == "hs":
            events.append(_Event(None, None, None, d, "hs"))
        elif d.name in ("accept", "turnin") and not explicit:
            # No coordinates of its own: the quest giver's or ender's position in the data pack is the target.
            coords = world.quest_coords(args["quest"], "s" if d.name == "accept" else "e")
            if coords:
                here = events[-1].zone if events else zone
                pick = next((coord for coord in coords if world.zone(coord.map) == here), coords[0])
                events.append(_Event("point", world.zone(pick.map), pick, d))
    return events


def _across(world: World, coord: Coord | None, event: _Event) -> bool:
    """A walk from `coord` to the event's point that goes between two world instances (continents)."""
    if coord is None or event.coord is None or event.kind != "point":
        return False
    here, there = world.geo.instance(coord.map), world.geo.instance(event.coord.map)
    return here is not None and there is not None and here != there


def _seconds(world: World, coord: Coord | None, event: _Event, prices: pricing.Prices | None = None) -> float:
    """What one event of a step costs the player, who stands at `coord`: the prices are signpost_tools/pricing.py's."""
    prices = prices or pricing.PRICES
    distance = world.geo.distance(coord, event.coord)
    if event.effect == "fly":
        return prices.flight(distance)
    if event.effect == "home":
        return prices.hearth
    if event.directive.name in ("boat", "zeppelin") and event.kind == "arrive":
        return prices.transport(distance)
    if distance is None:
        # A walk that cannot be measured costs nothing, except a change of continent: nobody walks that, and no travel step says how it
        # is made (the pack has no zeppelin or boat yet), so it costs what the planner charges for one.
        return prices.continent if _across(world, coord, event) else 0.0
    return prices.walk(distance)


def simulate(route: Route, world: World, prices: pricing.Prices | None = None) -> Simulation:
    """Walk the route: zones, flight paths, hearth, expected level; uncovered transitions and travel problems. Each step's travel
    time is SimStep.seconds, priced by signpost_tools/pricing.py. A change of zone is never free: a `.zone` step leaves the player
    nowhere in particular, and the walk to the next place is measured from the last place the route named (it used to cost nothing)."""
    prices = prices or pricing.PRICES
    sim = Simulation()
    zone: int | None = None
    coord: Coord | None = None
    last_point: Coord | None = None  # the last position the walk knew: where a walk starts when a zone change left `coord` unknown
    setter: RouteStep | None = None
    fps: list[KnownFP] = []
    bind: Bind | None = None
    last_home: float | None = None
    clock = 0.0
    level = 0
    for index, rs in enumerate(route.steps):
        levels = [d.args["level"] for d in rs.directives if d.name == "level"]
        level = max(level, route.chapters[rs.chapter].levels[0], *levels)
        zone_in = zone
        events = _step_events(rs, world, fps, bind, zone)
        arrivals = {event.zone for event in events if event.kind == "arrive"}
        travels = any(d.name in guidefile.TRAVEL_MOVES for d in rs.directives)
        checked = False
        spent = 0.0
        for event in events:
            d = event.directive
            if event.effect == "fly" and not any(names_match(fp.name, d.args["node"]) for fp in fps):
                message = f".fly {d.args['node']}: no earlier .fp teaches it"
                sim.issues.append(SimIssue(rs, d.line, "error", "fly-without-fp", message))
            if event.effect == "home":
                if bind is None:
                    message = ".home before any .hs: the bind location is unknown"
                    sim.issues.append(SimIssue(rs, d.line, "warning", "home-without-hs", message))
                elif last_home is not None and clock - last_home < HEARTH_COOLDOWN:
                    minutes = round((clock - last_home) / 60)
                    message = f".home about {minutes} min after the previous one: the hearthstone may be on cooldown"
                    sim.issues.append(SimIssue(rs, d.line, "warning", "hearth-cooldown", message))
                last_home = clock
            if event.kind == "point":
                if not checked:
                    checked = True
                    if zone is not None and event.zone != zone and event.zone not in arrivals and None not in arrivals:
                        ready = last_home is None or clock - last_home >= HEARTH_COOLDOWN
                        sim.transitions.append(
                            Transition(index, setter, rs, zone, event.zone, coord, event.coord, list(fps), bind, ready)
                        )
                elif zone is not None and event.zone != zone and not travels:
                    message = f"targets in {world.label(zone)} and {world.label(event.zone)} in one step with no travel"
                    sim.issues.append(SimIssue(rs, d.line, "warning", "zone-jump", message))
            if event.kind is not None:
                origin = coord if coord is not None else (last_point if event.kind == "point" else None)
                took = _seconds(world, origin, event, prices)
                clock += took
                spent += took
                zone, coord, setter = event.zone, event.coord, rs
                if event.coord is not None:
                    last_point = event.coord
                elif event.effect in ("fly", "home"):
                    last_point = None  # a flight or a hearthstone to a place the data does not give moved the player: the old point is stale
            if event.effect == "fp":
                fps.append(KnownFP(d.args["node"], d.args["map"], world.zone(d.args["map"]), rs))
            elif event.effect == "hs":
                bind = Bind(d.args["inn"], zone, coord, rs)
        clock += STEP_SECONDS
        known = [fp.name for fp in fps]
        sim.steps.append(SimStep(rs, zone_in, zone, coord, level, known, bind.name if bind else None, clock, spent))
    return sim


# Planning ------------------------------------------------------------------------------------------------------------


@dataclass
class Place:
    zone: int | None
    coord: Coord | None
    kind: str  # start, goal, crossing, node, dock, inn
    label: str = ""
    ref: object = None


@dataclass
class Leg:
    kind: str  # walk, cross, cross-todo, fly, boat, zeppelin, ride-todo (a ride whose docks are not recorded), hearth
    a: Place
    b: Place
    seconds: float
    ref: object = None


@dataclass
class Plan:
    legs: list[Leg]
    seconds: float


def _walk_seconds(world: World, a: Place, b: Place) -> float:
    distance = world.geo.distance(a.coord, b.coord)
    return distance / WALK_SPEED if distance is not None else UNKNOWN_WALK


def plan_travel(
    world: World,
    start: Place,
    goal: Place,
    known: list[str] = (),
    bind: Place | None = None,
    hearth_ready: bool = False,
) -> Plan | None:
    """The cheapest way from start to goal over walks, crossings, known flight paths, boats/zeppelins and the hearth."""
    places: list[Place] = [start, goal]
    edges: dict[int, list[tuple[int, Leg]]] = {}

    def add(place: Place) -> int:
        places.append(place)
        return len(places) - 1

    def link(i: int, j: int, kind: str, seconds: float, ref: object = None) -> None:
        edges.setdefault(i, []).append((j, Leg(kind, places[i], places[j], seconds, ref)))

    for crossing in world.crossings:
        i = add(Place(crossing.zone_a, crossing.a, "crossing", crossing.name, crossing))
        j = add(Place(crossing.zone_b, crossing.b, "crossing", crossing.name, crossing))
        if crossing.placed:
            seconds = _walk_seconds(world, places[i], places[j])
            kind = "cross"
        else:  # the zones are known to touch, the points are not: a `.todo` step, priced high
            seconds, kind = UNKNOWN_CROSS + TODO_PENALTY, "cross-todo"
        link(i, j, kind, seconds, crossing)
        link(j, i, kind, seconds, crossing)
    flights = [
        node for node in world.nodes if node.zone is not None and any(names_match(node.name, name) for name in known)
    ]
    flight_places = [add(Place(node.zone, node.coord, "node", node.name, node)) for node in flights]
    for i in flight_places:
        for j in flight_places:
            a, b = places[i], places[j]
            if i == j or a.ref is b.ref:
                continue
            if a.coord is None or b.coord is None or world.geo.instance(a.coord.map) == world.geo.instance(b.coord.map):
                distance = world.geo.distance(a.coord, b.coord)
                seconds = FLIGHT_OVERHEAD + distance / FLIGHT_SPEED if distance is not None else UNKNOWN_FLIGHT
                link(i, j, "fly", seconds, b.ref)
    for transport in world.transports:
        i = add(Place(transport.zone_a, transport.a, "dock", transport.kind, transport))
        j = add(Place(transport.zone_b, transport.b, "dock", transport.kind, transport))
        distance = world.geo.distance(transport.a, transport.b)
        seconds = transport.wait + (distance / TRANSPORT_SPEED if distance is not None else TRANSPORT_ACROSS)
        kind = transport.kind
        if not transport.placed:  # the zones are linked, the docks are not known: a `.todo` step, priced high
            seconds, kind = seconds + TODO_PENALTY, "ride-todo"
        link(i, j, kind, seconds, transport)
        if not transport.oneway:
            link(j, i, kind, seconds, transport)
    if bind is not None and hearth_ready and bind.zone is not None:
        link(0, add(bind), "hearth", HEARTH_SECONDS, bind)
    by_zone: dict[int, list[int]] = {}
    for index, place in enumerate(places):
        if place.zone is not None:
            by_zone.setdefault(place.zone, []).append(index)
    for members in by_zone.values():
        for i in members:
            for j in members:
                if i != j and j != 0 and places[i].kind != "goal":
                    link(i, j, "walk", _walk_seconds(world, places[i], places[j]))

    best = {0: 0.0}
    previous: dict[int, tuple[int, Leg]] = {}
    queue = [(0.0, 0)]
    while queue:
        seconds, index = heapq.heappop(queue)
        if index == 1:
            break
        if seconds > best.get(index, math.inf):
            continue
        for target, leg in edges.get(index, []):
            total = seconds + leg.seconds
            if total < best.get(target, math.inf):
                best[target] = total
                previous[target] = (index, leg)
                heapq.heappush(queue, (total, target))
    if 1 not in best:
        return None
    legs, index = [], 1
    while index != 0:
        index, leg = previous[index]
        legs.append(leg)
    return Plan(legs[::-1], best[1])


def fly_name(world: World, node: FlightNode) -> str:
    """The short node name when it is unambiguous for this faction, else the full one."""
    short = node.name.split(",")[0].strip()
    clash = [other for other in world.nodes if other is not node and names_match(other.name, short)]
    return node.name if clash else short


def _plain(text: str) -> str:
    """Text for a quoted `.todo`: no double quote, no `--` (a comment) and no `>>` (the text of the line)."""
    return text.replace('"', "'").replace("--", "-").replace(">>", ">")


def placeholder_lines(world: World, from_zone: int | None, to_zone: int) -> list[str]:
    """One travel step the guide cannot give directions for yet: a `.todo` that says in plain words what the player does
    (from what the data knows: the two zones, and whether they share a continent) and the `.zone` that completes it. No
    coordinate is written: the step must not look as if it were placed (the `.goto` of a step positions it for the
    profession tracks' `@zone` anchors, so a pin to the destination would move the step into the zone it ends in)."""
    geo = world.geo
    here, there = _plain(geo.name(from_zone)) if from_zone is not None else "here", _plain(geo.name(to_zone))
    worlds = (geo.instance(from_zone) if from_zone is not None else None, geo.instance(to_zone))
    if None in worlds:
        what = f"Get from {here} to {there}: the guide has no route for this yet."
    elif worlds[0] != worlds[1]:
        what = (
            f"Get from {here} to {there}: they are on different continents, so you need a boat, a zeppelin or another ride, "
            "and the guide has no dock for it yet."
        )
    else:
        what = f"Walk from {here} to {there}: the guide has no waypoints for this yet, so find your own way."
    return [f'.todo "{what} This step is done when you arrive in {there}."', f".zone {to_zone} >> Go to {there}"]


def ride_lines(world: World, leg: Leg) -> list[str]:
    """The step for a ride whose docks nobody has recorded (a hand-authored ride, Guides/Travel/Borders.lua): what to take,
    from where to where, how long to wait, and in plain words what nobody has confirmed in the game. It is still a `.todo`
    (the dock position is missing) and a `.zone` (the step is done on arrival), and carries no coordinate."""
    ride = leg.ref
    forward = leg.a.zone == ride.zone_a
    here, there = _plain(world.geo.name(leg.a.zone)), _plain(world.geo.name(leg.b.zone))
    start, end = (ride.from_text, ride.to_text) if forward else (ride.to_text, ride.from_text)
    label = _plain(ride.label or ride.kind)
    origin = f"{_plain(start)} ({here})" if start else here
    target = f"{_plain(end)} ({there})" if end else there
    lines = [f".zone {leg.b.zone} >> Take the {label} from {origin} to {target}"]
    if ride.wait_text:
        lines.append(f".note Expect to wait about {_plain(ride.wait_text)} for it.")
    unverified = _plain(ride.verify) if ride.verify else "where the dock is"
    lines.append(f'.todo "Not verified in the game: {unverified}. This step is done when you arrive in {there}."')
    return lines


def plan_steps(world: World, plan: Plan) -> list[list[str]]:
    """The plan as DSL steps (each a list of directive lines). Coordinates come only from the graph's data; a run of
    borders whose crossing points are not known yet is one `.todo` step for the whole walk."""
    steps: list[list[str]] = []
    unplaced: list[Leg] = []

    def flush() -> None:
        if unplaced:
            steps.append(placeholder_lines(world, unplaced[0].a.zone, unplaced[-1].b.zone))
            unplaced.clear()

    for leg in plan.legs:
        zone = leg.b.zone
        if leg.kind == "walk":  # inside a zone: no step of its own
            continue
        if leg.kind == "cross-todo":
            unplaced.append(leg)
            continue
        flush()
        if leg.kind == "cross":
            crossing = leg.ref
            via = f" ({crossing.name})" if crossing.name else ""
            steps.append(
                [
                    f".path {leg.a.coord.dsl()} ; {leg.b.coord.dsl()}",
                    f".zone {zone} >> Cross into {world.geo.name(zone)}{via}",
                ]
            )
        elif leg.kind == "fly":
            lines = []
            if leg.a.coord is not None:
                origin = "" if leg.a.ref.exact else "  -- position from the client's taxi map"
                lines.append(f".goto {leg.a.coord.dsl()} >> Go to the flight master{origin}")
            lines.append(f".fly {fly_name(world, leg.ref)}")
            steps.append(lines)
        elif leg.kind == "ride-todo":
            steps.append(ride_lines(world, leg))
        elif leg.kind in ("boat", "zeppelin"):
            route = f"{leg.a.coord.dsl()} > {leg.b.coord.dsl()}"
            label = _plain(leg.ref.label) if getattr(leg.ref, "label", "") else leg.kind
            steps.append([f".{leg.kind} {route} >> Take the {label} to {world.geo.name(zone)}"])
        elif leg.kind == "hearth":
            steps.append([f".home >> Hearth to {leg.b.label}"])
    flush()
    return steps


def no_route_steps(world: World, from_zone: int, to_zone: int) -> list[list[str]]:
    """The placeholder for a change of zone the graph has no route for (see placeholder_lines)."""
    return [placeholder_lines(world, from_zone, to_zone)]


def render_steps(steps: list[list[str]]) -> str:
    return "\n".join("step\n" + "\n".join(f"  {line}" for line in lines) for lines in steps)


def describe_cost(plan: Plan | None) -> str:
    if plan is None:
        return "no route"
    if any(leg.kind == "cross-todo" for leg in plan.legs):
        return "time unknown (a border without coordinates)"
    if any(leg.kind == "ride-todo" for leg in plan.legs):
        return "time unknown (a ride whose docks are not recorded)"
    return f"about {max(1, round(plan.seconds / 60))} min"


def _places(world: World, transition: Transition) -> tuple[Place, Place, Place | None]:
    start = Place(transition.from_zone, transition.from_coord, "start", "start")
    goal = Place(transition.to_zone, transition.to_coord, "goal", "goal")
    bind = None
    if transition.bind is not None and transition.bind.zone is not None:
        here = transition.bind.coord or world.inn_in(transition.bind.zone)  # only used to cost the walk from the inn
        bind = Place(transition.bind.zone, here, "inn", transition.bind.name)
    return start, goal, bind


def propose(world: World, transition: Transition) -> tuple[Plan | None, list[list[str]]]:
    """The cheapest travel for an uncovered transition, as DSL steps (a .todo step when the graph has no route)."""
    start, goal, bind = _places(world, transition)
    plan = plan_travel(world, start, goal, [fp.name for fp in transition.fps], bind, transition.hearth_ready)
    if plan is None:
        return None, no_route_steps(world, transition.from_zone, transition.to_zone)
    return plan, plan_steps(world, plan)


# Command line --------------------------------------------------------------------------------------------------------


def plan_order(project: guidefile.Project, keys: list[str]) -> list[str]:
    """A plan's merge order: primary professions first, then the rest, each in the given order."""
    primary = [key for key in keys if (project.professions.get(key) and project.professions[key].primary) is True]
    return primary + [key for key in keys if key not in primary]


def guide_routes(project: guidefile.Project, guide: guidefile.Guide, options, world_for) -> list[Route]:
    """The routes to simulate for one guide: its variants (filtered by --faction/--race/--class), tracks merged."""
    routes = []
    expansion = guidefile.expand(project, guide)
    seen = set()
    for variant in guidefile.variants(project, guide, expansion):
        wanted = ((variant.faction, options.faction), (variant.race, options.race), (variant.cls, options.cls))
        if any(choice and value != choice for value, choice in wanted):
            continue
        if options.profession:
            keys = list(options.profession)
        elif options.no_tracks:
            keys = []
        else:
            order = guide.professions
            keys = sorted(variant.plan, key=lambda key: (order.index(key) if key in order else len(order), key))
        identity = (variant.faction, variant.race, variant.cls, tuple(keys))
        if identity in seen:  # variants that differ only in a plan the merge does not use
            continue
        seen.add(identity)
        route = guidefile.build_route(project, guide, variant, expansion)
        if keys:
            within = world_for(variant.faction).within
            route, _ = guidefile.merge_tracks(project, route, plan_order(project, keys), within)
        routes.append(route)
    return routes


def _after(rs: RouteStep | None) -> str:
    """Where travel steps for a transition go: after the last line of the step before it."""
    if rs is None:
        return "the start of the guide"
    return f"{rs.source.path}:{rs.source.file_line(rs.step.end_line)}"


# Flight paths learned on the way ---------------------------------------------------------------------------------------
#
# A `.fly` needs an earlier `.fp` that teaches it, and nothing in a guide teaches one until its author adds the step. A route
# passes flight masters all the time (the quest hubs are towns), so where passing one would let a later change of zone fly
# instead of walk, the generator proposes the `.fp` step too: right after the step that passes the flight master. Only
# flight paths a later zone change would use are proposed, so the guide never asks for a detour for nothing, and a zone
# change that waits for one is proposed in the pass after the `.fp` step is in (rebuild_drafts and the planner repeat the
# pass until nothing is left to propose). The flight masters are the pack's: the travel table's, else its own NPC records
# (a Classic baseline, matched to the client's flight nodes).

LEARN_FLIGHT_PATHS = True  # propose `.fp` steps; `--no-learn-flight-paths` turns it off for one run
LEARN_RADIUS = 150.0  # yards: a step this close to a flight master passes it (the planner's hubs are 150 yd wide)
LEARN_GAIN = 90.0  # seconds a flight must save on a zone change before the route is asked to learn a flight path for it


@dataclass
class Lesson:
    """A flight path the route can learn where it passes the flight master."""

    node: FlightNode
    index: int  # the route step that passes the flight master (the `.fp` step goes after it)
    step: RouteStep


def route_points(route: Route, world: World) -> list[list[tuple[int, Coord]]]:
    """Where each step sends the player, as (zone, position): what `simulate` reads from the step (its `.goto`, `.path`,
    `.fish`, boat and zeppelin ends, flight landings, and the pack's quest givers for an `.accept` or `.turnin`)."""
    found = []
    for rs in route.steps:
        events = _step_events(rs, world, [], None, None)
        found.append([(event.zone, event.coord) for event in events if event.coord is not None and event.zone is not None])
    return found


def learnable_flight_paths(route: Route, world: World, sim: Simulation, radius: float = LEARN_RADIUS) -> list[Lesson]:
    """The flight paths the route does not teach, at the first step that ends in the flight master's zone having passed it."""
    if not sim.steps:
        return []
    points = route_points(route, world)
    taught = sim.steps[-1].fps
    lessons = []
    for node in world.nodes:
        if not node.exact or node.zone is None or node.coord is None:
            continue
        if any(names_match(name, node.name) for name in taught):
            continue
        for index, rs in enumerate(route.steps):
            if rs.track is not None or sim.steps[index].zone_out != node.zone:  # a track step belongs to a shared file
                continue
            near = (world.geo.distance(coord, node.coord) for zone, coord in points[index] if zone == node.zone)
            if any(distance is not None and distance <= radius for distance in near):
                lessons.append(Lesson(node, index, rs))
                break
    return lessons


def flights_to_learn(world: World, transition: Transition, lessons: list[Lesson], before: int) -> list[Lesson]:
    """The flight paths the route should learn before this zone change because the best plan with them flies: those the
    route passes at or before step `before` (-1: the start), not taught yet, and used by a flight of the faster plan."""
    known = [fp.name for fp in transition.fps]
    options = [
        lesson
        for lesson in lessons
        if lesson.index <= before and not any(names_match(name, lesson.node.name) for name in known)
    ]
    if not options:
        return []
    start, goal, bind = _places(world, transition)
    now = plan_travel(world, start, goal, known, bind, transition.hearth_ready)
    better = plan_travel(world, start, goal, known + [lesson.node.name for lesson in options], bind, transition.hearth_ready)
    # No plan without the flight paths means a placeholder step: any flight is an improvement. Otherwise it must save time.
    if better is None or (now is not None and now.seconds - better.seconds < LEARN_GAIN):
        return []
    used = [leg.a.ref for leg in better.legs if leg.kind == "fly"] + [leg.b.ref for leg in better.legs if leg.kind == "fly"]
    return [lesson for lesson in options if lesson.node in used]


def lesson_steps(world: World, lesson: Lesson) -> list[list[str]]:
    """The step that learns the flight path: go to the flight master, `.fp` (done when the game knows the node)."""
    node = lesson.node
    return [[f".goto {node.coord.dsl()} >> Go to the flight master", f".fp {node.coord.map},{fly_name(world, node)}"]]


def report_route(route: Route, world: World, simulate_steps: bool, learn: bool | None = None) -> list[str]:
    sim = simulate(route, world)
    lessons = learnable_flight_paths(route, world, sim) if (LEARN_FLIGHT_PATHS if learn is None else learn) else []
    position = {id(rs): index for index, rs in enumerate(route.steps)}
    # The flight paths to learn first: for each zone change that would fly if the route passed its flight masters earlier.
    asked: dict[str, tuple[Lesson, list[int]]] = {}  # node name -> (lesson, the zone changes that want it)
    for number, transition in enumerate(sim.transitions, 1):
        before = position.get(id(transition.before), -1) if transition.before is not None else -1
        for lesson in flights_to_learn(world, transition, lessons, before) if lessons else []:
            asked.setdefault(lesson.node.name, (lesson, []))[1].append(number)
    wanted = {number: [] for _, numbers in asked.values() for number in numbers}
    for lesson, numbers in asked.values():
        for number in numbers:
            wanted[number].append(lesson.node.name)
    # A flight path step goes in after the step that passes its flight master; travel steps for another zone change that
    # leaves from the same step wait for the next pass, so that the two never go in at the same place in the wrong order.
    anchors = {id(lesson.step) for lesson, _ in asked.values()}
    out = [f"== {route.guide.id} [{route.variant.label()}]: {len(sim.transitions)} uncovered zone change(s)"]
    if simulate_steps:
        out.append(f"   {'#':>4}  {'step':<28} {'zone':<28} {'level':>5}  flight paths / hearth")
        for number, state in enumerate(sim.steps, 1):
            zone = world.label(state.zone_out) if state.zone_out is not None else "-"
            extra = f"{len(state.fps)} FP" + (f", hearth {state.bind}" if state.bind else "")
            out.append(f"   {number:>4}  {state.step.id:<28} {zone:<28} {state.level:>5}  {extra}")
        for issue in sim.issues:
            where = f"{issue.step.source.path}:{issue.step.source.file_line(issue.line)}"
            out.append(f"   {where}: {issue.severity}: {issue.message}")
    for number, transition in enumerate(sim.transitions, 1):
        before = transition.before.id if transition.before else "start"
        heading = (
            f"-- {number}. {before} ({world.label(transition.from_zone)}) -> {transition.after.id} "
            f"({world.label(transition.to_zone)})"
        )
        if number in wanted:
            out += ["", f"{heading}, waits for the flight path(s) to learn first: {', '.join(wanted[number])}"]
            continue
        if transition.before is not None and id(transition.before) in anchors:
            out += ["", f"{heading}, waits: a flight path step goes in right after {transition.before.id} first"]
            continue
        plan, steps = propose(world, transition)
        known = ", ".join(fp.name for fp in transition.fps) or "none"
        bind = transition.bind.name if transition.bind else "unknown"
        out += [
            "",
            f"{heading}, {describe_cost(plan)}",
            f"-- insert after {_after(transition.before)}; flight paths known: {known}; hearth: {bind}",
            render_steps(steps),
        ]
    for lesson, numbers in sorted(asked.values(), key=lambda item: item[0].index):
        uses = ", ".join(str(n) for n in numbers)
        out += [
            "",
            f"-- flight path {lesson.node.name} ({world.label(lesson.node.zone)}): the route passes its flight master at "
            f"step {lesson.step.id}; zone change(s) {uses} fly from or to it",
            f"-- insert after {_after(lesson.step)}; flight path to learn on the way",
            render_steps(lesson_steps(world, lesson)),
        ]
    return out


def safe_stdout() -> None:
    """Names from the data pack may not fit a Windows console's code page: replace those characters, never crash."""
    reconfigure = getattr(sys.stdout, "reconfigure", None)
    if reconfigure is not None:
        reconfigure(errors="replace")


def _coord_arg(text: str, what: str) -> Coord:
    try:
        return guidefile.parse_coord(text)
    except guidefile.ArgError as exc:
        raise SystemExit(f"{what}: {exc}") from None


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--root", type=Path, default=REPO_ROOT, help="the Signpost checkout (default: this one)")
    parser.add_argument("--pack", type=Path, help="the data pack folder (default: ../Signpost_Data when present)")
    parser.add_argument("--no-pack", action="store_true", help="ignore the data pack")
    parser.add_argument("--guide", action="append", help="only this guide id (repeatable)")
    parser.add_argument("--faction", help="only this faction's variants (with --from: whose transports and flights)")
    parser.add_argument("--race", help="only this race's variants (raceFile token)")
    parser.add_argument("--class", dest="cls", help="only this class's variants (classFile token)")
    parser.add_argument("--profession", action="append", default=[], help="merge exactly these tracks (repeatable)")
    parser.add_argument("--no-tracks", action="store_true", help="simulate the route without profession tracks")
    parser.add_argument("--simulate", action="store_true", help="print the step-by-step simulation")
    parser.add_argument("--from", dest="start", help="plan one trip from <map>,<x>,<y>")
    parser.add_argument("--to", dest="goal", help="with --from: to <map>,<x>,<y>")
    parser.add_argument("--fp", action="append", default=[], help="with --from: a known flight path (repeatable)")
    parser.add_argument("--bind", help="with --from: <map>,<x>,<y> of the inn the hearthstone is set to")
    parser.add_argument(
        "--no-learn-flight-paths",
        action="store_true",
        help="do not propose `.fp` steps for flight masters the route passes (a later zone change would fly from them)",
    )
    options = parser.parse_args(argv)
    safe_stdout()

    project = guidefile.load_project(options.root)
    pack = load_pack(None if options.no_pack else options.pack or default_pack_dir(options.root))
    print(pack.describe())
    if options.start or options.goal:
        if not (options.start and options.goal):
            parser.error("--from and --to go together")
        world = World(pack, project.borders, options.faction or "*")
        start, goal = _coord_arg(options.start, "--from"), _coord_arg(options.goal, "--to")
        bind = None
        if options.bind:
            inn = _coord_arg(options.bind, "--bind")
            bind = Place(world.zone(inn.map), inn, "inn", "the inn")
        plan = plan_travel(
            world,
            Place(world.zone(start.map), start, "start"),
            Place(world.zone(goal.map), goal, "goal"),
            options.fp,
            bind,
            bind is not None,
        )
        from_zone, to_zone = world.zone(start.map), world.zone(goal.map)
        steps = plan_steps(world, plan) if plan else no_route_steps(world, from_zone, to_zone)
        print(f"-- {world.label(from_zone)} -> {world.label(to_zone)}: {describe_cost(plan)}")
        print(render_steps(steps))
        return 0
    guides = [guide for gid, guide in sorted(project.guides.items()) if not options.guide or gid in options.guide]
    if not guides:
        print("no guides" + (f" named {', '.join(options.guide)}" if options.guide else ""))
        return 0
    worlds: dict[str, World] = {}

    def world_for(faction: str) -> World:
        if faction not in worlds:
            worlds[faction] = World(pack, project.borders, faction)
        return worlds[faction]

    for guide in guides:
        for route in guide_routes(project, guide, options, world_for):
            learn = False if options.no_learn_flight_paths else None
            print("\n".join(report_route(route, world_for(route.variant.faction), options.simulate, learn)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
