"""Export WoW: Forever data from Wowhead into the private data pack (PLAN §6). Run it on your own machine.

    python tools/wowhead_env.py                                    first: structure check, paste its report to Claude Code
    python tools/wowhead_export.py --zones "Durotar,The Barrens"   quests of those zones, their NPCs/objects, Maps.lua IDs
    python tools/wowhead_export.py --max-level 32                  every zone up to that level
    python tools/wowhead_export.py --offline ...                   re-parse the cache only (no network)

Stages (--stages, default zones,quests,entities): zones joins Wowhead zone IDs to Maps.lua by name; quests reads each
zone's quest list (faction/level filtered) and every quest page (start/end, level, chain); entities reads every NPC and
object those quests reference (name, level, clustered coordinates). One request every 2 s, cached for --max-age days
under ../Signpost_Data/cache/wowhead, robots.txt honoured. Claude Code never runs this against Wowhead (CLAUDE.md).
Output: Quests.lua, Npcs.lua, Objects.lua and Maps.lua in --out, plus data-gaps.md. Only IDs, names, numbers and
coordinates are kept. Problems are reported by ID and kind only, so the output can be shared.
"""

from __future__ import annotations

import argparse
import datetime as dt
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from signpost_tools import datapack, devconfig, wowhead  # noqa: E402

DEFAULT_OUT = devconfig.REPO_ROOT.parent / "Signpost_Data"
TOOL = "wowhead_export.py"

# Wowhead quest "side" values and the factions that can take them.
SIDES = {1: "Alliance", 2: "Horde", 3: "both"}
FACTION_SIDES = {"horde": {2, 3}, "alliance": {1, 3}, "both": {1, 2, 3}}
# Wowhead quest categories for the two continents (quests=<category>.<zone>); uiMapIDs of the continents.
CONTINENT_CATEGORY = {1414: 1, 1415: 0}
MAX_CLUSTERS = 3
CLUSTER_RADIUS = 3.0  # percent of the map


def normalize(name: str) -> str:
    return re.sub(r"[^a-z0-9]", "", name.lower())


def cluster(points: list[tuple[float, float]], radius: float = CLUSTER_RADIUS, limit: int = MAX_CLUSTERS) -> list[list[float]]:
    """Greedy clustering of spawn points (percent coordinates): up to `limit` centres, biggest clusters first."""
    clusters: list[list[float]] = []  # [sum_x, sum_y, count]
    for x, y in points:
        for entry in clusters:
            cx, cy = entry[0] / entry[2], entry[1] / entry[2]
            if (cx - x) ** 2 + (cy - y) ** 2 <= radius**2:
                entry[0] += x
                entry[1] += y
                entry[2] += 1
                break
        else:
            clusters.append([x, y, 1])
    clusters.sort(key=lambda entry: -entry[2])
    return [[round(e[0] / e[2], 2), round(e[1] / e[2], 2)] for e in clusters[:limit]]


