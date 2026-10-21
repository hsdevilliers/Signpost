"""tools/placement_levels.py (the simulator's levels for the placement simulation) and tools/placement_report.py (the one
command that re-runs it)."""

import tempfile
import unittest
from pathlib import Path

import placement_levels
import placement_report
from tests.guide_fixtures import MAPS, TRAVEL, TempProject, chapter_lua, guide_lua, write_pack

NL = chr(10)

QUESTS = {1: {"n": "Early", "l": 1, "r": 1, "o": [{"id": 50, "k": "kill"}], "s": {"npc": [1001]}, "e": {"npc": [1001]}}}
NPCS = {50: {"n": "Boar"}, 1001: {"n": "Giver", "p": [[10, 40, 40]]}}
TEXT = (
    "#chapter 1-5 One" + NL
    + "step" + NL + "  .goto 10,40,40" + NL + "  .accept 1" + NL
    + "step" + NL + "  .goto 10,40,40" + NL + "  .complete 1,1" + NL
    + "step" + NL + "  .goto 10,40,40" + NL + "  .turnin 1" + NL
)


class LuaLevelsTest(unittest.TestCase):
    def test_a_table_per_guide_sorted_with_a_level_per_step(self):
        text = placement_levels.lua_levels(
            {"b-guide": {"start": 1, "steps": {"c:1": 1.0, "c:2": 2.5}}, "a-guide": {"start": 3, "steps": {}}}
        )
        self.assertEqual(text.split(NL)[1], "return {")
        self.assertIn('["a-guide"] = { start = 3, steps = {', text)
        self.assertIn('["c:2"] = 2.5,', text)
        self.assertLess(text.index("a-guide"), text.index("b-guide"))
        self.assertTrue(text.endswith("}" + NL))

    def test_refuses_what_a_lua_string_could_not_hold(self):
        for bad in ('a"b', "a" + chr(92) + "b", "a b", ""):
            with self.assertRaises(ValueError, msg=repr(bad)):
                placement_levels.lua_levels({bad: {"start": 1, "steps": {}}})
            with self.assertRaises(ValueError, msg=repr(bad)):
                placement_levels.lua_levels({"g": {"start": 1, "steps": {bad: 1}}})


class SimulateLevelsTest(TempProject):
    def project(self):
        write_pack(self.pack_dir, {"maps": MAPS, "quests": QUESTS, "npcs": NPCS, "travel": TRAVEL})
        self.files({"Guides/Test.lua": guide_lua("#include c" + NL), "Guides/Chapters/c.lua": chapter_lua("c", TEXT)})

    def test_a_level_after_every_step_with_the_way_to_the_next(self):
        self.project()
        data = placement_levels.simulate_levels(self.root, self.pack_dir)["test-guide"]
        self.assertEqual(data["start"], 1)
        self.assertEqual(list(data["steps"]), ["c:1", "c:2", "c:3"])  # the ids the parser gives the steps
        values = list(data["steps"].values())
        self.assertEqual(values, sorted(values))  # a character never loses experience
        self.assertGreater(values[-1], 1)  # the quest gave some
        self.assertTrue(all(isinstance(value, float) for value in values))

    def test_without_a_pack_it_says_so(self):
        self.files({"Guides/Test.lua": guide_lua("#include c" + NL), "Guides/Chapters/c.lua": chapter_lua("c", TEXT)})
        with self.assertRaises(ValueError):
            placement_levels.simulate_levels(self.root, self.pack_dir)

    def test_the_file_goes_where_it_is_told_and_is_lua(self):
        self.project()
        out = self.root / "plans" / "levels.lua"
        placement_levels.write_levels(self.root, self.pack_dir, out)
        text = out.read_text(encoding="utf-8")
        self.assertTrue(text.startswith("-- written by tools/placement_levels.py"))
        self.assertIn('["test-guide"] = { start = 1, steps = {', text)
        self.assertIn('["c:3"] = ', text)


class FindLuaTest(unittest.TestCase):
    def toolchain(self, base: Path) -> Path:
        folder = base / ".venv" / "lua51" / "bin"
        folder.mkdir(parents=True)
        (folder / "lua.exe").write_text("", encoding="utf-8")
        (folder / "lua").write_text("", encoding="utf-8")
        return folder

    def test_the_test_toolchain_comes_before_the_path(self):
        with tempfile.TemporaryDirectory() as tmp:
            folder = self.toolchain(Path(tmp))
            found = placement_report.find_lua(Path(tmp), which=lambda name: "/usr/bin/" + name, roots=[Path(tmp)])
            self.assertEqual(Path(found).parent, folder)

    def test_a_worktree_uses_the_main_checkouts_toolchain(self):
        with tempfile.TemporaryDirectory() as tmp:
            worktree = Path(tmp) / "worktree"
            worktree.mkdir()
            folder = self.toolchain(Path(tmp) / "main")
            found = placement_report.find_lua(worktree, which=lambda name: None, roots=[worktree, Path(tmp) / "main"])
            self.assertEqual(Path(found).parent, folder)

    def test_the_path_is_the_fallback_in_the_order_lua51_lua_luajit(self):
        with tempfile.TemporaryDirectory() as tmp:
            roots = [Path(tmp)]
            self.assertEqual(placement_report.find_lua(Path(tmp), which=lambda n: "/x/" + n, roots=roots), "/x/lua5.1")
            only = {"lua": "/y/lua", "luajit": "/y/luajit"}
            self.assertEqual(placement_report.find_lua(Path(tmp), which=only.get, roots=roots), "/y/lua")
            self.assertEqual(
                placement_report.find_lua(Path(tmp), which={"luajit": "/z/luajit"}.get, roots=roots), "/z/luajit"
            )

    def test_none_when_there_is_no_lua(self):
        with tempfile.TemporaryDirectory() as tmp:
            self.assertIsNone(placement_report.find_lua(Path(tmp), which=lambda name: None, roots=[Path(tmp)]))


if __name__ == "__main__":
    unittest.main()
