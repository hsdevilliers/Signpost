"""Export WoW: Forever data from Wowhead into the data pack's `wowhead` layer (PLAN §6). Run it on your own machine;
Claude Code never runs it against Wowhead and never reads its cache (CLAUDE.md "Data sources").

    python tools/wowhead_env.py                                    first: structure check; paste its report
    python tools/wowhead_export.py --zones "Durotar,The Barrens"   those zones' quests and their NPCs/objects
    python tools/wowhead_export.py --max-level 32                  every zone up to that level, and the cities
    python tools/wowhead_export.py --stages class --class HUNTER   class trainer spells, trainers, quest chains
    python tools/wowhead_export.py --stages professions            every profession's recipes and trainers
    python tools/wowhead_export.py --stages travel                 flight masters, innkeepers, transport masters
    python tools/wowhead_export.py --offline ...                   re-parse the cache only (no network)

Stages (--stages, default zones,quests; --class adds class):
  zones        Wowhead zone IDs and level ranges, joined by name to the client's maps (tools/map_overrides.json,
               {"uiMapID": wowheadZoneID}, settles names that do not join)
  quests       each selected zone's quest list (faction and level filtered), then the quest pages still needed:
               start and end NPCs, objects and items, the series' previous quest (preSingle) and next quest
  class        trainer spells by level, class trainers, class quest chains; `new` marks chains with a quest missing from
               Wowhead's Classic database (--no-classic-check skips that lookup)
  professions  every profession the client knows (docs/probes): recipes (item, skill colors, reagents, source), trainers
  travel       each selected zone's NPC list: flight masters (named after the client's nearest flight node), innkeepers,
               zeppelin and boat masters; --transport zeppelin:<npcID>,<npcID> pairs two masters into a route
After the stages, NPC and object pages give the positions of what they referenced (--no-entities skips them).

Gap-only by default: a quest page is read only when no other layer (questie, learned) and no earlier run has the quest
with a start and an end, an NPC or object page only when nothing has a position for it; --all reads them anyway. Zone
quest lists are always read, so quests the other sources lack (Forever's new ones) are found.

Output: layers/wowhead.json in --out (records of earlier runs are kept; --fresh starts over), then the pack is rebuilt
from every layer (datapack.build: the tables, classes/<CLASS>.lua, _meta.lua, the TOC, data-gaps.md).
Only IDs, names, numbers and coordinates are kept; there are no item records (items appear only as IDs inside quest and
recipe records). One request every 2 s, cached for --max-age days under <out>/cache/wowhead, robots.txt honoured.
Problems are reported by ID and kind only, so the output can be shared.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import math
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from signpost_tools import datapack, devconfig, wowhead  # noqa: E402
from signpost_tools.geo import cluster  # noqa: E402

DEFAULT_OUT = devconfig.REPO_ROOT.parent / "Signpost_Data"
PROBES = devconfig.REPO_ROOT / "docs" / "probes"
MAP_OVERRIDES = devconfig.TOOLS_DIR / "map_overrides.json"
TOOL = "wowhead_export.py"
STAGES = ("zones", "quests", "class", "professions", "travel")
DEFAULT_STAGES = "zones,quests"

# Wowhead quest "side" values and the factions that can take them; the NPC sides each exported faction can use.
SIDES = {1: "Alliance", 2: "Horde", 3: "both"}
FACTION_SIDES = {"horde": {2, 3}, "alliance": {1, 3}, "both": {1, 2, 3}}
USABLE = {"horde": {"Horde", "both"}, "alliance": {"Alliance", "both"}, "both": {"Alliance", "Horde", "both"}}
NPC_SIDES = ("Alliance", "Horde", "both")
# Wowhead list pages: quests=<category>.<zone> (category from the client continent's uiMapID, else from the zone list),
# class quests quests=4.-<QuestSort>, class spells spells=7.<classID>, recipes spells=11.<skillLine> (secondary: 9).
CONTINENT_CATEGORY = {1414: 1, 1415: 0}
CLASS_QUEST_CATEGORY = 4
CLASS_SPELL_CATEGORY = 7
RECIPE_CATEGORY = {True: 11, False: 9}
# QuestSort IDs of the class quest categories. HUNTER's list is a wowhead_env.py sample; confirm the others with it
# before their guides start.
CLASS_QUEST_SORTS = {
    "DRUID": 263,
    "HUNTER": 261,
    "MAGE": 161,
    "PALADIN": 141,
    "PRIEST": 262,
    "ROGUE": 162,
    "SHAMAN": 82,
    "WARLOCK": 61,
    "WARRIOR": 81,
}
ZONE_TYPE = 3  # Enum.UIMapType.Zone
ZONE_TYPES = (ZONE_TYPE, 6)  # and Orphan (Forever's Darkspear Islands, the battlegrounds)
NODE_SIDES = {0: "both", 1: "Horde", 2: "Alliance"}  # Enum.FlightPathFaction of the client's flight nodes
NODE_MATCH_YARDS = 100.0
MAX_CLUSTERS = 3
CLUSTER_RADIUS = 3.0  # percent of the map
QUEST_PARTS = (("start", "s"), ("end", "e"))
LINK_KINDS = {"npc": "npc", "object": "obj", "item": "item"}  # Quick Facts link type -> quest s/e group
ENTITY_TABLES = (("npc", "npcs"), ("object", "objects"))
# plus travel and classes; never items (CLAUDE.md scope)
LAYER_TABLES = ("maps", "quests", "npcs", "objects", "professions")


def normalize(name: str) -> str:
    return re.sub(r"[^a-z0-9]", "", name.lower())


def client_facts(probes: Path = PROBES) -> dict:
    """The professions ({skillLineID: {n, primary}}) and classes ({classFile: {id, n}}) the client reported in the
    newest `/signpost probe` dump (docs/probes/<build>.json)."""
    facts: dict = {"professions": {}, "classes": {}}
    files = sorted(Path(probes).glob("*.json"), key=lambda path: [int(p) for p in re.findall(r"\d+", path.stem)])
    if not files:
        return facts
    probe = json.loads(files[-1].read_text(encoding="utf-8"))
    for entry in ((probe.get("professions") or {}).get("byEnum") or {}).values():
        if not isinstance(entry, dict):
            continue
        info, skill = entry.get("info"), entry.get("skillLine")
        if isinstance(info, dict) and isinstance(skill, int) and skill > 0:
            primary = bool(info.get("isPrimaryProfession"))
            facts["professions"][skill] = {"n": info.get("professionName"), "primary": primary}
    for entry in ((probe.get("player") or {}).get("classes") or {}).values():
        if not isinstance(entry, dict):
            continue
        if isinstance(entry.get("classFile"), str) and isinstance(entry.get("classID"), int):
            facts["classes"][entry["classFile"]] = {"id": entry["classID"], "n": entry.get("className")}
    return facts


def load_overrides(path: Path | None) -> dict[int, int]:
    """{uiMapID: wowheadZoneID} from the overrides file, if it exists."""
    if not path or not Path(path).exists():
        return {}
    try:
        raw = json.loads(Path(path).read_text(encoding="utf-8"))
        return {int(map_id): int(zone) for map_id, zone in raw.items()}
    except (ValueError, AttributeError) as error:
        raise SystemExit(f"{path}: expected {{\"uiMapID\": wowheadZoneID, ...}} ({error})") from error


def combined_side(sides: list[str | None]) -> str | None:
    """The side of a route between two endpoints: their common side, or "both"."""
    known = {side for side in sides if side in NPC_SIDES}
    factions = known - {"both"}
    if len(factions) == 1:
        return factions.pop()
    return "both" if known else None


class Export:
    def __init__(self, options: argparse.Namespace, client=None, facts: dict | None = None, log=None) -> None:
        self.options = options
        self.log = log or (lambda message: print(message, file=sys.stderr))
        self.client = client or wowhead.Wowhead(
            options.cache, max_age_days=options.max_age, force=options.force, offline=options.offline, log=self.log
        )
        self.facts = facts if facts is not None else client_facts()
        self.problems: list[str] = []
        self.maps: dict = datapack.read_table(options.out, "maps") or {}
        self.zone_to_map: dict[int, int] = {
            m["wowhead"]: map_id for map_id, m in self.maps.items() if isinstance(m, dict) and m.get("wowhead")
        }
        self.layers = {
            name: (datapack.read_layer(options.out, name) or {}).get("tables") or {} for name in ("questie", "learned")
        }
        previous = {} if options.fresh else datapack.read_layer(options.out, "wowhead") or {}
        earlier = previous.get("tables") or {}
        self.tables: dict = {table: dict(earlier.get(table) or {}) for table in LAYER_TABLES}
        travel = earlier.get("travel") or {}
        self.tables["travel"] = {part: dict(travel.get(part) or {}) for part in datapack.TRAVEL_KEYED} | {
            part: list(travel.get(part) or []) for part in datapack.TRAVEL_LISTS
        }
        # classes[classFile]: datapack.build writes them as classes/<CLASS>.lua. (A layer written before the classes
        # table existed kept them beside its tables.)
        self.classes: dict = dict(earlier.get("classes") or previous.get("classes") or {})
        self.known = self.known_sets(earlier)
        self.wanted: dict[str, set[int]] = {"npc": set(), "object": set()}
        self.names: dict[str, dict[int, str]] = {"npc": {}, "object": {}}
        self.sides: dict[int, str] = {}
        self.endpoints: dict[str, dict[int, dict]] = {"flight": {}, "inn": {}, "transport": {}}
        self.done_quests: set[int] = set()
        self.zone_rows: dict[int, dict] | None = None

    # bookkeeping ---------------------------------------------------------------------------------------------------

    def problem(self, kind: str, ident: object) -> None:
        self.problems.append(f"{kind}: {ident}")

    @staticmethod
    def status(page: wowhead.Page) -> str:
        return "not in the cache" if page.status == 0 else f"HTTP {page.status}"

    def known_sets(self, earlier: dict) -> dict[str, set[int]]:
        """Quests that some layer has with a start and an end, NPCs and objects that some layer has placed."""
        known: dict[str, set[int]] = {"quest": set(), "npc": set(), "object": set()}
        if self.options.all:
            return known
        for tables in (self.layers["questie"], self.layers["learned"], earlier):
            for quest_id, quest in (tables.get("quests") or {}).items():
                if isinstance(quest, dict) and quest.get("s") and quest.get("e"):
                    known["quest"].add(quest_id)
            for kind, table in ENTITY_TABLES:
                for ident, record in (tables.get(table) or {}).items():
                    if isinstance(record, dict) and record.get("p"):
                        known[kind].add(ident)
        return known

    def view(self, table: str, ident: int) -> dict:
        """One record as the pack will merge it: questie, then this layer, then learned (datapack.LAYERS order)."""
        merged: dict = {}
        for tables in (self.layers["questie"], self.tables, self.layers["learned"]):
            record = (tables.get(table) or {}).get(ident)
            if isinstance(record, dict):
                merged.update(record)
        return merged

    def put(self, table: str, ident: int, record: dict, replace: bool = False) -> None:
        record = {key: value for key, value in record.items() if value is not None}
        if not record and not replace:
            return
        if replace or ident not in self.tables[table]:
            self.tables[table][ident] = record
        else:
            self.tables[table][ident].update(record)

    def want(self, kind: str, ident: object, name: object = None, side: str | None = None) -> None:
        if not isinstance(ident, int) or isinstance(ident, bool):
            return
        self.wanted[kind].add(ident)
        if isinstance(name, str) and name:
            self.names[kind][ident] = name
        if kind == "npc" and side in NPC_SIDES:
            self.sides[ident] = side

    def want_quest_entities(self, quest: dict) -> None:
        for _, part in QUEST_PARTS:
            for group, kind in (("npc", "npc"), ("obj", "object")):
                for ident in (quest.get(part) or {}).get(group) or []:
                    self.want(kind, ident)

    # zones ---------------------------------------------------------------------------------------------------------

    def zone_list(self) -> dict[int, dict]:
        """Wowhead's zone list by zone ID (read once per run; usually from the cache)."""
        if self.zone_rows is None:
            page = self.client.get("zones")
            zone_rows = wowhead.rows(page.text, "zone")
            self.zone_rows = {row["id"]: row for row in zone_rows if isinstance(row.get("id"), int)}
            if not self.zone_rows:
                self.problem(f"zone list without a zone listview ({self.status(page)})", "zones")
        return self.zone_rows

    def zones_stage(self) -> None:
        rows = self.zone_list()
        if not rows:
            return
        by_name: dict[str, list[dict]] = {}
        for row in rows.values():
            by_name.setdefault(normalize(str(row.get("name", ""))), []).append(row)
        overrides = load_overrides(self.options.map_overrides)
        joined = 0
        for map_id, entry in sorted(self.maps.items()):
            if not isinstance(entry, dict) or entry.get("t") not in ZONE_TYPES:
                continue
            if map_id in overrides:
                row = rows.get(overrides[map_id])
                if row is None:
                    self.problem("map override names a zone missing from Wowhead's zone list", map_id)
                    continue
            else:
                candidates = by_name.get(normalize(str(entry.get("n", "")))) or []
                if len(candidates) > 1:
                    category = CONTINENT_CATEGORY.get(entry.get("parent"))
                    candidates = [row for row in candidates if row.get("category") == category] or candidates
                if len(candidates) != 1:
                    if candidates:
                        self.problem("zone name matches several Wowhead zones (add a map override)", map_id)
                    elif entry.get("t") == ZONE_TYPE:
                        self.problem("client zone not on Wowhead's zone list (add a map override)", map_id)
                    continue
                row = candidates[0]
            record = {"wowhead": row["id"]}
            for source, target in (("minlevel", "lmin"), ("maxlevel", "lmax")):
                value = row.get(source)
                if isinstance(value, int) and not isinstance(value, bool) and value > 0:
                    record[target] = value
            self.put("maps", map_id, record)
            entry.update(record)
            self.zone_to_map[row["id"]] = map_id
            joined += 1
        self.log(f"zones: {len(rows)} on Wowhead, {joined} joined to the client's maps")

    def selected_zones(self) -> list[int]:
        """uiMapIDs of the zones to export: --zones names, else every zone Wowhead knows whose level range starts at
        or below --max-level (zones without a range, such as the cities, included)."""
        zones = {map_id: m for map_id, m in self.maps.items() if isinstance(m, dict) and m.get("t") in ZONE_TYPES}
        if self.options.zones:
            wanted = {normalize(name) for name in self.options.zones.split(",") if name.strip()}
            chosen = [map_id for map_id, m in zones.items() if normalize(str(m.get("n", ""))) in wanted]
            for name in sorted(wanted - {normalize(str(zones[map_id].get("n", ""))) for map_id in chosen}):
                self.problem("zone name not in Maps.lua", name)
            return sorted(chosen)
        return sorted(
            map_id
            for map_id, m in zones.items()
            if m.get("wowhead") is not None and (m.get("lmin") is None or m["lmin"] <= self.options.max_level)
        )

    def quest_category(self, map_id: int) -> int | None:
        entry = self.maps[map_id]
        category = CONTINENT_CATEGORY.get(entry.get("parent"))
        if category is None:
            row = self.zone_list().get(entry.get("wowhead")) or {}
            category = row.get("category") if isinstance(row.get("category"), int) else None
        return category

    # quests --------------------------------------------------------------------------------------------------------

    def quests_stage(self) -> None:
        sides = FACTION_SIDES[self.options.faction]
        for map_id in self.selected_zones():
            zone = self.maps[map_id]
            category = self.quest_category(map_id)
            if zone.get("wowhead") is None or category is None:
                self.problem("zone without a Wowhead ID or quest category (zones stage)", map_id)
                continue
            page = self.client.get(f"quests={category}.{zone['wowhead']}")
            rows = wowhead.rows(page.text, "quest")
            if page.status != 200 or not rows:
                self.problem(f"quest list empty or missing ({self.status(page)})", f"zone {map_id}")
                continue
            kept = [
                row
                for row in rows
                if row.get("side", 3) in sides and (wowhead.to_int(row.get("level")) or 0) <= self.options.max_level
            ]
            read = sum(1 for row in kept if self.quest(row.get("id"), row, map_id))
            self.log(
                f"quests: zone {map_id}: {len(rows)} listed, {len(kept)} for {self.options.faction}, "
                f"{read} quest pages read, {len(kept) - read} covered already"
            )

    def quest(self, quest_id: object, row: dict | None = None, map_id: int | None = None) -> bool:
        """Record one quest from its list row and, when no layer has its start and end yet, from its page. Returns
        whether the page was read."""
        if not isinstance(quest_id, int) or isinstance(quest_id, bool):
            return False
        record: dict = {"zone": map_id}
        if row:
            record.update({"n": row.get("name"), "l": row.get("level"), "r": row.get("reqlevel")})
            record["side"] = SIDES.get(row.get("side", 3), "both")
            for source, target in (("reqclass", "classes"), ("reqrace", "races")):
                if row.get(source):
                    record[target] = row[source]
        first = quest_id not in self.done_quests
        self.done_quests.add(quest_id)
        read = first and quest_id not in self.known["quest"]
        if read:
            self.read_quest_page(quest_id, record, from_list=bool(row))
        self.put("quests", quest_id, record)
        if first:  # its NPCs and objects, from this page or from the other layers
            self.want_quest_entities(self.view("quests", quest_id))
        return read

    def read_quest_page(self, quest_id: int, record: dict, from_list: bool) -> None:
        page = self.client.get(f"quest={quest_id}")
        if page.status != 200:
            self.problem(f"quest page {self.status(page)}", quest_id)
            return
        markup = wowhead.infobox_markup(page.text)
        facts = wowhead.infobox_facts(markup) if markup else {}
        if not markup:
            self.problem("quest page without Quick Facts", quest_id)
        for key, target in QUEST_PARTS:
            groups: dict[str, set[int]] = {}
            for link in facts.get(key) or []:
                if link["type"] in LINK_KINDS:
                    groups.setdefault(LINK_KINDS[link["type"]], set()).add(link["id"])
            if groups:
                record[target] = {group: sorted(ids) for group, ids in groups.items()}
            elif markup:
                self.problem(f"quest without {key} entity", quest_id)
        if not from_list:  # found through another layer: level and side from Quick Facts
            for key, target in (("level", "l"), ("reqlevel", "r")):
                if key in facts:
                    record[target] = facts[key]
            side = {"horde": "Horde", "alliance": "Alliance", "both": "both"}.get(str(facts.get("side", "")).lower())
            if side:
                record["side"] = side
        # The series' previous quest is a prerequisite: the questie layer's field for "one of these first" (preSingle).
        previous, record["next"] = wowhead.neighbours(wowhead.series(page.text))
        record["preSingle"] = [previous] if previous else None
        for kind, entries in wowhead.gatherer(page.text).items():
            label = {wowhead.TYPE_NPC: "npc", wowhead.TYPE_OBJECT: "object"}.get(kind)
            for ident, fields in entries.items():
                if label and isinstance(fields, dict) and fields.get("name_enus") and str(ident).isdigit():
                    self.names[label][int(ident)] = fields["name_enus"]

    # class ---------------------------------------------------------------------------------------------------------

    def class_mask(self) -> int:
        return sum(1 << (info["id"] - 1) for info in self.facts["classes"].values() if info.get("id", 0) > 0)

    def class_stage(self) -> None:
        class_file = self.options.class_name
        info = self.facts["classes"].get(class_file)
        if not info:
            self.problem("class not in the client's class list (docs/probes)", class_file)
            return
        class_id = info["id"]
        page = self.client.get(f"class={class_id}")
        pages = [page]
        if page.status != 200:
            self.problem(f"class page {self.status(page)}", class_file)
        spell_rows = wowhead.rows(page.text, "spell")
        if not spell_rows:
            pages.append(self.client.get(f"spells={CLASS_SPELL_CATEGORY}.{class_id}"))
            spell_rows = wowhead.rows(pages[-1].text, "spell")
        spells, basis = wowhead.trainer_spells(spell_rows)
        if not spell_rows:
            self.problem("class without a spell listview", class_file)
        elif basis == "none":
            self.problem("class spell rows without source or trainingcost (kept every spell with a level)", class_file)
        trainers = self.trainers(page.text, f"class {class_file}")
        chains = self.class_quests(class_file, 1 << (class_id - 1), page.text, pages)
        if class_file in self.classes and not any(read.status == 200 for read in pages):
            self.problem("class pages could not be read; the earlier export is kept", class_file)
            return
        self.classes[class_file] = {"spells": spells, "trainers": sorted(trainers), "quests": chains}
        self.log(
            f"class {class_file}: {sum(len(ids) for ids in spells.values())} trainer spells, {len(trainers)} trainers, "
            f"{len(chains)} quest chains ({sum(len(chain['quests']) for chain in chains)} quests)"
        )

    def class_quests(self, class_file: str, bit: int, class_page: str, pages: list[wowhead.Page]) -> list[dict]:
        """The class's quest chains: its class quest category, the class page's quest list, and every quest only this
        class can take (class mask) that this run or another layer knows."""
        sides = FACTION_SIDES[self.options.faction]
        rows = {row["id"]: row for row in wowhead.rows(class_page, "quest") if isinstance(row.get("id"), int)}
        sort = CLASS_QUEST_SORTS.get(class_file)
        if sort is None:
            self.problem("no class quest category known", class_file)
        else:
            listing = self.client.get(f"quests={CLASS_QUEST_CATEGORY}.-{sort}")
            pages.append(listing)
            listed = wowhead.rows(listing.text, "quest")
            if not listed:
                self.problem(f"class quest list empty or missing ({self.status(listing)})", class_file)
            rows.update({row["id"]: row for row in listed if isinstance(row.get("id"), int)})
        chosen = {quest_id for quest_id, row in rows.items() if row.get("side", 3) in sides}
        everyone = self.class_mask()
        for tables in (self.layers["questie"], self.tables, self.layers["learned"]):
            for quest_id, quest in (tables.get("quests") or {}).items():
                mask = quest.get("classes") if isinstance(quest, dict) else None
                if isinstance(mask, int) and mask & everyone == bit and quest_id not in rows:
                    side = self.view("quests", quest_id).get("side")
                    if side is None or side in USABLE[self.options.faction]:
                        chosen.add(quest_id)
        for quest_id in sorted(chosen):
            self.quest(quest_id, rows.get(quest_id))
        new = {}
        if not self.options.no_classic_check:
            new = {quest_id: self.new_in_forever(quest_id) for quest_id in sorted(chosen)}
        return self.chains(chosen, new)

    def new_in_forever(self, quest_id: int) -> bool | None:
        page = self.client.get(f"quest={quest_id}", flavor=wowhead.CLASSIC_FLAVOR)
        exists = wowhead.entity_exists(page)
        if exists is None:
            self.problem(f"Classic database check inconclusive ({self.status(page)})", quest_id)
            return None
        return not exists

    def chains(self, quest_ids: set[int], new: dict[int, bool | None]) -> list[dict]:
        """Group quests into chains along their prerequisite (preSingle, preGroup) and next links (within the set),
        each in chain order."""
        neighbours: dict[int, set[int]] = {quest_id: set() for quest_id in quest_ids}
        following: dict[int, int] = {}
        for quest_id in quest_ids:
            record = self.view("quests", quest_id)
            befores = [*(record.get("preSingle") or []), *(record.get("preGroup") or [])]
            after = record.get("next")
            for before in befores:
                if before in quest_ids and before != quest_id:
                    neighbours[quest_id].add(before)
                    neighbours[before].add(quest_id)
                    following.setdefault(before, quest_id)
            if after in quest_ids and after != quest_id:
                neighbours[quest_id].add(after)
                neighbours[after].add(quest_id)
                following[quest_id] = after
        chains, seen = [], set()
        for start in sorted(quest_ids):
            if start in seen:
                continue
            group, stack = set(), [start]
            while stack:
                quest_id = stack.pop()
                if quest_id not in group:
                    group.add(quest_id)
                    stack.extend(neighbours[quest_id])
            seen |= group
            chains.append(self.chain(group, following, new))
        chains.sort(key=lambda chain: (chain.get("l") or 0, chain["id"]))
        return chains

    def chain(self, group: set[int], following: dict[int, int], new: dict[int, bool | None]) -> dict:
        def level(quest_id: int) -> int:
            record = self.view("quests", quest_id)
            return wowhead.to_int(record.get("r")) or wowhead.to_int(record.get("l")) or 0

        followers = {following[q] for q in group if q in following}
        heads = sorted(group - followers, key=lambda q: (level(q), q))
        order: list[int] = []
        for head in heads:
            quest_id: int | None = head
            while quest_id in group and quest_id not in order:
                order.append(quest_id)
                quest_id = following.get(quest_id)
        order += sorted(group - set(order), key=lambda q: (level(q), q))  # a cycle, or links that do not line up
        head = self.view("quests", order[0])
        record = {"id": order[0], "n": head.get("n"), "l": level(order[0]) or None, "quests": order}
        flags = [new.get(quest_id) for quest_id in order]
        if any(flag is True for flag in flags):
            record["new"] = True
        elif flags and all(flag is False for flag in flags):
            record["new"] = False
        return {key: value for key, value in record.items() if value is not None}

    # professions ---------------------------------------------------------------------------------------------------

    def selected_professions(self) -> list[int]:
        professions = self.facts["professions"]
        if not professions:
            self.problem("no professions known (docs/probes holds no client probe)", "professions")
        if not self.options.professions:
            return sorted(professions)
        chosen: set[int] = set()
        for token in (part.strip() for part in self.options.professions.split(",")):
            matches = [
                skill
                for skill, info in professions.items()
                if str(skill) == token or normalize(str(info.get("n", ""))) == normalize(token)
            ]
            if matches:
                chosen.update(matches)
            elif token:
                self.problem("profession not in the client's profession list", token)
        return sorted(chosen)

    def professions_stage(self) -> None:
        for skill in self.selected_professions():
            info = self.facts["professions"][skill]
            page = self.client.get(f"skill={skill}")
            pages = [page]
            if page.status != 200:
                self.problem(f"profession page {self.status(page)}", skill)
            spell_rows = [row for row in wowhead.rows(page.text, "spell") if self.for_skill(row, skill)]
            if not spell_rows:
                pages.append(self.client.get(f"spells={RECIPE_CATEGORY[info['primary']]}.{skill}"))
                spell_rows = [row for row in wowhead.rows(pages[-1].text, "spell") if self.for_skill(row, skill)]
            if not spell_rows:
                self.problem("profession without a spell listview", skill)
            recipes = {}
            for row in spell_rows:
                parsed = wowhead.recipe(row)
                if parsed is None or not isinstance(row.get("id"), int):
                    continue
                recipe, missing = parsed
                for field in missing:
                    self.problem(f"recipe without {field}", row["id"])
                recipes[row["id"]] = recipe
            trainers = self.trainers(page.text, f"profession {skill}")
            unread = not any(read.status == 200 for read in pages)
            if skill in self.tables["professions"] and (unread or not (recipes or trainers)):
                self.problem("profession pages gave nothing; the earlier export is kept", skill)
                continue
            record = {"n": info.get("n"), "trainers": sorted(trainers), "recipes": recipes}
            self.put("professions", skill, record, replace=True)
            self.log(f"professions: {skill}: {len(recipes)} recipes, {len(trainers)} trainers")

    @staticmethod
    def for_skill(row: dict, skill: int) -> bool:
        skills = row.get("skill")
        return not isinstance(skills, list) or skill in skills

    def trainers(self, text: str, what: str) -> set[int]:
        """NPC IDs from the page's trainer listviews (an npc listview whose id names trainers) usable by --faction."""
        views = [view for view in wowhead.listviews(text) if view["template"] == "npc" and "train" in str(view["id"])]
        if not views:
            self.problem("page without a trainer listview", what)
            return set()
        found = set()
        usable = USABLE[self.options.faction]
        for row in (row for view in views for row in view["data"] if isinstance(row, dict)):
            side = wowhead.react_side(row.get("react"))
            if not isinstance(row.get("id"), int) or (side is not None and side not in usable):
                continue
            found.add(row["id"])
            self.want("npc", row["id"], row.get("name"), side)
        return found

    # travel --------------------------------------------------------------------------------------------------------

    def travel_stage(self) -> None:
        """Flight masters, innkeepers and transport masters of every faction (PLAN §6: every node carries its side)."""
        for map_id in self.selected_zones():
            zone_id = self.maps[map_id].get("wowhead")
            if zone_id is None:
                self.problem("zone without a Wowhead ID (zones stage)", map_id)
                continue
            page = self.client.get(f"zone={zone_id}")
            npc_rows = wowhead.rows(page.text, "npc")
            if not npc_rows:
                self.problem(f"zone page without an NPC listview ({self.status(page)})", map_id)
                continue
            found = 0
            for row in npc_rows:
                role = wowhead.npc_role(row.get("tag"))
                if role not in self.endpoints or not isinstance(row.get("id"), int):
                    continue
                side = wowhead.react_side(row.get("react"))
                entry: dict = {"side": side if side in NPC_SIDES else None, "zone": map_id}
                if role == "transport":
                    entry["kind"] = wowhead.transport_kind(row.get("tag"))
                self.endpoints[role][row["id"]] = entry
                self.want("npc", row["id"], row.get("name"), entry["side"])
                found += 1
            self.log(f"travel: zone {map_id}: {len(npc_rows)} NPCs listed, {found} flight, inn or transport NPCs")

    def position(self, npc: int) -> list | None:
        for point in self.view("npcs", npc).get("p") or []:
            if isinstance(point, list) and len(point) >= 3 and all(isinstance(v, (int, float)) for v in point[:3]):
                return list(point[:3])
        return None

    def world(self, map_id: object, x: object, y: object) -> tuple | None:
        """(instance, worldX, worldY) in yards for a point in percent of a map, from the client map's world corners."""
        entry = self.maps.get(map_id)
        corners = entry.get("world") if isinstance(entry, dict) else None
        if not (isinstance(corners, list) and len(corners) == 5):
            return None
        instance, x0, y0, x1, y1 = corners
        if not all(isinstance(v, (int, float)) and not isinstance(v, bool) for v in (x, y, x0, y0, x1, y1)):
            return None
        # A map's x runs along world Y and its y along world X (top-left corner first).
        return instance, x0 + (y / 100) * (x1 - x0), y0 + (x / 100) * (y1 - y0)

    def flight_node(self, position: list, side: str | None) -> str | None:
        """The client flight node (Maps.lua continent `taxi`) nearest a flight master, if within NODE_MATCH_YARDS."""
        # VERIFY(beta): the dump's node names are the names the taxi map shows (what `.fly <node>` matches).
        here = self.world(*position)
        if here is None:
            return None
        best, best_distance = None, NODE_MATCH_YARDS
        for continent_id, continent in sorted(self.maps.items()):
            for node in (continent.get("taxi") if isinstance(continent, dict) else None) or []:
                name = node.get("n") if isinstance(node, dict) else None
                if not isinstance(name, str) or name.startswith("zz"):  # "zz" marks retired client records
                    continue
                node_side = NODE_SIDES.get(node.get("faction"))
                if side in ("Alliance", "Horde") and node_side not in (side, "both"):
                    continue
                there = self.world(continent_id, node.get("x"), node.get("y"))
                if there is None or there[0] != here[0]:
                    continue
                distance = math.hypot(there[1] - here[1], there[2] - here[2])
                if distance < best_distance:
                    best, best_distance = name, distance
        return best

    def finish_travel(self) -> None:
        travel = self.tables["travel"]
        for role, part, label in (("flight", "flightMasters", "flight master"), ("inn", "inns", "innkeeper")):
            for npc, entry in sorted(self.endpoints[role].items()):
                position = self.position(npc)
                if position is None:
                    self.problem(f"{label} without a position", npc)
                    continue
                record = {"p": position, "side": entry["side"]}
                if role == "flight":
                    record["node"] = self.flight_node(position, entry["side"])
                    if record["node"] is None:
                        self.problem(f"flight master without a client flight node within {NODE_MATCH_YARDS:.0f} yd", npc)
                travel[part][npc] = {key: value for key, value in record.items() if value is not None}
        paired = set()
        for kind, first, second in self.options.transports:
            ends = [self.position(first), self.position(second)]
            if None in ends:
                self.problem("transport endpoint without a position", first if ends[0] is None else second)
                continue
            side = combined_side([self.view("npcs", npc).get("side") for npc in (first, second)])
            record = {"kind": kind, "from": ends[0], "to": ends[1], "side": side, "npcs": [first, second]}
            pair = sorted([first, second])
            travel["transports"] = [t for t in travel["transports"] if sorted(t.get("npcs") or []) != pair]
            travel["transports"].append({key: value for key, value in record.items() if value is not None})
            paired |= {first, second}
        paired |= {npc for transport in travel["transports"] for npc in transport.get("npcs") or []}
        for npc in sorted(set(self.endpoints["transport"]) - paired):
            self.problem(f"{self.endpoints['transport'][npc]['kind']} master without a --transport pair", npc)

    # entities ------------------------------------------------------------------------------------------------------

    def entities_stage(self) -> None:
        for kind, table in ENTITY_TABLES:
            wanted = sorted(self.wanted[kind])
            missing = [ident for ident in wanted if ident not in self.known[kind]]
            for ident in missing:
                entry = self.entity(kind, ident)
                if entry:
                    self.put(table, ident, entry)
            placed = len(wanted) - len(missing)
            self.log(f"entities: {len(wanted)} {kind}s referenced, {len(missing)} pages read, {placed} placed already")

    def entity(self, kind: str, ident: int) -> dict | None:
        page = self.client.get(f"{kind}={ident}")
        if page.status != 200:
            self.problem(f"{kind} page {self.status(page)}", ident)
            return None
        name = self.names[kind].get(ident) or wowhead.heading(page.text)
        entry: dict = {"n": name} if name else {}
        by_map: dict[int, list[tuple[float, float]]] = {}
        for point in wowhead.coordinates(wowhead.mapper(page.text)):
            map_id = point["uiMapId"] or self.zone_to_map.get(point["zone"])
            if map_id is None:
                self.problem(f"{kind} spawn in unknown Wowhead zone {point['zone']}", ident)
                continue
            by_map.setdefault(map_id, []).append((point["x"], point["y"]))
        positions = [
            [map_id, x, y] for map_id, pts in sorted(by_map.items()) for x, y in cluster(pts, CLUSTER_RADIUS, MAX_CLUSTERS)
        ]
        if positions:
            entry["p"] = positions
        else:
            self.problem(f"{kind} without coordinates", ident)
        return entry or None

    # output --------------------------------------------------------------------------------------------------------

    def finish(self) -> None:
        """Names and sides of every referenced entity (from the pages read this run), then the travel records."""
        for kind, table in ENTITY_TABLES:
            for ident in sorted(self.wanted[kind]):
                side = self.sides.get(ident) if kind == "npc" else None
                self.put(table, ident, {"n": self.names[kind].get(ident), "side": side})
        self.finish_travel()

    def origin(self) -> str:
        return f"Wowhead {self.client.flavor}, {dt.date.today().isoformat()}"

    def write(self) -> dict[str, int]:
        out = self.options.out
        tables = {**self.tables, datapack.CLASSES: self.classes}
        datapack.write_layer(out, "wowhead", tables, self.origin(), self.problems)
        return datapack.build(out, TOOL)