class Export:
    def __init__(self, options: argparse.Namespace) -> None:
        self.options = options
        self.client = wowhead.Wowhead(
            options.cache, max_age_days=options.max_age, force=options.force, offline=options.offline, log=self.log
        )
        self.problems: list[str] = []
        self.maps: dict = datapack.read_table(options.out, "Maps.lua") or {}
        self.zone_to_map: dict[int, int] = {
            m["wowhead"]: map_id for map_id, m in self.maps.items() if isinstance(m, dict) and m.get("wowhead")
        }
        self.quests: dict[int, dict] = {}
        self.wanted = {"npc": set(), "object": set()}
        self.names: dict[str, dict[int, str]] = {"npc": {}, "object": {}, "item": {}}

    def log(self, message: str) -> None:
        print(message, file=sys.stderr)

    def problem(self, kind: str, ident: object) -> None:
        self.problems.append(f"{kind}: {ident}")

    # zones ---------------------------------------------------------------------------------------------------------

    def zones(self) -> None:
        page = self.client.get("zones")
        rows = [row for view in wowhead.listviews(page.text) if view["template"] == "zone" for row in view["data"]]
        if not rows:
            self.problem("zones page without a zone listview (HTTP %s)" % page.status, "zones")
            return
        by_name = {normalize(str(m.get("n", ""))): map_id for map_id, m in self.maps.items() if isinstance(m, dict)}
        joined = 0
        for row in rows:
            map_id = by_name.get(normalize(str(row.get("name", ""))))
            if map_id is None or not isinstance(row.get("id"), int):
                continue
            self.maps[map_id]["wowhead"] = row["id"]
            for source, target in (("minlevel", "lmin"), ("maxlevel", "lmax")):
                if isinstance(row.get(source), int) and row[source] > 0:
                    self.maps[map_id][target] = row[source]
            self.zone_to_map[row["id"]] = map_id
            joined += 1
        datapack.update_table(self.options.out, "Maps.lua", self.maps, TOOL, "client dumpmaps + Wowhead zone IDs")
        self.log(f"zones: {len(rows)} on Wowhead, {joined} joined to Maps.lua by name")

    def selected_zones(self) -> list[int]:
        """uiMapIDs of the zones to export, from --zones names or --max-level."""
        maps = {map_id: m for map_id, m in self.maps.items() if isinstance(m, dict) and m.get("t") == 3}
        if self.options.zones:
            wanted = {normalize(name) for name in self.options.zones.split(",")}
            chosen = [map_id for map_id, m in maps.items() if normalize(str(m.get("n", ""))) in wanted]
            missing = wanted - {normalize(str(maps[map_id].get("n", ""))) for map_id in chosen}
            for name in sorted(missing):
                self.problem("zone name not in Maps.lua", name)
            return sorted(chosen)
        return sorted(map_id for map_id, m in maps.items() if m.get("lmin") and m["lmin"] <= self.options.max_level)

    # quests --------------------------------------------------------------------------------------------------------

    def quests_stage(self) -> None:
        sides = FACTION_SIDES[self.options.faction]
        for map_id in self.selected_zones():
            zone = self.maps[map_id]
            category = CONTINENT_CATEGORY.get(zone.get("parent"))
            if zone.get("wowhead") is None or category is None:
                self.problem("zone without a Wowhead ID or continent category (run the zones stage)", map_id)
                continue
            page = self.client.get(f"quests={category}.{zone['wowhead']}")
            rows = [row for view in wowhead.listviews(page.text) if view["template"] == "quest" for row in view["data"]]
            if page.status != 200 or not rows:
                self.problem(f"quest list empty or missing (HTTP {page.status})", f"zone {map_id}")
                continue
            kept = [
                row
                for row in rows
                if row.get("side", 3) in sides and (row.get("level") or 0) <= self.options.max_level
            ]
            self.log(f"quests: zone {map_id}: {len(rows)} listed, {len(kept)} for {self.options.faction}")
            for row in kept:
                self.quest(row, map_id)

    def quest(self, row: dict, map_id: int) -> None:
        quest_id = row.get("id")
        if not isinstance(quest_id, int):
            return
        record: dict = {"n": row.get("name"), "l": row.get("level"), "r": row.get("reqlevel"), "zone": map_id}
        record["side"] = SIDES.get(row.get("side", 3), "both")
        for source, target in (("reqclass", "classes"), ("reqrace", "races")):
            if row.get(source):
                record[target] = row[source]
        page = self.client.get(f"quest={quest_id}")
        if page.status != 200:
            self.problem(f"quest page HTTP {page.status}", quest_id)
            self.quests[quest_id] = record
            return
        markup = wowhead.infobox_markup(page.text)
        facts = wowhead.infobox_facts(markup) if markup else {}
        if not markup:
            self.problem("quest page without Quick Facts", quest_id)
        for key, target in (("start", "s"), ("end", "e")):
            links = facts.get(key) or []
            if not links:
                self.problem(f"quest without {key} entity", quest_id)
            groups: dict[str, list[int]] = {}
            for link in links:
                kind = {"npc": "npc", "object": "obj", "item": "item"}.get(link["type"])
                if kind:
                    groups.setdefault(kind, []).append(link["id"])
                if link["type"] in self.wanted:
                    self.wanted[link["type"]].add(link["id"])
            if groups:
                record[target] = groups
        previous, following = wowhead.neighbours(wowhead.series(page.text))
        if previous:
            record["prev"] = previous
        if following:
            record["next"] = following
        for kind, entries in wowhead.gatherer(page.text).items():
            label = {wowhead.TYPE_NPC: "npc", wowhead.TYPE_OBJECT: "object", wowhead.TYPE_ITEM: "item"}.get(kind)
            for ident, fields in entries.items():
                if label and isinstance(fields, dict) and fields.get("name_enus") and str(ident).isdigit():
                    self.names[label][int(ident)] = fields["name_enus"]
        self.quests[quest_id] = {k: v for k, v in record.items() if v is not None}

    # entities ------------------------------------------------------------------------------------------------------

    def entities_stage(self) -> None:
        for kind, file_name in (("npc", "Npcs.lua"), ("object", "Objects.lua")):
            table = datapack.read_table(self.options.out, file_name) or {}
            for ident in sorted(self.wanted[kind]):
                entry = self.entity(kind, ident)
                if entry:
                    table[ident] = {**table.get(ident, {}), **entry}
            datapack.update_table(self.options.out, file_name, table, TOOL, self.origin())
            self.log(f"entities: {len(self.wanted[kind])} {kind}s")

    def entity(self, kind: str, ident: int) -> dict | None:
        page = self.client.get(f"{kind}={ident}")
        if page.status != 200:
            self.problem(f"{kind} page HTTP {page.status}", ident)
            return None
        entry: dict = {"src": "wowhead"}
        name = self.names[kind].get(ident) or heading(page.text)
        if name:
            entry["n"] = name
        by_map: dict[int, list[tuple[float, float]]] = {}
        for point in wowhead.coordinates(wowhead.mapper(page.text)):
            map_id = point["uiMapId"] or self.zone_to_map.get(point["zone"])
            if map_id is None:
                self.problem(f"{kind} spawn in unknown Wowhead zone {point['zone']}", ident)
                continue
            by_map.setdefault(map_id, []).append((point["x"], point["y"]))
        positions = [[map_id, x, y] for map_id, pts in sorted(by_map.items()) for x, y in cluster(pts)]
        if positions:
            entry["p"] = positions
        else:
            self.problem(f"{kind} without coordinates", ident)
        return entry

    # output --------------------------------------------------------------------------------------------------------

    def origin(self) -> str:
        return f"Wowhead {self.client.flavor}, {dt.date.today().isoformat()}"

    def write_quests(self) -> None:
        table = datapack.read_table(self.options.out, "Quests.lua") or {}
        table.update(self.quests)
        datapack.update_table(self.options.out, "Quests.lua", table, TOOL, self.origin())
        self.log(f"quests: {len(self.quests)} exported ({len(table)} in Quests.lua)")

    def write_gaps(self) -> None:
        lines = [
            "# Data gaps",
            "",
            f"Generated by `tools/{TOOL}` on {dt.date.today().isoformat()} ({self.client.requests} requests, "
            f"{self.client.cache_hits} from cache). IDs and problem kinds only.",
            "",
        ]
        lines += [f"- {problem}" for problem in sorted(set(self.problems))] or ["- none"]
        (self.options.out / "data-gaps.md").write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")


