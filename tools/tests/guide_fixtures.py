"""Synthetic guides, chapters, tracks, modules and data packs for the guide tool tests (no real game data)."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from signpost_tools import datapack
from signpost_tools.luawriter import write_lua

# A guide's text starts on this line of the file guide_lua() writes; chapters and tracks start on line 3.
GUIDE_FIRST_LINE = 11
TEXT_FIRST_LINE = 3


def _list(items) -> str:
    return "{ " + ", ".join(f'"{item}"' for item in items) + " }"


def guide_lua(text, gid="test-guide", faction="Horde", races=("Troll",), classes=("HUNTER",), levels=(1, 20)) -> str:
    return (
        "local ADDON_NAME, ns = ...\n"
        "\n"
        "ns.Guides:Register({\n"
        f'\tid = "{gid}",\n'
        '\tname = "Test Guide",\n'
        f'\tfaction = "{faction}",\n'
        f"\traces = {_list(races)},\n"
        f"\tclasses = {_list(classes)},\n"
        f"\tlevels = {{ {levels[0]}, {levels[1]} }},\n"
        f"\ttext = [[\n{text}]],\n"
        "})\n"
    )


def chapter_lua(chapter_id: str, text: str) -> str:
    return f'local ADDON_NAME, ns = ...\nns.Chapters:Register("{chapter_id}", [[\n{text}]])\n'


def track_lua(key: str, text: str) -> str:
    return f'local ADDON_NAME, ns = ...\nns.Professions:RegisterTrack("{key}", [[\n{text}]])\n'


HUNTER_LUA = """local ADDON_NAME, ns = ...
local function level(args)
	local n = tonumber(args)
	return { npc = n }
end
ns.Classes:Register("HUNTER", {
	trainerSpells = { [10] = { 1515 } },
	classQuests = {
		{ id = "hunters-path", name = "The Hunter's Path", level = 10, quests = { 6061, 6062 } },
		{ id = "late-chain", name = "Late Chain", level = 50, quests = { 9001 } },
	},
	directives = {
		tame = { parse = level, describe = function(args) return "Tame " .. args.npc end },
	},
})
"""

SKINNING_LUA = """local ADDON_NAME, ns = ...
ns.Professions:Register("skinning", { skillLine = 393, primary = true, gathering = true, ranks = { 75, 150 } })
"""
FIRSTAID_LUA = """local ADDON_NAME, ns = ...
ns.Professions:Register("firstaid", { skillLine = 129, primary = false, ranks = { 75, 150 } })
"""

BORDERS_LUA = """local ADDON_NAME, ns = ...
ns.Travel:RegisterBorders({
	{ name = "Westland/Eastland bridge", from = { 10, 95, 50 }, to = { 20, 5, 50 } },
	{ name = "Eastland/Towne gate", from = { 20, 50, 51 }, to = { 30, 50, 99 } },
	{ name = "Westland/Northland pass", from = { 10 }, to = { 50 } },
})
"""

# A small world: continent 100 (instance 1) with Westland (10, the west half), Eastland (20, the east half), the city
# Towne (30) inside Eastland, Northland (50) north of both, a cave (11) inside Westland; continent 200 (instance 2)
# with Isle (40). World rectangles are { instance, x0, y0, x1, y1 } of the top-left and bottom-right corners.
MAPS = {
    100: {
        "n": "Mainland",
        "t": 2,
        "parent": 1,
        "world": [1, 1000, 1000, -1000, -1000],
        "taxi": [
            {"id": 1, "n": "Towne, Eastland", "x": 75, "y": 45, "faction": 1},
            {"id": 2, "n": "Westhold, Westland", "x": 25, "y": 50, "faction": 1},
            {"id": 3, "n": "Allyport, Westland", "x": 10, "y": 50, "faction": 2},
            {"id": 4, "n": "zzOLDTowne, Eastland", "x": 75, "y": 45, "faction": 1},
        ],
    },
    10: {"n": "Westland", "t": 3, "parent": 100, "world": [1, 1000, 1000, -1000, 0]},
    11: {"n": "Westland Cave", "t": 5, "parent": 10, "world": [1, 100, 600, 0, 500]},
    20: {"n": "Eastland", "t": 3, "parent": 100, "world": [1, 1000, 0, -1000, -1000]},
    30: {"n": "Towne", "t": 3, "parent": 100, "world": [1, 200, -400, 0, -600]},
    50: {"n": "Northland", "t": 3, "parent": 100, "world": [1, 3000, 1000, 1000, -1000]},
    200: {"n": "Isles", "t": 2, "parent": 1, "world": [2, 500, 500, -500, -500]},
    40: {"n": "Isle", "t": 3, "parent": 200, "world": [2, 500, 500, -500, -500]},
}

QUESTS = {
    101: {"n": "First Steps", "r": 1, "s": {"npc": [1001]}, "e": {"npc": [1001]}},
    102: {"n": "Too Early", "r": 15, "s": {"npc": [1001]}, "e": {"npc": [1001]}},
    103: {"n": "Bit Early", "r": 9, "s": {"npc": [1001]}, "e": {"npc": [1001]}},
    104: {"n": "Eastern Errand", "r": 1, "s": {"npc": [1002]}, "e": {"npc": [1002]}},
    6061: {"n": "Taming", "r": 10},
    6062: {"n": "Taming Again", "r": 10},
    7001: {"n": "Skinning Lesson", "r": 1},
}
NPCS = {1001: {"n": "Questgiver", "p": [[10, 40, 40]]}, 1002: {"n": "Easterner", "p": [[20, 60, 60]]}}
TRAVEL = {
    "flightMasters": {},
    "inns": {},
    "transports": [{"kind": "boat", "from": [20, 90, 90], "to": [40, 10, 10], "side": "both"}],
    "crossings": [],
}


def write_files(root: Path, files: dict[str, str]) -> None:
    for relative, text in files.items():
        path = root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8", newline="\n")


def write_pack(root: Path, tables: dict | None = None, classes: dict | None = None) -> Path:
    """A data pack in the generated layout (schema, tables, classes/<CLASS>.lua)."""
    tables = {"maps": MAPS, "quests": QUESTS, "npcs": NPCS, "travel": TRAVEL} if tables is None else tables
    root.mkdir(parents=True, exist_ok=True)
    meta = {"schema": datapack.SCHEMA, "source": "generated", "generated": "2026-10-17", "tables": {}}
    datapack.write_meta(root, meta, "test")
    for table in datapack.TABLE_FILES:
        empty = datapack.empty_travel() if table == "travel" else {}
        datapack.write_table(root, table, tables.get(table, empty), "test")
    for token, record in (classes or {}).items():
        (root / "classes").mkdir(exist_ok=True)
        write_lua(root / "classes" / f"{token}.lua", ["test"], [(f"{datapack.GLOBAL}.classes.{token}", record)])
    return root


class TempProject(unittest.TestCase):
    """A test case with a fresh project folder (self.root) and a sibling folder for a data pack (self.pack_dir)."""

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        base = Path(self._tmp.name)
        self.root = base / "Signpost"
        self.root.mkdir()
        self.pack_dir = base / "pack"

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def files(self, files: dict[str, str]) -> None:
        write_files(self.root, files)
