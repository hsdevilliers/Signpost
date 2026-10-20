"""Import QuestieDB's WoW: Forever data into the private data pack's `questie` layer (PLAN §6; CLAUDE.md, Data sources).

    python tools/questie_import.py                     Horde and neutral quests and what they reference, Forever layers on
    python tools/questie_import.py --no-forever-layers the converted Classic Era baseline tables only
    python tools/questie_import.py --faction both      both factions
    python tools/questie_import.py --check-maps 1411,1413 --check-races 128 --check-classes 4
                                                       afterwards, check the quests of those maps (see --check-maps)

Reads the pinned QuestieDB checkout (default <out>/cache/questiedb): data/Forever/forever{Quest,Npc,Object,Item}DB.lua
and support/Forever/Zones/areaIdToUiMapId.lua. Those tables are a converted Classic Era baseline; QuestieDB's real Forever
content is layered on top as correction providers (src/corrections/Forever: generated delta-base, traces, authored fixes),
which are read as data and applied first (signpost_tools.lua_corrections, forever_layers; --no-forever-layers switches it off). QuestieDB is used with its maintainers' permission (Questie Discord,
2026-10-17) as an input to the private pack only. Its files are read as data and never executed: each key table
(`QuestieDB.<x>Keys`, including the commented part positions under a key) gives the field positions, and each
`[[return {...}]]` string holds the records.

Only route facts are kept: names, levels, race/class masks, faction, who starts and ends a quest, chains, objective
references by kind and ID, the items the quests touch with where they drop or are sold, the faction's service NPCs, and
positions (at most --clusters per map). Never quest text, item stats or prices, or QuestieDB's code, formats or
corrections. Writes layers/questie.json, rebuilds the pack (signpost_tools.datapack) and reports problems by kind and
ID only, in data-gaps.md.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from signpost_tools import datapack, devconfig, forever_layers  # noqa: E402
from signpost_tools.geo import cluster  # noqa: E402
from signpost_tools.lua_corrections import CorrectionsFormatError  # noqa: E402
from signpost_tools.savedvars import LuaParseError, parse_value  # noqa: E402

TOOL = "questie_import.py"
DEFAULT_PACK = devconfig.REPO_ROOT.parent / "Signpost_Data"
KINDS = ("quest", "npc", "object", "item")
DATA_FILE = "data/Forever/forever{}DB.lua"
ZONE_FILE = "support/Forever/Zones/areaIdToUiMapId.lua"
ZONE_OVERRIDE = "ZoneDB.private.areaIdToUiMapIdOverride"
ZONE_BASE = "ZoneDB.private.areaIdToUiMapId"
PROVENANCE_FILE = "support/Forever/provenance.json"

# The fields read from each table; their positions come from the file's key table.
FIELDS = {
    "quest": (
        "name",
        "startedBy",
        "finishedBy",
        "requiredLevel",
        "questLevel",
        "requiredRaces",
        "requiredClasses",
        "triggerEnd",
        "objectives",
        "sourceItemId",
        "preQuestGroup",
        "preQuestSingle",
        "exclusiveTo",
        "zoneOrSort",
        "requiredSkill",
        "requiredSourceItems",
        "nextQuestInChain",
        "specialFlags",
        "parentQuest",
        "breadcrumbForQuestId",
        "requiredMaxLevel",
    ),
    "npc": ("name", "spawns", "friendlyToFaction", "subName", "npcFlags", "rank"),
    "object": ("name", "spawns"),
    "item": ("name", "npcDrops", "objectDrops", "startQuest", "vendors"),
}
# Parts of composite quest fields; their positions come from the commented lines under the key. The objectives'
# kill-credit and spell parts are optional (skipped when the key table does not document them).
PARTS = {
    "startedBy": ("creatureStart", "objectStart", "itemStart"),
    "finishedBy": ("creatureEnd", "objectEnd"),
    "objectives": ("creatureObjective", "objectObjective", "itemObjective"),
}
# Quest fields copied as they are: (our name, QuestieDB's name). Zero means "not set" for all of them.
NUMBER_FIELDS = (
    ("l", "questLevel"),
    ("r", "requiredLevel"),
    ("maxLevel", "requiredMaxLevel"),
    ("races", "requiredRaces"),
    ("classes", "requiredClasses"),
)
LIST_FIELDS = (("preGroup", "preQuestGroup"), ("preSingle", "preQuestSingle"), ("exclusive", "exclusiveTo"))
ID_FIELDS = (("next", "nextQuestInChain"), ("parent", "parentQuest"), ("breadcrumbFor", "breadcrumbForQuestId"))

# Classic race bits (2^(raceID - 1)): Human 1, Orc 2, Dwarf 4, Night Elf 8, Undead 16, Tauren 32, Gnome 64, Troll 128.
# Forever's Skyborne races (raceIDs 95 and 96) are bits 32 and 33, not raceID - 1 (QuestieDB src/corrections/enum/expansions.lua
# raceMaskById); its aggregate masks ALL_ALLIANCE / ALL_HORDE are the Classic races plus the Skyborne bit of their side.
SKYBORNE_ALLIANCE = 4294967296  # 1 << 32
SKYBORNE_HORDE = 8589934592  # 1 << 33
ALLIANCE_RACES = 1 | 4 | 8 | 64 | SKYBORNE_ALLIANCE  # 77 + Skyborne
HORDE_RACES = 2 | 16 | 32 | 128 | SKYBORNE_HORDE  # 178 + Skyborne
FACTION_SIDES = {"horde": ("Horde", "both"), "alliance": ("Alliance", "both"), "both": ("Horde", "Alliance", "both")}
FACTION_LETTERS = {"horde": "H", "alliance": "A", "both": "AH"}  # friendlyToFaction letters of the faction's friends

# npcFlags bits. The key table points at cmangos mangos-classic's Unit.h NPCFlags; these six were checked against the
# NPC titles in the Forever data: every "Wind Rider Master" has 8, "Innkeeper" 128, "Stable Master" 8192, class and
# profession trainers 16, "General Goods" 4, "Armorer" 16384 (plus 4).
VENDOR, FLIGHT_MASTER, TRAINER, INNKEEPER, STABLE_MASTER, REPAIR = 4, 8, 16, 128, 8192, 16384
SERVICE_FLAGS = VENDOR | FLIGHT_MASTER | TRAINER | INNKEEPER | STABLE_MASTER | REPAIR
REPEATABLE = 1  # specialFlags bit
MAX_CLUSTERS = 3
CLUSTER_RADIUS = 3.0  # percent of the map
MAX_DROPS = 25

# Problem kinds (data-gaps.md lists each with its IDs). The "quests ..." ones list quest IDs.
P_NO_START = "quests without a start entity"
P_NO_END = "quests without an end entity"
P_START_UNPLACED = "quests whose start has no position"
P_END_UNPLACED = "quests whose end has no position"
P_ZONE_UNMAPPED = "quests whose zone AreaID has no uiMapID"
P_NO_ZONE = "quests without a zone or sort"
P_RACES = "quests whose race mask has no Classic or Skyborne race bit"
P_EXPLORE = "quests with an explore objective without coordinates"
P_AREAS = "AreaIDs without a uiMapID"


class QuestieFormatError(RuntimeError):
    """The QuestieDB files do not have the expected layout, so the importer would misread them."""


# Reading the files ----------------------------------------------------------------------------------------------------

_STATEMENT = re.compile(r"^(?=[A-Za-z_])", re.M)  # top-level statements start in column 1
_ASSIGNMENT = re.compile(r"([A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*)\s*=(?!=)\s*")
_KEY_LINE = re.compile(r"\s*\[\s*['\"](\w+)['\"]\s*\]\s*=\s*(\d+)")
_PART_LINE = re.compile(r"\s*--\s*\[\s*['\"](\w+)['\"]\s*\]\s*=\s*(\d+)")
_SHA = re.compile(r"[0-9a-f]{40}")


def read_assignments(path: Path, names: tuple[str, ...]) -> dict[str, tuple[object, str]]:
    """{name: (value, statement text)} for the top-level assignments to `names` in a QuestieDB Lua file.

    Only literal values are parsed (nothing is executed); a `[[return {...}]]` string is parsed again into its table.
    """
    if not path.is_file():
        raise QuestieFormatError(f"{path} is missing")
    text = path.read_bytes().decode("utf-8", "surrogateescape")
    found: dict[str, tuple[object, str]] = {}
    for statement in _STATEMENT.split(text):
        match = _ASSIGNMENT.match(statement)
        if not match or match.group(1) not in names:
            continue
        try:
            value = parse_value(statement[match.end() :])
            if isinstance(value, str):
                value = parse_value(value)
        except LuaParseError as exc:
            raise QuestieFormatError(f"{path}: {match.group(1)}: {exc}") from exc
        found[match.group(1)] = (value, statement)
    missing = [name for name in names if name not in found]
    if missing:
        raise QuestieFormatError(f"{path}: no {', '.join(missing)}")
    return found


def part_positions(statement: str) -> dict[str, dict[str, int]]:
    """Positions inside composite fields, from the commented lines under a key (e.g. startedBy's creatureStart)."""
    parts: dict[str, dict[str, int]] = {}
    current = None
    for line in statement.splitlines():
        key = _KEY_LINE.match(line)
        if key:
            current = key.group(1)
            continue
        sub = _PART_LINE.match(line)
        if sub and current:
            parts.setdefault(current, {})[sub.group(1)] = int(sub.group(2))
    return parts


def id_map(value: object) -> dict[int, object]:
    """A table keyed by IDs. The Lua parser turns a table whose keys are exactly 1..n into a list; this undoes that."""
    if isinstance(value, dict):
        return {key: item for key, item in value.items() if isinstance(key, int) and item is not None}
    if isinstance(value, list):
        return {index: item for index, item in enumerate(value, 1) if item is not None}
    return {}


def as_list(value: object) -> list:
    if value is None:
        return []
    if isinstance(value, list):
        return [item for item in value if item is not None]
    if isinstance(value, dict):
        return [value[key] for key in sorted(k for k in value if isinstance(k, int))]
    return [value]


def scalar_id(value: object) -> int | None:
    """A positive integer (IDs, levels, masks), else None."""
    if isinstance(value, bool):
        return None
    if isinstance(value, float) and value.is_integer():
        value = int(value)
    return value if isinstance(value, int) and value > 0 else None


def ids(value: object) -> list[int]:
    return sorted({ident for ident in map(scalar_id, as_list(value)) if ident is not None})


def part(value: object, position: int | None) -> object:
    """Element `position` (1-based, as in Lua) of a positional table."""
    if position is None:
        return None
    if isinstance(value, list):
        return value[position - 1] if 0 < position <= len(value) else None
    if isinstance(value, dict):
        return value.get(position)
    return None


def first_id(entry: object) -> int | None:
    """The ID at the head of an objective entry ({id, text, icon}, or a bare ID)."""
    return scalar_id(part(entry, 1)) if isinstance(entry, (list, dict)) else scalar_id(entry)


def race_side(mask: object) -> str | None:
    """The side a race mask allows: "Horde", "Alliance", "both" (0, or races of both), None (no Classic or Skyborne race bit)."""
    if not isinstance(mask, int) or mask == 0:
        return "both"
    alliance, horde = mask & ALLIANCE_RACES, mask & HORDE_RACES
    if alliance and horde:
        return "both"
    return "Alliance" if alliance else "Horde" if horde else None


def npc_side(friendly: object) -> str:
    """Our side token for QuestieDB's friendlyToFaction letters ("A", "H", "AH"; nil means friendly to neither)."""
    letters = frozenset(friendly) & {"A", "H"} if isinstance(friendly, str) else frozenset()
    return {frozenset("AH"): "both", frozenset("A"): "Alliance", frozenset("H"): "Horde"}.get(letters, "none")


def checkout_commit(root: Path) -> str | None:
    """The checked-out commit, read from the checkout's .git files (no git command runs in a third-party checkout)."""
    git = root / ".git"
    try:
        if git.is_file():
            pointer = git.read_text(encoding="utf-8").strip()
            git = (root / pointer.removeprefix("gitdir:").strip()).resolve()
        sha = (git / "HEAD").read_text(encoding="utf-8").strip()
        if sha.startswith("ref:"):
            ref = sha.removeprefix("ref:").strip()
            if (git / ref).is_file():
                sha = (git / ref).read_text(encoding="utf-8").strip()
            else:
                packed = (git / "packed-refs").read_text(encoding="utf-8") if (git / "packed-refs").is_file() else ""
                sha = next((line.split()[0] for line in packed.splitlines() if line.endswith(" " + ref)), "")
    except OSError:
        return None
    return sha[:10] if _SHA.fullmatch(sha) else None


def client_build(root: Path) -> str | None:
    """The client build QuestieDB's Forever data was made for, when its provenance file names one."""
    try:
        provenance = json.loads((root / PROVENANCE_FILE).read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None
    report = provenance.get("dbc_report") if isinstance(provenance, dict) else None
    build = report.get("build") if isinstance(report, dict) else None
    return build if isinstance(build, str) and re.fullmatch(r"[0-9.]{1,32}", build) else None


@dataclass
class Questie:
    """QuestieDB's Forever tables as read from its files."""

    keys: dict[str, dict[str, int]]  # kind -> field -> 1-based position
    parts: dict[str, dict[str, int]]  # composite quest field -> part -> 1-based position
    data: dict[str, dict[int, object]]  # kind -> ID -> record
    area_maps: dict[int, int]  # AreaID -> uiMapID, override applied (0: suppressed)
    commit: str | None = None
    build: str | None = None
    layers: forever_layers.LayerReport = field(default_factory=forever_layers.LayerReport)  # Forever correction layers applied

    def get(self, kind: str, record: object, name: str) -> object:
        return part(record, self.keys[kind][name])


def load(root: Path) -> Questie:
    """Read the QuestieDB checkout at `root`."""
    keys: dict[str, dict[str, int]] = {}
    data: dict[str, dict[int, object]] = {}
    parts: dict[str, dict[str, int]] = {}
    for kind in KINDS:
        path = root / DATA_FILE.format(kind.capitalize())
        key_name, data_name = f"QuestieDB.{kind}Keys", f"QuestieDB.{kind}Data"
        found = read_assignments(path, (key_name, data_name))
        table, statement = found[key_name]
        if not isinstance(table, dict) or not all(isinstance(v, int) and v > 0 for v in table.values()):
            raise QuestieFormatError(f"{path}: {key_name} is not a table of field positions")
        missing = [name for name in FIELDS[kind] if name not in table]
        if missing:
            raise QuestieFormatError(f"{path}: {key_name} has no {', '.join(missing)}")
        keys[kind] = table
        data[kind] = id_map(found[data_name][0])
        if kind == "quest":
            parts = part_positions(statement)
            for composite, names in PARTS.items():
                absent = [name for name in names if name not in parts.get(composite, {})]
                if absent:
                    raise QuestieFormatError(f"{path}: {key_name} documents no {composite} part {', '.join(absent)}")
    zones = read_assignments(root / ZONE_FILE, (ZONE_OVERRIDE, ZONE_BASE))
    merged = {**id_map(zones[ZONE_BASE][0]), **id_map(zones[ZONE_OVERRIDE][0])}
    area_maps = {area: map_id for area, map_id in merged.items() if isinstance(map_id, int)}
    return Questie(keys, parts, data, area_maps, checkout_commit(root), client_build(root))


# Converting -----------------------------------------------------------------------------------------------------------


@dataclass
class References:
    """What the kept quests reference, collected before the NPC, object and item tables are built."""

    npcs: set[int] = field(default_factory=set)
    objects: set[int] = field(default_factory=set)
    items: set[int] = field(default_factory=set)
    starts: dict[int, set[int]] = field(default_factory=dict)  # item -> quests it starts
    uses: dict[int, set[int]] = field(default_factory=dict)  # item -> quests that need it (objective or source item)


class Importer:
    """Turns QuestieDB's tables into the layer's quests, npcs, objects and items (Data/Schema.lua)."""

    def __init__(
        self,
        questie: Questie,
        faction: str = "horde",
        max_drops: int = MAX_DROPS,
        radius: float = CLUSTER_RADIUS,
        clusters: int = MAX_CLUSTERS,
    ) -> None:
        self.q = questie
        self.faction = faction
        self.sides = FACTION_SIDES[faction]
        self.letters = FACTION_LETTERS[faction]
        self.max_drops = max_drops
        self.radius = radius
        self.clusters = clusters
        self.problems: dict[str, set[int]] = {}
        self.stats: dict[str, int] = {}
        self._positions: dict[tuple[str, int], list[list]] = {}

    def problem(self, label: str, ident: int) -> None:
        self.problems.setdefault(label, set()).add(ident)

    def count(self, name: str) -> None:
        self.stats[name] = self.stats.get(name, 0) + 1

    def problem_lines(self) -> list[str]:
        return [
            f"{label} ({len(found)}): {', '.join(str(ident) for ident in sorted(found))}"
            for label, found in sorted(self.problems.items())
        ]

    def run(self) -> dict[str, dict]:
        quests = self.quests()
        refs = self.references(quests)
        items = self.items(refs, quests)
        npcs = self.npcs(refs)
        objects = self.objects(refs)
        for qid, quest in quests.items():
            for entities, missing, unplaced in (
                (quest.get("s"), P_NO_START, P_START_UNPLACED),
                (quest.get("e"), P_NO_END, P_END_UNPLACED),
            ):
                if not entities:
                    self.problem(missing, qid)
                elif not entities_located(entities, npcs, objects, items):
                    self.problem(unplaced, qid)
        return {"quests": quests, "npcs": npcs, "objects": objects, "items": items}

    # positions --------------------------------------------------------------------------------------------------------

    def positions(self, spawns: object, kind: str, ident: int) -> tuple[list[list], list[tuple[str, int]]]:
        """{[AreaID] = {{x, y}, ...}} -> [[uiMapID, x, y], ...] (the map with most spawns first, clustered per map),
        and the problems found on the way."""
        by_map: dict[int, list[tuple[float, float]]] = {}
        issues: list[tuple[str, int]] = []
        for area, points in id_map(spawns).items():
            map_id = self.q.area_maps.get(area)
            for point in as_list(points):
                if not (
                    isinstance(point, list)
                    and len(point) >= 2
                    and all(isinstance(v, (int, float)) and not isinstance(v, bool) for v in point[:2])
                ):
                    issues.append((f"{kind}s with malformed coordinates", ident))
                    continue
                x, y = float(point[0]), float(point[1])
                if (x, y) == (-1.0, -1.0):
                    continue  # inside an instance
                if not map_id:
                    issues.append((P_AREAS, area))
                    continue
                if not (0 <= x <= 100 and 0 <= y <= 100):
                    issues.append((f"{kind}s with coordinates outside 0-100", ident))
                    continue
                by_map.setdefault(map_id, []).append((x, y))
        ordered = sorted(by_map, key=lambda map_id: (-len(by_map[map_id]), map_id))
        found = [[map_id, x, y] for map_id in ordered for x, y in cluster(by_map[map_id], self.radius, self.clusters)]
        return found, issues

    def entity_positions(self, kind: str, ident: int) -> list[list]:
        """An NPC's or object's positions (cached)."""
        key = (kind, ident)
        if key not in self._positions:
            record = self.q.data[kind].get(ident)
            spawns = self.q.get(kind, record, "spawns") if record is not None else None
            self._positions[key] = self.positions(spawns, kind, ident)
        return self._positions[key][0]

    def kept_positions(self, kind: str, ident: int) -> list[list]:
        """The positions of an entity the layer keeps, recording their problems."""
        found = self.entity_positions(kind, ident)
        for label, value in self._positions[(kind, ident)][1]:
            self.problem(label, value)
        return found

    def entity_maps(self, kind: str, ident: int) -> set[int]:
        return {point[0] for point in self.entity_positions(kind, ident)}

    def friendly(self, npc: object) -> bool:
        letters = self.q.get("npc", npc, "friendlyToFaction")
        return isinstance(letters, str) and any(letter in letters for letter in self.letters)

    # quests -----------------------------------------------------------------------------------------------------------

    def quest_side(self, record: object) -> str | None:
        """The race mask's side; a race-neutral quest that only NPCs friendly to one faction start is that faction's."""
        side = race_side(self.q.get("quest", record, "requiredRaces"))
        if side != "both":
            return side
        starters = self.q.get("quest", record, "startedBy")
        positions = self.q.parts["startedBy"]
        npc_data = self.q.data["npc"]
        npcs = [npc_data[n] for n in ids(part(starters, positions["creatureStart"])) if n in npc_data]
        others = ids(part(starters, positions["objectStart"])) + ids(part(starters, positions["itemStart"]))
        if not npcs or others:
            return side
        sides = {npc_side(self.q.get("npc", npc, "friendlyToFaction")) for npc in npcs}
        return sides.pop() if len(sides) == 1 and sides <= {"Horde", "Alliance"} else side

    def quests(self) -> dict[int, dict]:
        quests = {}
        for qid, record in sorted(self.q.data["quest"].items()):
            side = self.quest_side(record)
            if side is None:
                self.problem(P_RACES, qid)
            if side in self.sides or (side is None and self.faction == "both"):
                quests[qid] = self.quest(qid, record, side)
            else:
                self.count(f"quests left out ({side or 'no Classic or Skyborne race'})")
        return quests

    def entities(self, value: object, composite: str, kinds: tuple[str, ...]) -> dict[str, list[int]]:
        found = {}
        for kind, name in zip(kinds, PARTS[composite]):
            values = ids(part(value, self.q.parts[composite][name]))
            if values:
                found[kind] = values
        return found

    def quest(self, qid: int, record: object, side: str | None) -> dict:
        def get(name: str) -> object:
            return self.q.get("quest", record, name)

        quest: dict[str, object] = {}
        if isinstance(get("name"), str):
            quest["n"] = get("name")
        else:
            self.problem("quests without a name", qid)
        if side:
            quest["side"] = side
        for target, name in NUMBER_FIELDS:
            value = scalar_id(get(name))
            if value:
                quest[target] = value
        zone_or_sort = get("zoneOrSort")
        if isinstance(zone_or_sort, int) and zone_or_sort > 0:
            map_id = self.q.area_maps.get(zone_or_sort)
            if map_id:
                quest["zone"] = map_id
            else:
                self.problem(P_ZONE_UNMAPPED, qid)
                self.problem(P_AREAS, zone_or_sort)
        elif isinstance(zone_or_sort, int) and zone_or_sort < 0:
            quest["sort"] = -zone_or_sort  # the QuestSort ID (class, profession, seasonal, ...)
        else:
            self.problem(P_NO_ZONE, qid)
        starts = self.entities(get("startedBy"), "startedBy", ("npc", "obj", "item"))
        if starts:
            quest["s"] = starts
        ends = self.entities(get("finishedBy"), "finishedBy", ("npc", "obj"))
        if ends:
            quest["e"] = ends
        objectives = self.objectives(qid, get("objectives"), get("triggerEnd"))
        if objectives:
            quest["o"] = objectives
        for target, name in LIST_FIELDS:
            values = ids(get(name))
            if values:
                quest[target] = values
        for target, name in ID_FIELDS:
            value = scalar_id(get(name))
            if value:
                quest[target] = value
        skill = get("requiredSkill")
        skill_line, skill_value = scalar_id(part(skill, 1)), scalar_id(part(skill, 2))
        if skill_line:
            quest["skill"] = [skill_line, skill_value or 0]
        flags = get("specialFlags")
        if isinstance(flags, int) and flags & REPEATABLE:
            quest["repeatable"] = True
        gives = scalar_id(get("sourceItemId"))
        if gives:
            quest["gives"] = gives
        needs = ids(get("requiredSourceItems"))
        if needs:
            quest["needs"] = needs
        return quest

    def objectives(self, qid: int, value: object, trigger: object) -> list[dict]:
        """Objective references by kind and ID, in QuestieDB's kind order (not the quest log's); no text."""
        positions = self.q.parts["objectives"]
        found: list[dict] = []

        def add(entry: dict) -> None:
            if entry not in found:
                found.append(entry)

        for kind, name in (("kill", "creatureObjective"), ("object", "objectObjective"), ("item", "itemObjective")):
            for entry in as_list(part(value, positions[name])):
                ident = first_id(entry)
                if ident:
                    add({"k": kind, "id": ident})
        for entry in as_list(part(value, positions.get("killCreditObjective"))):
            creatures = ids(part(entry, 1))  # {{creature, ...}, baseCreatureID, text, icon}
            ident = scalar_id(part(entry, 2)) or (creatures[0] if creatures else None)
            if ident:
                add({"k": "kill", "id": ident, **({"credit": creatures} if creatures and creatures != [ident] else {})})
        for entry in as_list(part(value, positions.get("spellObjective"))):
            spell, item = scalar_id(part(entry, 1)), scalar_id(part(entry, 3))  # {spell, text, item}
            if spell:
                add({"k": "spell", "id": spell, **({"item": item} if item else {})})
        if trigger is not None:  # {text, {[AreaID] = {{x, y}, ...}}}
            points, issues = self.positions(part(trigger, 2), "quest", qid)
            for label, ident in issues:
                self.problem(label, ident)
            if points:
                add({"k": "explore", "p": points})
            else:
                self.problem(P_EXPLORE, qid)
        return found

    # references, items, NPCs, objects ---------------------------------------------------------------------------------

    def references(self, quests: dict[int, dict]) -> References:
        refs = References()
        for qid, quest in quests.items():
            starts, ends = quest.get("s", {}), quest.get("e", {})
            refs.npcs.update(starts.get("npc", ()), ends.get("npc", ()))
            refs.objects.update(starts.get("obj", ()), ends.get("obj", ()))
            for item in starts.get("item", ()):
                refs.starts.setdefault(item, set()).add(qid)
            used = list(quest.get("needs", ()))
            for objective in quest.get("o", ()):
                if objective["k"] == "kill":
                    refs.npcs.add(objective["id"])
                    refs.npcs.update(objective.get("credit", ()))
                elif objective["k"] == "object":
                    refs.objects.add(objective["id"])
                elif objective["k"] == "item":
                    used.append(objective["id"])
                elif objective["k"] == "spell" and objective.get("item"):
                    used.append(objective["item"])
            for item in used:
                refs.uses.setdefault(item, set()).add(qid)
            if quest.get("gives"):
                refs.items.add(quest["gives"])
        refs.items.update(refs.starts, refs.uses)
        return refs

    def quest_maps(self, quests: dict[int, dict], quest_ids: set[int]) -> set[int]:
        """The maps of these quests: their zones and where their starters are."""
        maps = set()
        for qid in quest_ids:
            quest = quests.get(qid) or {}
            starts = quest.get("s") or {}
            if quest.get("zone"):
                maps.add(quest["zone"])
            for npc in starts.get("npc", ()):
                maps |= self.entity_maps("npc", npc)
            for obj in starts.get("obj", ()):
                maps |= self.entity_maps("object", obj)
        return maps

    def drop_sources(self, npcs: list[int], objects: list[int], maps: set[int]) -> tuple[list[int], list[int], int]:
        """The creatures and objects an item drops from. Beyond --max-drops of them (a cloth, gem or world drop), only
        those on the maps of the quests that need it, if there are at most --max-drops of those; then also the total."""
        total = len(npcs) + len(objects)
        if total <= self.max_drops:
            return npcs, objects, 0
        self.count("items with more drop sources than --max-drops")
        local_npcs = [npc for npc in npcs if maps & self.entity_maps("npc", npc)]
        local_objects = [obj for obj in objects if maps & self.entity_maps("object", obj)]
        if len(local_npcs) + len(local_objects) > self.max_drops:
            return [], [], total
        return local_npcs, local_objects, total

    def items(self, refs: References, quests: dict[int, dict]) -> dict[int, dict]:
        npc_data = self.q.data["npc"]
        items = {}
        for ident in sorted(refs.items):
            record = self.q.data["item"].get(ident)
            if record is None:
                self.problem("items referenced but missing from QuestieDB", ident)
                continue
            item: dict[str, object] = {}
            name = self.q.get("item", record, "name")
            if isinstance(name, str):
                item["n"] = name
            started = scalar_id(self.q.get("item", record, "startQuest"))
            if started not in quests:
                started = min(refs.starts.get(ident, ()), default=None)
            if started:
                item["quest"] = started
            maps = self.quest_maps(quests, refs.uses.get(ident, set()) | refs.starts.get(ident, set()))
            drops, obj_drops, total = self.drop_sources(
                ids(self.q.get("item", record, "npcDrops")), ids(self.q.get("item", record, "objectDrops")), maps
            )
            if drops:
                item["drops"] = drops
            if obj_drops:
                item["objDrops"] = obj_drops
            if total:
                item["many"] = total
            vendors = ids(self.q.get("item", record, "vendors"))
            vendors = [npc for npc in vendors if npc in npc_data and self.friendly(npc_data[npc])]
            if vendors:
                item["vendors"] = vendors
            refs.npcs.update(drops, vendors)
            refs.objects.update(obj_drops)
            items[ident] = item
        return items

    def npcs(self, refs: References) -> dict[int, dict]:
        data = self.q.data["npc"]

        def service_flags(record: object) -> int:
            return (scalar_id(self.q.get("npc", record, "npcFlags")) or 0) & SERVICE_FLAGS

        service = {ident for ident, record in data.items() if service_flags(record) and self.friendly(record)}
        npcs = {}
        for ident in sorted(refs.npcs | service):
            record = data.get(ident)
            if record is None:
                self.problem("npcs referenced but missing from QuestieDB", ident)
                continue
            if ident not in refs.npcs and not self.entity_positions("npc", ident):
                continue  # a service NPC with no position (inside an instance) that no quest needs
            positions = self.kept_positions("npc", ident)
            npc: dict[str, object] = {"side": npc_side(self.q.get("npc", record, "friendlyToFaction"))}
            name = self.q.get("npc", record, "name")
            if isinstance(name, str):
                npc["n"] = name
            if positions:
                npc["p"] = positions
            # 1 elite, 2 rare elite, 3 boss (QuestieDB: 4 is a rare without the elite flag and 0 a normal creature: not kept)
            rank = scalar_id(self.q.get("npc", record, "rank"))
            if rank in (1, 2, 3):
                npc["rank"] = rank
            if ident in service:
                npc["flags"] = service_flags(record)
                title = self.q.get("npc", record, "subName")
                if isinstance(title, str) and title:
                    npc["sub"] = title
                self.count("service NPCs")
            npcs[ident] = npc
        return npcs

    def objects(self, refs: References) -> dict[int, dict]:
        objects = {}
        for ident in sorted(refs.objects):
            record = self.q.data["object"].get(ident)
            if record is None:
                self.problem("objects referenced but missing from QuestieDB", ident)
                continue
            obj: dict[str, object] = {}
            name = self.q.get("object", record, "name")
            if isinstance(name, str):
                obj["n"] = name
            positions = self.kept_positions("object", ident)
            if positions:
                obj["p"] = positions
            objects[ident] = obj
        return objects


def entities_located(entities: dict, npcs: dict, objects: dict, items: dict) -> bool:
    """Whether any of a quest's starters (or enders) has a position; an item counts through its sources."""

    def placed(table: dict, idents: object) -> bool:
        return any((table.get(ident) or {}).get("p") for ident in idents or ())

    if placed(npcs, entities.get("npc")) or placed(objects, entities.get("obj")):
        return True
    for ident in entities.get("item") or ():
        item = items.get(ident) or {}
        sources = ((npcs, item.get("drops")), (npcs, item.get("vendors")), (objects, item.get("objDrops")))
        if any(placed(table, idents) for table, idents in sources):
            return True
    return False


# Checking the built pack ----------------------------------------------------------------------------------------------


def listed_quests(gaps: str) -> set[int]:
    """Quest IDs data-gaps.md lists as incomplete: the "quests ..." problem lines and the build's quest sections."""
    listed: set[int] = set()
    section = ""
    for line in gaps.splitlines():
        if line.startswith("## "):
            section = line
        elif line.startswith("- quests ") and ":" in line:
            listed.update(int(n) for n in re.findall(r"\d+", line.split(":", 1)[1]))
        elif section.startswith("## Quests without") and line.strip():
            listed.update(int(n) for n in re.findall(r"\d+", re.sub(r"\(and \d+ more\)", "", line)))
    return listed


def check(pack: Path, maps: set[int], races: int | None, classes: int | None, sides: tuple[str, ...]) -> dict:
    """Check the built pack: every quest of `maps` (by its zone, or by where it starts when it is filed under a
    QuestSort) that a character with these race and class bits can take needs a start entity, an end entity and a
    coordinate, or must be listed in data-gaps.md."""
    tables = {name: datapack.read_table(pack, name) or {} for name in ("quests", "npcs", "objects", "items")}
    quests, npcs, objects, items = (tables[name] for name in ("quests", "npcs", "objects", "items"))
    listed = listed_quests((pack / "data-gaps.md").read_text(encoding="utf-8"))
    result: dict = {
        "checked": [],
        "failing": [],
        "start": 0,
        "end": 0,
        "coordinate": 0,
        "start placed": 0,
        "end placed": 0,
    }
    for qid, quest in sorted(quests.items()):
        if quest.get("side") not in sides:
            continue
        if races and quest.get("races") and not quest["races"] & races:
            continue
        if classes and quest.get("classes") and not quest["classes"] & classes:
            continue
        starts, ends = quest.get("s") or {}, quest.get("e") or {}
        if quest.get("zone"):
            on_maps = quest["zone"] in maps
        else:
            starters = [npcs.get(i) or {} for i in starts.get("npc", ())]
            starters += [objects.get(i) or {} for i in starts.get("obj", ())]
            on_maps = any(point[0] in maps for entity in starters for point in entity.get("p") or ())
        if not on_maps:
            continue
        result["checked"].append(qid)
        start_placed = bool(starts) and entities_located(starts, npcs, objects, items)
        end_placed = bool(ends) and entities_located(ends, npcs, objects, items)
        result["start"] += bool(starts)
        result["end"] += bool(ends)
        result["start placed"] += start_placed
        result["end placed"] += end_placed
        result["coordinate"] += start_placed or end_placed
        if not (starts and ends and (start_placed or end_placed)):
            result["failing"].append(qid)
    result["unlisted"] = [qid for qid in result["failing"] if qid not in listed]
    result["listed"] = [qid for qid in result["checked"] if qid in listed]
    return result


# Command line ---------------------------------------------------------------------------------------------------------


def import_layer(
    questie_dir: Path, pack: Path, forever_layers_on: bool = True, **options: object
) -> tuple[Importer, dict[str, int]]:
    """Read QuestieDB, write layers/questie.json and rebuild the pack. Returns the importer and the record counts.

    With `forever_layers_on` the Forever correction layers (delta-base, traces, authored fixes) are applied to the
    records first (signpost_tools.forever_layers); without it only the converted Classic Era baseline is imported."""
    questie = load(questie_dir)
    base = {kind: len(questie.data[kind]) for kind in KINDS}
    if forever_layers_on:
        questie.layers = forever_layers.apply_layers(questie, questie_dir)
    else:
        questie.layers.note = "Forever layers switched off (--no-forever-layers)"
    importer = Importer(questie, **options)  # type: ignore[arg-type]
    for kind in KINDS:
        importer.stats[f"{kind} records in QuestieDB's base tables"] = base[kind]
        importer.stats[f"{kind} records after the Forever layers"] = len(questie.data[kind])
    for layer in questie.layers.layers:
        for kind in KINDS:
            importer.stats[f"forever layer {layer.name}: {kind} records added"] = layer.added[kind]
            importer.stats[f"forever layer {layer.name}: {kind} records changed"] = layer.changed[kind]
    tables = importer.run()
    # QuestieDB's "Forever" base tables are its Classic Era tables with the map coordinates converted to Forever's geometry
    # (data/Forever/conversion.json: "a converted Era baseline, not complete Forever content"): say so wherever it shows.
    origin = f"QuestieDB {questie.commit or 'unknown commit'}: a Classic Era baseline, coordinates converted to Forever's maps"
    if questie.build:
        origin += f" (geometry of build {questie.build})"
    origin += f", {importer.faction}; "
    if questie.layers.applied:
        origin += (
            f"plus {questie.layers.summary()}: Forever's own quests, zones, restrictions; not complete objectives or "
            "gameplay behavior"
        )
    else:
        origin += f"no Forever content (new quests, zones, race and class restrictions); {questie.layers.summary()}"
    problems = importer.problem_lines()
    problems += [
        f"Forever layers skipped {reason}: {count}" for reason, count in sorted(questie.layers.skipped.items())
    ]
    problems += [
        f"Forever layers rejected {reason}: {count}" for reason, count in sorted(questie.layers.rejected.items())
    ]
    datapack.write_layer(pack, "questie", tables, origin, problems)
    for table, records in tables.items():
        importer.stats[f"{table} in the questie layer"] = len(records)
    return importer, datapack.build(pack, TOOL)


def mask(text: str) -> int:
    value = int(text, 0)
    if value <= 0:
        raise argparse.ArgumentTypeError("a mask is a positive number")
    return value


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--out", type=Path, default=DEFAULT_PACK, help="data pack folder (default ../Signpost_Data)")
    parser.add_argument("--questie", type=Path, help="QuestieDB checkout (default <out>/cache/questiedb)")
    parser.add_argument("--faction", choices=sorted(FACTION_SIDES), default="horde", help="default horde (+ neutral)")
    parser.add_argument(
        "--max-drops",
        type=int,
        default=MAX_DROPS,
        help=f"drop sources (creatures and objects) kept per item; beyond that only those on the maps of the quests "
        f"that need it (default {MAX_DROPS})",
    )
    parser.add_argument("--radius", type=float, default=CLUSTER_RADIUS, help="spawn cluster radius, percent of the map")
    parser.add_argument("--clusters", type=int, default=MAX_CLUSTERS, help="positions kept per map (default 3)")
    parser.add_argument(
        "--no-forever-layers",
        action="store_true",
        help="import only QuestieDB's converted Classic Era baseline tables; by default its Forever correction layers "
        "(generated delta-base, traces, authored fixes) are applied on top",
    )
    parser.add_argument(
        "--check-maps",
        help="after the build, check the quests of these uiMapIDs (comma-separated): each needs a start and an end "
        "entity and a coordinate, or an entry in data-gaps.md; exit status 1 when one has neither",
    )
    parser.add_argument("--check-races", type=mask, help="only quests a character with these race bits can take")
    parser.add_argument("--check-classes", type=mask, help="only quests a character with these class bits can take")
    options = parser.parse_args()
    if not (options.out / "Signpost_Data.toc").exists():
        parser.error(f"{options.out} is not the data pack (no Signpost_Data.toc); run tools/datapack.py init first")

    try:
        importer, counts = import_layer(
            options.questie or options.out / "cache" / "questiedb",
            options.out,
            forever_layers_on=not options.no_forever_layers,
            faction=options.faction,
            max_drops=options.max_drops,
            radius=options.radius,
            clusters=options.clusters,
        )
    except (QuestieFormatError, CorrectionsFormatError) as exc:
        print(f"questie_import: {exc}", file=sys.stderr)
        return 1
    for name, value in sorted(importer.stats.items()):
        print(f"{name}: {value}")
    layers = importer.q.layers
    print(f"layers: {layers.summary()}")
    for reason, count in layers.skipped.most_common(10):
        print(f"  skipped {count}: {reason}")
    for reason, count in layers.rejected.most_common(10):
        print(f"  rejected {count}: {reason}")
    print(f"problems: {sum(map(len, importer.problems.values()))} IDs of {len(importer.problems)} kinds (data-gaps.md)")
    print(f"data pack rebuilt: {counts}")
    for name in ("_meta.lua", *datapack.TABLE_FILES.values()):
        if (options.out / name).exists():
            print(f"  {name}: {(options.out / name).stat().st_size} bytes")
    if not options.check_maps:
        return 0

    maps = {int(text) for text in options.check_maps.split(",") if text.strip()}
    result = check(options.out, maps, options.check_races, options.check_classes, FACTION_SIDES[options.faction])
    print(
        f"check: {len(result['checked'])} quests on maps {sorted(maps)} "
        f"(race bits {options.check_races}, class bits {options.check_classes})"
    )
    print(
        f"  with a start entity {result['start']}, an end entity {result['end']}, a coordinate {result['coordinate']}"
        f"; start placed {result['start placed']}, end placed {result['end placed']}"
    )
    print(f"  failing {len(result['failing'])}: {result['failing']}")
    print(f"  listed in data-gaps.md as incomplete: {len(result['listed'])}: {result['listed']}")
    if result["unlisted"]:
        print(f"  failing and NOT in data-gaps.md: {result['unlisted']}")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