def heading(text: str) -> str | None:
    match = re.search(r"<h1[^>]*>([^<]{1,80})</h1>", text)
    return match.group(1).strip() if match else None


def main() -> None:
    sys.exit("wowhead_export.py is being moved to the data pack's layer model; not usable until that lands.")
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT, help="data pack folder (default ../Signpost_Data)")
    parser.add_argument("--cache", type=Path, help="page cache (default <out>/cache/wowhead)")
    parser.add_argument("--zones", help="comma-separated zone names as in Maps.lua, e.g. 'Durotar,The Barrens'")
    parser.add_argument("--max-level", type=int, default=32)
    parser.add_argument("--faction", choices=sorted(FACTION_SIDES), default="horde")
    parser.add_argument("--stages", default="zones,quests,entities")
    parser.add_argument("--max-age", type=float, default=7, help="days before a cached page is fetched again")
    parser.add_argument("--force", action="store_true", help="ignore the cache")
    parser.add_argument("--offline", action="store_true", help="use only cached pages (no network)")
    options = parser.parse_args()
    options.cache = options.cache or options.out / "cache" / "wowhead"
    if not (options.out / "Maps.lua").exists():
        sys.exit(f"{options.out / 'Maps.lua'} is missing: run /signpost dumpmaps in game and tools/import_savedvars.py --maps")

    export = Export(options)
    stages = set(options.stages.split(","))
    try:
        if "zones" in stages:
            export.zones()
        if "quests" in stages:
            export.quests_stage()
            export.write_quests()
        if "entities" in stages:
            export.entities_stage()
    except wowhead.WowheadError as error:
        export.problem("stopped", error)
        export.log(f"stopped: {error}")
    export.write_gaps()
    print(
        f"done: {export.client.requests} requests, {export.client.cache_hits} cached pages, "
        f"{len(set(export.problems))} problem(s) listed in {options.out / 'data-gaps.md'}"
    )


if __name__ == "__main__":
    main()