def parse_transport(spec: str) -> tuple[str, int, int]:
    """`zeppelin:111,222` -> ("zeppelin", 111, 222)."""
    match = re.fullmatch(r"\s*(boat|zeppelin)\s*:\s*(\d+)\s*,\s*(\d+)\s*", spec)
    if not match:
        raise argparse.ArgumentTypeError(f"{spec!r}: expected boat:<npcID>,<npcID> or zeppelin:<npcID>,<npcID>")
    return match.group(1), int(match.group(2)), int(match.group(3))


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT, help="data pack folder (default ../Signpost_Data)")
    parser.add_argument("--cache", type=Path, help="page cache (default <out>/cache/wowhead)")
    parser.add_argument("--stages", default=DEFAULT_STAGES, help=f"comma-separated, from {','.join(STAGES)}")
    parser.add_argument("--zones", help="comma-separated zone names as in Maps.lua, e.g. 'Durotar,The Barrens'")
    parser.add_argument("--max-level", type=int, default=32, help="zones starting at or below this level; quests up to it")
    parser.add_argument("--faction", choices=sorted(FACTION_SIDES), default="horde")
    parser.add_argument("--class", dest="class_name", type=str.upper, help="class stage: class file token, e.g. HUNTER")
    parser.add_argument("--professions", help="skill line IDs or names (default: every profession the client knows)")
    parser.add_argument(
        "--transport",
        dest="transports",
        action="append",
        type=parse_transport,
        default=[],
        metavar="KIND:NPC,NPC",
        help="travel: two zeppelin or boat masters that serve one route, e.g. zeppelin:111,222 (repeatable)",
    )
    parser.add_argument("--all", action="store_true", help="read every quest, NPC and object page, not just the gaps")
    parser.add_argument("--fresh", action="store_true", help="start the wowhead layer empty instead of adding to it")
    parser.add_argument("--no-entities", action="store_true", help="skip the NPC and object pages (positions)")
    parser.add_argument("--no-classic-check", action="store_true", help="class stage: skip the Classic-database lookups")
    parser.add_argument("--map-overrides", type=Path, default=MAP_OVERRIDES, help="JSON {uiMapID: wowheadZoneID}")
    parser.add_argument("--max-age", type=float, default=7, help="days before a cached page is fetched again")
    parser.add_argument("--force", action="store_true", help="ignore the cache")
    parser.add_argument("--offline", action="store_true", help="use only cached pages (no network)")
    options = parser.parse_args(argv)
    options.cache = options.cache or options.out / "cache" / "wowhead"
    stages = {stage.strip() for stage in options.stages.split(",") if stage.strip()}
    if stages - set(STAGES):
        parser.error(f"unknown stage(s) {', '.join(sorted(stages - set(STAGES)))}; choose from {', '.join(STAGES)}")
    if options.class_name:
        stages.add("class")
    if "class" in stages and not options.class_name:
        parser.error("the class stage needs --class, e.g. --class HUNTER")
    options.stage_set = stages
    return options


def run(options: argparse.Namespace, client=None, facts: dict | None = None, log=None) -> tuple[Export, dict[str, int]]:
    if not datapack.read_table(options.out, "maps"):
        raise SystemExit(
            f"{options.out / 'Maps.lua'} is missing or empty: run /signpost dumpmaps in game, then "
            "tools/import_savedvars.py --maps"
        )
    export = Export(options, client, facts, log)
    stages = options.stage_set
    try:
        if stages & {"zones", "quests", "travel"}:
            export.zones_stage()
        if "quests" in stages:
            export.quests_stage()
        if "class" in stages:
            export.class_stage()
        if "professions" in stages:
            export.professions_stage()
        if "travel" in stages:
            export.travel_stage()
        if not options.no_entities:
            export.entities_stage()
    except wowhead.WowheadError as error:
        export.problem("stopped", error)
        export.log(f"stopped: {error}")
    export.finish()
    return export, export.write()


def main() -> None:
    options = parse_args()
    export, counts = run(options)
    print(
        f"done: {export.client.requests} requests, {export.client.cache_hits} cached pages, "
        f"{len(set(export.problems))} problem(s) listed in {options.out / 'data-gaps.md'}; pack rebuilt: {counts}"
    )


if __name__ == "__main__":
    main()
