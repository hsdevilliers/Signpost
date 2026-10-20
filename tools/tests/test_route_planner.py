import contextlib
import io
import json
import tempfile
import unittest
from pathlib import Path

import route_planner as rp
from signpost_tools import guidefile
from tests.guide_fixtures import BORDERS_LUA, MAPS, TRAVEL, TempProject, guide_lua, write_pack
from tests.test_guide_draft import NPCS, QUESTS

ITEMS = {9999: {"n": "Thing"}, 9998: {"n": "Elite Drop", "drops": [3002]}, 9997: {"n": "Stone", "drops": [3002], "objDrops": [1]}}


class FormatTest(unittest.TestCase):
    def test_time_and_bars(self):
        self.assertEqual(rp.hms(3660), "1h01")
        self.assertEqual(rp.hms(0), "0h00")
        self.assertEqual(rp.mins(150), "2m")
        self.assertEqual(rp.bar(0.5, 10), "#####.....")
        self.assertEqual(rp.bar(2.0, 4), "####")  # never more than the width
        self.assertEqual(rp.bar(-1, 4), "....")
        self.assertEqual(rp.share(25, 100).strip(), "25.0%")
        self.assertEqual(rp.share(1, 0).strip(), "-")

    def test_wrap_keeps_the_indent_and_the_width(self):
        lines = rp.wrap("word " * 60, "  ", 40)
        self.assertTrue(all(len(line) <= 40 and line.startswith("  ") for line in lines))
        self.assertGreater(len(lines), 5)

    def test_a_label_takes_the_first_line_and_the_text_hangs_under_it(self):
        lines = rp.labelled("class quests  ", "word " * 40, 40)
        self.assertTrue(lines[0].startswith("class quests  word"))
        self.assertTrue(all(line.startswith(" " * 14) for line in lines[1:]))
        self.assertTrue(all(len(line) <= 40 for line in lines))
        self.assertEqual(rp.labelled("x  ", ""), [])

    def test_quiet_output_keeps_every_line_for_the_report_file(self):
        out = rp.Out(quiet=True)
        buffer = io.StringIO()
        with contextlib.redirect_stdout(buffer):
            out("hidden")
            out("shown", always=True)
            out.section("A title")
        self.assertEqual(buffer.getvalue().strip(), "shown")
        self.assertEqual([line for line in out.lines if line][0], "hidden")
        self.assertTrue(any("A title" in line for line in out.lines))


class RouteCase(TempProject):
    def setUp(self):
        super().setUp()
        self.files(
            {
                "Guides/Test.lua": guide_lua("step\n  .goto 10,50,50\n", gid="test-guide", races=("Troll",), classes=("HUNTER",)),
                "Guides/Hardcore.lua": guide_lua(
                    "step\n  .goto 10,50,50\n", gid="test-hardcore", races=("Orc",), classes=("WARRIOR",)
                ).replace('name = "Test Guide"', 'name = "Test Hardcore (HARDCORE)"'),
                "Guides/Travel/Borders.lua": BORDERS_LUA,
            }
        )
        self.pack = write_pack(self.pack_dir, {"maps": MAPS, "quests": QUESTS, "npcs": NPCS, "travel": TRAVEL, "items": ITEMS})

    def run_main(self, *args):
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = rp.main([*args, "--root", str(self.root), "--pack", str(self.pack)])
        return code, out.getvalue()


class GuideChoiceTest(RouteCase):
    def test_a_guide_is_named_by_any_of_its_words_and_its_kind_comes_from_its_name(self):
        project = guidefile.load_project(self.root)
        self.assertEqual([g.id for g in rp.find_guides(project, ["troll"])], ["test-guide"])
        self.assertEqual([g.id for g in rp.find_guides(project, ["warrior", "orc"])], ["test-hardcore"])
        self.assertEqual(len(rp.find_guides(project, ["horde"])), 2)
        self.assertEqual(rp.find_guides(project, ["nothing"]), [])
        self.assertEqual(rp.kind_of(self.root, project.guides["test-hardcore"]), "HARDCORE")
        self.assertEqual(rp.kind_of(self.root, project.guides["test-guide"]), "normal")

    def test_the_manifest_decides_the_kind_when_it_names_the_guide(self):
        (self.root / "tools").mkdir(exist_ok=True)
        (self.root / "tools" / "drafts.json").write_text(json.dumps({"guides": [{"guide": "test-guide", "hardcore": True}]}), encoding="utf-8")
        project = guidefile.load_project(self.root)
        self.assertEqual(rp.kind_of(self.root, project.guides["test-guide"]), "HARDCORE")

    def test_no_guide_lists_them_and_an_unknown_one_exits_with_2(self):
        code, text = self.run_main()
        self.assertEqual(code, 0)
        self.assertIn("test-guide", text)
        self.assertIn("HARDCORE", text)
        code, text = self.run_main("zzz")
        self.assertEqual(code, 2)
        self.assertIn("no guide", text)
        code, text = self.run_main("horde")
        self.assertEqual(code, 2)
        self.assertIn("several guides", text)


class EndToEndTest(RouteCase):
    def test_a_plan_is_made_written_as_guide_steps_checked_and_reported(self):
        code, text = self.run_main("troll", "--preset", "greedy", "--cap", "6", "--no-write", "--steps", "4", "--decisions", "0")
        self.assertEqual(code, 0, text)
        for heading in ("ROUTE PLANNER", "THE SEARCH", "THE ROUTE AS A GRAPH", "TIME AND EXPERIENCE", "THE QUESTS",
                        "CHECKED BY THE SAME SIMULATOR AND LINT"):
            self.assertIn(heading, text)
        self.assertIn("availability  0 error(s)", text)
        self.assertIn("lint          0 error(s)", text)
        self.assertIn("reaches level 6", text)
        self.assertIn("greedy:", text.strip().splitlines()[-1])

    def test_every_technique_compares_in_one_table_and_files_are_written(self):
        with tempfile.TemporaryDirectory() as out_dir:
            code, text = self.run_main(
                "troll", "--preset", "all", "--cap", "6", "--width", "8", "--runs", "10", "--out", out_dir, "--steps", "2", "--decisions", "2"
            )
            self.assertEqual(code, 0, text)
            self.assertIn("COMPARISON OF THE TECHNIQUES", text)
            self.assertIn("UNDER UNCERTAIN ASSUMPTIONS", text)
            for preset in rp.PRESETS:
                target = Path(out_dir) / preset
                self.assertTrue((target / "plan.json").is_file(), preset)
                self.assertTrue((target / "report.txt").is_file(), preset)
                self.assertTrue((target / "Guides" / "Plan.lua").is_file(), preset)
                self.assertTrue(list((target / "Guides" / "Chapters").glob("plan-*.lua")), preset)
            data = json.loads((Path(out_dir) / "beam" / "plan.json").read_text(encoding="utf-8"))
            self.assertTrue(data["complete"])
            self.assertEqual(data["lint_errors"], [])
            self.assertEqual(data["guide"], "test-guide")

    def test_hardcore_is_taken_from_the_guide_and_can_be_overridden(self):
        code, text = self.run_main("orc", "--preset", "greedy", "--cap", "6", "--no-write", "--steps", "1", "--decisions", "0")
        self.assertIn("[HARDCORE route]", text)
        code, text = self.run_main("orc", "--preset", "greedy", "--cap", "6", "--no-write", "--steps", "1", "--decisions", "0", "--mode", "normal")
        self.assertIn("[normal route]", text)


if __name__ == "__main__":
    unittest.main()
