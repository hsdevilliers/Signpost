"""Turn Signpost's SavedVariables into files: JSON for inspection, and Maps.lua for the private data pack.

    python tools/import_savedvars.py --json --out savedvars.json   SignpostDB and every SignpostCharDB as JSON
    python tools/import_savedvars.py --maps                         Maps.lua from SignpostDB.mapDump (/signpost dumpmaps)

--from DIR reads a copied SavedVariables folder (the play machine's); --pack DIR is the data pack (default
../Signpost_Data). Wowhead zone IDs already in Maps.lua are kept when the map list is regenerated.
--merge-learned (learned NPC positions and zone crossings into the pack) arrives with Core/Learn.lua.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from signpost_tools import datapack, devconfig  # noqa: E402
from signpost_tools.savedvars import LuaParseError  # noqa: E402
from signpost_tools.svfiles import find_files, load_db  # noqa: E402

DEFAULT_PACK = devconfig.REPO_ROOT.parent / "Signpost_Data"


def _points(entries: object) -> list[dict] | None:
    """Flight nodes or dungeon entrances from a map dump entry, reduced to id, name, position and faction."""
    if not isinstance(entries, list) or not entries:
        return None
    points = []
    for entry in entries:
        if isinstance(entry, dict) and isinstance(entry.get("x"), (int, float)) and isinstance(entry.get("y"), (int, float)):
            point = {"id": entry.get("id"), "n": entry.get("name"), "x": entry["x"], "y": entry["y"]}
            if entry.get("faction") is not None:
                point["faction"] = entry["faction"]
            points.append({k: v for k, v in point.items() if v is not None})
    return points or None


def maps_table(dump: dict, previous: dict | None = None) -> dict[int, dict]:
    """Maps.lua from a /signpost dumpmaps result. `previous` (the current Maps.lua) supplies Wowhead zone IDs."""
    previous = previous if isinstance(previous, dict) else {}
    maps: dict[int, dict] = {}
    for entry in dump.get("maps") or []:
        if not isinstance(entry, dict) or not isinstance(entry.get("id"), int) or "error" in entry:
            continue
        map_id = entry["id"]
        record: dict[str, object] = {"n": entry.get("name"), "t": entry.get("type"), "parent": entry.get("parent")}
        world = entry.get("world")
        if isinstance(world, dict) and all(isinstance(world.get(k), (int, float)) for k in ("x0", "y0", "x1", "y1")):
            record["world"] = [world.get("instance"), world["x0"], world["y0"], world["x1"], world["y1"]]
        rect = entry.get("onParent")
        if isinstance(rect, dict) and all(isinstance(rect.get(k), (int, float)) for k in ("minX", "maxX", "minY", "maxY")):
            record["rect"] = [rect["minX"], rect["maxX"], rect["minY"], rect["maxY"]]
        for key in ("group", "flags"):
            if isinstance(entry.get(key), (int, float)):
                record[key] = entry[key]
        record["taxi"] = _points(entry.get("taxi"))
        record["dungeons"] = _points(entry.get("dungeons"))
        old = previous.get(map_id)
        if isinstance(old, dict) and old.get("wowhead") is not None:
            record["wowhead"] = old["wowhead"]
        maps[map_id] = {k: v for k, v in record.items() if v is not None}
    return maps


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--from", dest="source", type=Path, help="read a copied SavedVariables folder")
    parser.add_argument("--config", type=Path, help="dev config (default tools/dev.local.json)")
    parser.add_argument("--json", action="store_true", help="write SignpostDB and the character DBs as JSON")
    parser.add_argument("--out", type=Path, help="with --json: the output file (default: print)")
    parser.add_argument("--maps", action="store_true", help="write Maps.lua into the data pack from mapDump")
    parser.add_argument("--pack", type=Path, default=DEFAULT_PACK, help="data pack folder (default ../Signpost_Data)")
    options = parser.parse_args()
    if not (options.json or options.maps):
        parser.error("choose --json and/or --maps")

    try:
        files = find_files(options.source, options.config)
        databases = {sv.owner: load_db(sv) for sv in files if sv.path.exists()}
    except (devconfig.ConfigError, LuaParseError) as exc:
        sys.exit(str(exc))
    if "account" not in databases:
        sys.exit(f"{files[0].path} does not exist yet: log in, run the commands, then /reload")

    if options.json:
        sys.path.insert(0, str(Path(__file__).resolve().parent))
        from read_savedvars import to_json  # noqa: E402  (same JSON conventions as read_savedvars.py)

        text = to_json(databases)
        if options.out:
            options.out.write_text(text + "\n", encoding="utf-8")
            print(f"wrote {options.out}")
        else:
            print(text)

    if options.maps:
        dump = databases["account"].get("mapDump")
        if not isinstance(dump, dict) or not dump.get("maps"):
            sys.exit("SignpostDB has no mapDump: type /signpost dumpmaps in game, wait for 'saved', then /reload")
        maps = maps_table(dump, datapack.read_table(options.pack, "Maps.lua"))
        origin = f"client dumpmaps, build {dump.get('build')}"
        datapack.update_table(options.pack, "Maps.lua", maps, "import_savedvars.py", origin)
        print(f"wrote {options.pack / 'Maps.lua'}: {len(maps)} maps ({origin})")


if __name__ == "__main__":
    main()
