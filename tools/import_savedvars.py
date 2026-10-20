"""Turn Signpost's SavedVariables into files: JSON for inspection, and the data pack's client and learned layers.

    python tools/import_savedvars.py --json --out savedvars.json   SignpostDB and every SignpostCharDB as JSON
    python tools/import_savedvars.py --maps                         client layer (maps) from SignpostDB.mapDump, then rebuild
    python tools/import_savedvars.py --merge-learned                learned layer from SignpostDB.learned and eventLog, then
                                                                    rebuild
    python tools/import_savedvars.py --merge-learned --also incoming/play-machine   ... from both machines' SavedVariables
    python tools/import_savedvars.py --merge-learned --contributions <shared folder>   ... and contributors' copies (see below)

--from DIR reads a copied SavedVariables folder (the play machine's) instead of the client's; --also DIR (repeatable)
adds more learned data to --merge-learned; --contributions DIR (repeatable) reads the shared folder that
tools/share_savedvars.ps1 fills (<id>/Signpost-<game folder>-<time>.lua per contributor): every file of one contributor and
game folder is folded, oldest first, into one source, so importing again, or importing a later copy, never double-counts;
--pack DIR is the data pack (default ../Signpost_Data). The maps go into
layers/client.json, the learned data (Core/Learn.lua, plus the NPC positions and zone crossings in the debug
recorder's event log) into layers/learned.json (signpost_tools/learned.py), and the pack is rebuilt from every layer
(datapack.build), learned last.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from signpost_tools import datapack, devconfig, learned  # noqa: E402
from signpost_tools.savedvars import LuaParseError  # noqa: E402
from signpost_tools.svfiles import ACCOUNT_VAR, SVFile, find_files, load_db  # noqa: E402

DEFAULT_PACK = devconfig.REPO_ROOT.parent / "Signpost_Data"
DEFAULT_GUIDES = devconfig.REPO_ROOT / "Guides"
CONTINENT = 2  # Enum.UIMapType.Continent


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


def maps_table(dump: dict) -> dict[int, dict]:
    """The client layer's maps from a /signpost dumpmaps result (Wowhead zone IDs come from the wowhead layer)."""
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
        # The client returns every flight node of the continent for each of its zones (positions projected into the
        # requested map), so the nodes are kept once, on the continent; world rectangles project them into zones.
        if entry.get("type") == CONTINENT:
            record["taxi"] = _points(entry.get("taxi"))
        record["dungeons"] = _points(entry.get("dungeons"))
        maps[map_id] = {k: v for k, v in record.items() if v is not None}
    return maps


def account_db(source: Path | None, config: Path | None) -> dict:
    """SignpostDB from the client's SavedVariables (source None) or a copied folder; exits when it is missing."""
    try:
        sv = find_files(source, config)[0]
        if not sv.path.exists():
            sys.exit(f"{sv.path} does not exist yet: log in, run the commands, then /reload")
        return load_db(sv)
    except (devconfig.ConfigError, LuaParseError) as exc:
        sys.exit(str(exc))


def contribution_sources(folder: Path) -> list[tuple[str, dict]]:
    """(label, SignpostDB) for each file under a shared folder: <id>/Signpost-<game folder>-<time>.lua. The label names
    the contributor and game folder, so their copies fold into one source, oldest first (the names sort by time)."""
    sources = []
    for path in sorted(Path(folder).glob("*/Signpost-*.lua")):
        flavor = path.stem.removeprefix("Signpost-").rsplit("-", 2)[0]
        try:
            sources.append((f"contrib-{path.parent.name}-{flavor}", load_db(SVFile(path, ACCOUNT_VAR, "account"))))
        except LuaParseError as exc:
            sys.exit(f"{path}: {exc}")
    return sources


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--from", dest="source", type=Path, help="read a copied SavedVariables folder")
    parser.add_argument("--config", type=Path, help="dev config (default tools/dev.local.json)")
    parser.add_argument("--json", action="store_true", help="write SignpostDB and the character DBs as JSON")
    parser.add_argument("--out", type=Path, help="with --json: the output file (default: print)")
    parser.add_argument("--maps", action="store_true", help="write Maps.lua into the data pack from mapDump")
    parser.add_argument(
        "--merge-learned",
        action="store_true",
        help="fold SignpostDB.learned and the event log's NPC positions and zone crossings into the learned layer",
    )
    parser.add_argument(
        "--also",
        type=Path,
        action="append",
        default=[],
        metavar="DIR",
        help="with --merge-learned: also read the learned data in this copied SavedVariables folder (repeatable)",
    )
    parser.add_argument(
        "--contributions",
        type=Path,
        action="append",
        default=[],
        metavar="DIR",
        help="with --merge-learned: also read the contributors' copies in this shared folder (repeatable)",
    )
    parser.add_argument("--pack", type=Path, default=DEFAULT_PACK, help="data pack folder (default ../Signpost_Data)")
    parser.add_argument("--guides", type=Path, default=DEFAULT_GUIDES, help=argparse.SUPPRESS)
    options = parser.parse_args()
    if not (options.json or options.maps or options.merge_learned):
        parser.error("choose --json, --maps and/or --merge-learned")
    if (options.also or options.contributions) and not options.merge_learned:
        parser.error("--also and --contributions only go with --merge-learned")

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

    written = []
    if options.maps:
        dump = databases["account"].get("mapDump")
        if not isinstance(dump, dict) or not dump.get("maps"):
            sys.exit("SignpostDB has no mapDump: type /signpost dumpmaps in game, wait for 'saved', then /reload")
        maps = maps_table(dump)
        origin = f"client dumpmaps, build {dump.get('build')}"
        datapack.write_layer(options.pack, "client", {"maps": maps}, origin)
        written.append(f"client layer: {len(maps)} maps ({origin})")

    if options.merge_learned:
        sources = [databases["account"]] + [account_db(folder, None) for folder in options.also]
        # No paths in the origin: it ends up in the pack's _meta.lua and data-gaps.md.
        origin = f"in game: Core/Learn.lua and the debug event log, {len(sources)} SavedVariables file(s)"
        # the labels stay the same between imports, so a source is folded into its own earlier record
        labels = ["local"] + [f"also-{Path(folder).name}" for folder in options.also]
        for folder in options.contributions:
            for label, db in contribution_sources(folder):
                sources.append(db)
                labels.append(label)
        stats = learned.merge_learned(options.pack, sources, origin, [options.guides], labels)
        written.append("learned layer: " + ", ".join(f"{count} {name}" for name, count in stats.items()))

    if written:
        counts = datapack.build(options.pack, "import_savedvars.py")
        print(f"{'; '.join(written)}; data pack rebuilt: {counts}")


if __name__ == "__main__":
    main()
