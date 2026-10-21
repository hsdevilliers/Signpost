"""The level the simulator (tools/guide_sim.py) has after every step of every guide, as a Lua table for the placement
simulation (tools/placement_report.lua --truth sim; docs/ENGINE.md "Engine/Placement.lua").

    python tools/placement_levels.py [--pack DIR] [--out plans/placement_levels.lua]

The file is `return { ["<guide id>"] = { start = <level at the first step>, steps = { ["<step id>"] = <level, with the
fraction of the way to the next, after that step> } } }`, one walk of each guide's first route (no profession tracks).

The numbers come from the private data pack (quest experience from QuestieDB's Classic seed, which Forever's tuning may
differ from): the file is derived from it, so it goes to plans/ (ignored by git) and is never committed. The pack is read,
never changed. Without the pack there is nothing to write.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path
from types import SimpleNamespace

sys.path.insert(0, str(Path(__file__).resolve().parent))

import guide_sim  # noqa: E402
import guide_travel  # noqa: E402
from signpost_tools import guidefile  # noqa: E402

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_OUT = REPO_ROOT / "plans" / "placement_levels.lua"
# What a guide or step id may hold: it goes into a Lua string unescaped.
SAFE_ID = re.compile(r"^[A-Za-z0-9:_.#-]+$")


def lua_levels(levels: dict[str, dict]) -> str:
    """The Lua text of {guide id: {"start": level, "steps": {step id: level}}}."""
    lines = ["-- written by tools/placement_levels.py from the data pack: derived from it, so never committed", "return {"]
    for guide_id in sorted(levels):
        data = levels[guide_id]
        if not SAFE_ID.match(guide_id):
            raise ValueError(f"unsafe guide id {guide_id!r}")
        lines.append(f'  ["{guide_id}"] = {{ start = {data["start"]}, steps = {{')
        for step_id, level in data["steps"].items():
            if not SAFE_ID.match(step_id):
                raise ValueError(f"unsafe step id {step_id!r}")
            lines.append(f'    ["{step_id}"] = {level},')
        lines.append("  } },")
    lines.append("}")
    return chr(10).join(lines) + chr(10)


def simulate_levels(root: Path, pack_dir: Path) -> dict[str, dict]:
    """Walks the first route of every guide with the simulator; raises ValueError without a usable pack."""
    project = guidefile.load_project(root)
    pack = guide_travel.load_pack(pack_dir)
    if not pack.present:
        raise ValueError("no data pack: " + pack.describe())
    params = guide_sim.load_params()
    quest_xp = guide_sim.read_quest_xp(pack_dir)
    quests, npcs, items = pack.table("quests"), pack.table("npcs"), pack.table("items")
    model = guide_sim.Model(params, quests, npcs, items, quest_xp)
    worlds: dict[str, guide_travel.World] = {}

    def world_for(faction: str) -> guide_travel.World:
        if faction not in worlds:
            worlds[faction] = guide_travel.World(pack, project.borders, faction)
        return worlds[faction]

    # guide_travel.guide_routes reads these from the command line options; no filter, no profession tracks
    options = SimpleNamespace(faction=None, race=None, cls=None, profession=[], no_tracks=True)
    out: dict[str, dict] = {}
    for guide_id, guide in sorted(project.guides.items()):
        routes = guide_travel.guide_routes(project, guide, options, world_for)
        if not routes:
            continue
        route = routes[0]
        result = guide_sim.run_one(route, world_for(route.variant.faction), quests, npcs, items, quest_xp, params)
        out[guide_id] = {
            "start": route.chapters[0].levels[0] if route.chapters else 1,
            "steps": {log.id: round(log.level + log.xp / model.to_next(log.level), 3) for log in result.log},
        }
    return out


def write_levels(root: Path, pack_dir: Path, out: Path) -> dict[str, dict]:
    levels = simulate_levels(root, pack_dir)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(lua_levels(levels), encoding="utf-8", newline=chr(10))
    return levels


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--root", type=Path, default=REPO_ROOT)
    parser.add_argument("--pack", type=Path)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    options = parser.parse_args(argv)
    guide_travel.safe_stdout()
    pack_dir = options.pack or guide_travel.default_pack_dir(options.root)
    if pack_dir is None:
        print("placement_levels needs the data pack (--pack DIR, or Signpost_Data beside the repository)")
        return 1
    try:
        levels = write_levels(options.root, pack_dir, options.out)
    except ValueError as exc:
        print(exc)
        return 1
    for guide_id, data in levels.items():
        print(f"{guide_id}: {len(data['steps'])} steps from level {data['start']}")
    print(f"written to {options.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
