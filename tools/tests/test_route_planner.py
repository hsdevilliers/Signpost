import contextlib
import io
import json
import re
import tempfile
import types
import unittest
from pathlib import Path
from unittest import mock

import planner as engine
import route_install
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

    def test_the_completeness_rule_is_stated_in_the_setup_and_switched_by_the_options(self):
        args = ("troll", "--preset", "greedy", "--cap", "6", "--no-write", "--steps", "0", "--decisions", "0")
        code, text = self.run_main(*args)
        self.assertEqual(code, 0, text)
        flat = " ".join(text.split())
        self.assertIn("a quest the route picked up and did not finish is taken out when the route is written, and listed with the reason "
                      "(--completeness F finishes the ones that are a short walk away and pay at least F of the route's pace; off)", flat)
        code, text = self.run_main(*args, "--completeness", "0.6", "--completeness-trip", "45")
        self.assertEqual(code, 0, text)
        flat = " ".join(text.split())
        self.assertIn("is finished when its objectives are at most 45 s of walking away and it pays at least 60% of the route's pace "
                      "(--completeness, --completeness-trip); the rest are taken out and listed with the reason", flat)
        self.assertNotIn("is taken out when the route is written", flat)

    def test_what_the_route_leaves_unfinished_is_named_with_the_reason_in_the_report_the_plan_file_and_the_guide(self):
        with tempfile.TemporaryDirectory() as out_dir:
            code, text = self.run_main("troll", "--preset", "greedy", "--cap", "4", "--out", out_dir, "--steps", "0", "--decisions", "0")
            self.assertEqual(code, 0, text)
            flat = " ".join(text.split())
            self.assertIn("unfinished 3 quests the search picked up on the way and did not finish are not in the route "
                          "(2 hand-in too far, 1 could not be worked):", flat)
            self.assertIn("202 Follows First (level 1, picked up at level 1, Giver): it is handed in 96 s of walking away", flat)
            self.assertIn("229 Hub Rats (level 6, picked up at level 1, Giver): it could not be worked at level 1", flat)
            self.assertIn("tidied 3 quests the search had accepted but never finished", flat)
            data = json.loads((Path(out_dir) / "greedy" / "plan.json").read_text(encoding="utf-8"))
            self.assertEqual((data["completeness"], data["completeness_trip"]), (0.0, 30.0))
            self.assertEqual([(r["quest"], r["code"]) for r in data["left_out"]], [(202, "handin"), (211, "handin"), (229, "level")])
            self.assertEqual(data["completed"], [])
            record = data["left_out"][0]
            for field in ("name", "level", "picked_level", "hub", "why", "trip", "handin", "work", "rate", "pace", "ratio", "unplaced"):
                self.assertIn(field, record)
            guide = (Path(out_dir) / "greedy" / "Guides" / "Plan.lua").read_text(encoding="utf-8")
            self.assertIn("#skipquest 202 >> not finished by this route: it is handed in 96 s of walking away", guide)
            self.assertIn("#skipquest 229 >> not finished by this route: it could not be worked at level 1", guide)

    def test_completeness_finishes_the_quests_a_short_walk_away_and_the_reports_say_so(self):
        with tempfile.TemporaryDirectory() as out_dir:
            code, text = self.run_main(
                "troll", "--preset", "greedy", "--cap", "4", "--completeness", "0.01", "--completeness-trip", "200", "--out", out_dir,
                "--steps", "0", "--decisions", "0",
            )
            self.assertEqual(code, 0, text)
            flat = " ".join(text.split())
            self.assertIn("completed 2 more quests the search left unfinished were finished instead (completeness 0.01, trips up to 200 s)", flat)
            self.assertIn("unfinished 1 quests the search picked up on the way and did not finish are not in the route (1 could not be worked):", flat)
            data = json.loads((Path(out_dir) / "greedy" / "plan.json").read_text(encoding="utf-8"))
            self.assertEqual((data["completeness"], data["completeness_trip"]), (0.01, 200.0))
            self.assertEqual(data["completed"], [202, 211])
            self.assertEqual(data["completed_unplaced"], [])  # (the fixture's two have positions)
            self.assertEqual([r["quest"] for r in data["left_out"]], [229])
            guide = (Path(out_dir) / "greedy" / "Guides" / "Plan.lua").read_text(encoding="utf-8")
            self.assertNotIn("#skipquest 202", guide)  # a quest that was finished is in the route, not skipped
            self.assertIn("#skipquest 229 >> not finished by this route", guide)
            self.assertIn("availability  0 error(s)", text)  # and the route as written is still one the game would offer
            self.assertIn("lint          0 error(s)", text)

    def test_the_report_says_how_many_quests_the_log_holds_at_most_and_the_limit_is_obeyed(self):
        args = ("troll", "--preset", "greedy", "--cap", "6", "--no-write", "--steps", "0", "--decisions", "0")
        code, text = self.run_main(*args)
        self.assertIn("the quest log holds at most 40 quests", text)
        free = int(re.search(r"the most quests held at once: (\d+) \(at level \d+, \d+h\d\d in\); the log holds 40", text).group(1))
        self.assertGreater(free, 3)  # the fixture holds a dozen when it may
        self.assertRegex(text, rf"the written route holds at most {free} quests at once \(the log holds 40\)")
        code, text = self.run_main(*args, "--quest-log", "3")
        self.assertEqual(code, 0, text)
        self.assertIn("the quest log holds at most 3 quests", text)
        held = int(re.search(r"the most quests held at once: (\d+)", text).group(1))
        self.assertLessEqual(held, 3)
        self.assertRegex(text, rf"the written route holds at most {held} quests at once \(the log holds 3\)")
        self.assertNotIn("ERROR, more than the log holds", text)

    def test_the_grind_steps_are_listed_with_their_amounts_and_each_says_how_much_in_the_chapters(self):
        with tempfile.TemporaryDirectory() as out_dir:
            code, text = self.run_main("troll", "--preset", "greedy", "--cap", "8", "--out", out_dir, "--steps", "0", "--decisions", "0")
            self.assertEqual(code, 0, text)
            self.assertRegex(text, r"grinding      1 grind step\(s\) ask the player to kill for a level: [\d,]+ experience \(\d+\.\d% of the route's\)")
            self.assertRegex(text, r"at \d+h\d\d: level \d to 8, about [\d,]+ experience, about [\d,]+ kills, \d+m")
            chapters = sorted((Path(out_dir) / "greedy" / "Guides" / "Chapters").glob("plan-*.lua"))
            written = "\n".join(path.read_text(encoding="utf-8") for path in chapters)
            self.assertRegex(
                written,
                r"\.level 8 -- reach it first: kill or grind on the way\n  \.note Grind about [\d,]+ experience before you go on: "
                r"about [\d,]+ kills of creatures near your level \(an estimate\)",
            )
            data = json.loads((Path(out_dir) / "greedy" / "plan.json").read_text(encoding="utf-8"))
            self.assertEqual(len(data["grinds"]), 1)
            self.assertEqual(data["grinds"][0]["level_to"], 8)

    def test_the_chapters_are_cut_where_the_zone_changes_for_as_long_as_the_setting_asks(self):
        counts = {}
        for asked in (1, 100):
            with tempfile.TemporaryDirectory() as out_dir:
                args = ("troll", "--preset", "greedy", "--cap", "6", "--out", out_dir, "--chapter-steps", str(asked), "--steps", "0", "--decisions", "0")
                code, text = self.run_main(*args)
                self.assertEqual(code, 0, text)
                counts[asked] = len(list((Path(out_dir) / "greedy" / "Guides" / "Chapters").glob("plan-*.lua")))
        self.assertEqual(counts[100], 1)  # one long stay is all there is
        self.assertGreater(counts[1], 1)  # every change of zone is a chapter when one step is enough

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
            self.assertEqual(data["quest_log_limit"], 40)
            self.assertGreater(data["quest_log_peak"], 0)
            thorough = json.loads((Path(out_dir) / "thorough" / "plan.json").read_text(encoding="utf-8"))
            self.assertEqual([g["parts"] for g in thorough["grains"]], [2, 4, 8])  # every grain of thorough is in the plan file with what it found
            self.assertIn("grains        each grain of progress searched on its own", text)

    def test_the_route_starts_where_the_guide_does_or_at_the_races_first_quest(self):
        code, text = self.run_main("troll", "--preset", "greedy", "--cap", "6", "--no-write", "--steps", "1", "--decisions", "0")
        self.assertIn("(the guide's first step)", text)
        code, text = self.run_main(
            "troll", "--preset", "greedy", "--cap", "6", "--no-write", "--steps", "1", "--decisions", "0", "--start", "999,50,50"
        )
        self.assertEqual(code, 0, text)  # no hub on that map: the race's first quest decides
        self.assertIn("(the race's first quest)", text)

    def test_the_zones_that_are_not_leveling_content_come_from_the_rules_file(self):
        rules = self.root / "tools" / "hardcore_rules.json"
        rules.parent.mkdir(exist_ok=True)
        reason = "battleground (PvP) quest, not leveling content"
        rules.write_text(json.dumps({"rules": [], "skip_zones": [{"zone": 20, "reason": reason}]}), encoding="utf-8")
        args = ("troll", "--preset", "greedy", "--cap", "6", "--no-write", "--steps", "0", "--decisions", "0")
        code, text = self.run_main(*args)
        self.assertEqual(code, 0, text)
        self.assertIn(reason, text)  # the quest of that zone is left out, and the report says why
        rules.unlink()
        self.assertNotIn(reason, self.run_main(*args)[1])

    def test_the_ferry_is_the_shared_price_unless_the_command_line_says_otherwise(self):
        for extra, minutes in (((), 7), (("--ferry", "9"), 9)):
            code, text = self.run_main("troll", "--preset", "greedy", "--cap", "6", "--no-write", "--steps", "1", "--decisions", "0", *extra)
            self.assertEqual(code, 0, text)
            self.assertIn(f"boat or zeppelin + {minutes} min + the walk from the other capital", " ".join(text.split()))
        self.assertEqual(engine.Settings().ferry_seconds, 420.0)  # pricing.PRICES.ferry
        self.assertIn("Both price travel with the same numbers (signpost_tools/pricing.py", " ".join(text.split()))  # the fidelity line

    def test_a_rule_about_another_classes_quest_skips_it_for_the_other_classes_guides_only(self):
        rules = self.root / "tools" / "hardcore_rules.json"
        rules.parent.mkdir(exist_ok=True)
        line = "#skipquest 203 >> probably another class's quest"
        for owner, skipped in (("WARLOCK", True), ("HUNTER", False)):  # the Troll Hunter's guide is a normal one
            rule = {"id": 203, "action": "skip", "reason": "probably another class's quest", "class_quest_of": owner}
            rules.write_text(json.dumps({"rules": [rule]}), encoding="utf-8")
            with tempfile.TemporaryDirectory() as out_dir:
                code, text = self.run_main("troll", "--preset", "greedy", "--cap", "6", "--out", out_dir, "--steps", "0", "--decisions", "0")
                self.assertEqual(code, 0, text)
                plan = (Path(out_dir) / "greedy" / "Guides" / "Plan.lua").read_text(encoding="utf-8")
            self.assertEqual(line in plan, skipped, owner)

    def test_hardcore_is_taken_from_the_guide_and_can_be_overridden(self):
        code, text = self.run_main("orc", "--preset", "greedy", "--cap", "6", "--no-write", "--steps", "1", "--decisions", "0")
        self.assertIn("[HARDCORE route]", text)
        code, text = self.run_main("orc", "--preset", "greedy", "--cap", "6", "--no-write", "--steps", "1", "--decisions", "0", "--mode", "normal")
        self.assertIn("[normal route]", text)


class SearchReportTest(unittest.TestCase):
    def report(self, settings=None, quests=None, **stats):
        plan = engine.Plan(complete=True, seconds=900.0, stats=stats, alternatives=[object()])
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            rp.report_search(rp.Out(), mock.Mock(s=settings or engine.Settings(), quests=quests or {}), rp.Outcome("beam", plan, 1.0))
        return out.getvalue()

    def test_quests_finished_by_completeness_are_named_and_the_ones_the_data_cannot_place_are_counted(self):
        quests = {n: types.SimpleNamespace(name=f"Quest {n}") for n in (1, 2, 3)}
        settings = engine.Settings(completeness=0.6, completeness_trip=40.0)
        text = " ".join(self.report(settings, quests, finals=12, baseline_seconds=1000.0, chosen="beam", completed=[1, 2, 3], completed_unplaced=[2]).split())
        self.assertIn("completed 3 more quests the search left unfinished were finished instead (completeness 0.60, trips up to 40 s): "
                      "the route stops at their objectives right after the pick-up: Quest 1, Quest 2, Quest 3", text)
        self.assertIn("; 1 with an objective that has no position in the data", text)
        plain = " ".join(self.report(settings, quests, finals=12, baseline_seconds=1000.0, chosen="beam", completed=[1], completed_unplaced=[]).split())
        self.assertNotIn("no position in the data", plain)
        self.assertNotIn("more quests the search left unfinished", self.report(finals=12, baseline_seconds=1000.0, chosen="beam"))  # nothing finished: no line

    def test_a_beam_that_finished_nothing_says_so(self):
        text = self.report(finals=0, baseline_seconds=1000.0, chosen="greedy")
        self.assertIn("NO route of its own", text)
        self.assertNotIn("none faster", text)

    def test_a_beam_that_beat_nothing_says_the_route_is_the_greedy_one(self):
        text = self.report(finals=12, baseline_seconds=800.0, chosen="greedy")
        self.assertIn("none faster than the greedy one once tidied", text)
        self.assertNotIn("NO route of its own", text)

    def test_a_search_of_several_grains_says_how_far_apart_they_are_and_one_grain_says_nothing_of_it(self):
        grains = [dict(parts=2, finals=5, seconds=1.0, total=900.0), dict(parts=4, finals=7, seconds=2.0, total=1000.0)]
        self.assertIn("the grains disagree by", self.report(finals=12, baseline_seconds=1000.0, chosen="beam", grains=grains))
        self.assertNotIn("the grains disagree", self.report(finals=12, baseline_seconds=1000.0, chosen="beam", grains=grains[:1]))
        self.assertNotIn("the grains disagree", self.report(finals=12, baseline_seconds=1000.0, chosen="beam"))

    def test_a_beam_that_won_says_how_many_routes_it_finished_and_how_much_faster(self):
        text = self.report(finals=12, baseline_seconds=1000.0, chosen="beam")
        self.assertIn("12 complete routes reached the cap", text)
        self.assertIn("the best 2 with different orders of zones", text)
        self.assertIn("10.0% faster", text)  # the route takes 900 s against the greedy route's 1000 s
        self.assertNotIn("this is the greedy route", text)


class QuestLogPeakTest(unittest.TestCase):
    def test_a_written_route_is_counted_on_its_own_steps_an_accept_adds_one_and_a_hand_in_takes_one_out(self):
        def step(*directives):
            return types.SimpleNamespace(directives=[types.SimpleNamespace(name=name, args={"quest": quest} if quest else {}) for name, quest in directives])

        route = types.SimpleNamespace(
            steps=[
                step(("goto", None), ("accept", 1), ("accept", 2)),
                step(("accept", 3), ("complete", 1), ("turnin", 1)),
                step(("turnin", 2), ("turnin", 3), ("accept", 4)),
                step(("accept", 5), ("accept", 6), ("accept", 7)),
                step(("turnin", 4), ("turnin", 99)),  # a hand-in of a quest that was never accepted here takes nothing out
            ]
        )
        self.assertEqual(rp.route_log_peak(route), 4)  # 2 held, 3 at the second step, only 4 at the third, and 4 + three accepts = four at the fourth
        self.assertEqual(rp.route_log_peak(types.SimpleNamespace(steps=[])), 0)


class LeftOutReportTest(unittest.TestCase):
    """The list of THE QUESTS (report_left_out): what tidy took out of the route, with the reason and the numbers. Nothing is dropped silently."""

    @staticmethod
    def record(quest, code="price", unplaced=False, ratio=0.8, name=None, level=2):
        return dict(
            quest=quest, name=name or f"Quest {quest}", level=level, picked_level=1, hub="Zephras Isle: Aetheen of the Gales", code=code,
            why=f"the reason of {quest}", trip=21.9, handin=0.0, work=40.0, rate=1.1, pace=1.4, ratio=ratio, unplaced=unplaced,
        )

    def lines(self, records, limit=12):
        out = rp.Out(quiet=True)
        rp.report_left_out(out, mock.Mock(), engine.Plan(stats={"left_out": records}), limit)
        return "\n".join(out.lines)

    def test_a_route_that_left_nothing_unfinished_says_so(self):
        self.assertIn("unfinished    none: the search left no quest unfinished", self.lines([]))

    def test_each_quest_is_named_with_its_level_where_it_was_picked_up_and_the_reason_and_the_causes_are_counted(self):
        records = [self.record(92463, "far", name="The Next One", ratio=0.2), self.record(92462, "price", name="Infestation Investigation", ratio=0.79)]
        text = " ".join(self.lines(records).split())
        self.assertIn("2 quests the search picked up on the way and did not finish are not in the route (1 near but not worth the trip, 1 objectives too far):", text)
        self.assertIn("92462 Infestation Investigation (level 2, picked up at level 1, Aetheen of the Gales): the reason of 92462", text)
        self.assertIn("92463 The Next One (level 2, picked up at level 1, Aetheen of the Gales): the reason of 92463", text)
        self.assertLess(text.index("92462"), text.index("92463"))  # the near ones first: they are the ones a setting would get back

    def test_the_causes_are_listed_most_frequent_first(self):
        text = " ".join(self.lines([self.record(1, "far"), self.record(2, "price"), self.record(3, "price"), self.record(4, "price")]).split())
        self.assertIn("(3 near but not worth the trip, 1 objectives too far)", text)
        text = " ".join(self.lines([self.record(1, "far"), self.record(2, "far"), self.record(3, "far"), self.record(4, "price")]).split())
        self.assertIn("(3 objectives too far, 1 near but not worth the trip)", text)

    def test_the_quests_with_an_objective_the_data_cannot_place_are_counted(self):
        text = " ".join(self.lines([self.record(1, unplaced=True), self.record(2), self.record(3, unplaced=True)]).split())
        self.assertIn("; 2 with an objective that has no position in the data:", text)
        self.assertNotIn("no position in the data", " ".join(self.lines([self.record(1)]).split()))

    def test_a_long_list_is_cut_and_says_where_the_rest_is(self):
        text = " ".join(self.lines([self.record(n) for n in range(1, 21)], limit=5).split())
        self.assertEqual(len(re.findall(r"\d+ Quest \d+ \(level 2", text)), 5)
        self.assertIn("... 15 more (all of them in plan.json, and as #skipquest lines in the guide)", text)


class GrainReportTest(unittest.TestCase):
    def lines(self, grains):
        out = rp.Out(quiet=True)
        rp.report_grains(out, grains)
        return "\n".join(out.lines)

    GRAINS = [
        dict(parts=2, finals=1204, seconds=40.2, total=80000.0),
        dict(parts=4, finals=9, seconds=95.5, total=84800.0),
        dict(parts=8, finals=0, seconds=200.0, total=None),
    ]

    def test_each_grain_is_listed_with_its_route_as_written_and_the_spread_is_said_in_hours_and_percent(self):
        text = self.lines(self.GRAINS)
        self.assertIn("22h13", text)  # 80,000 s
        self.assertIn("23h33", text)  # 84,800 s
        self.assertIn("1,204", text)
        self.assertIn("none", text)  # the grain that finished nothing
        self.assertIn("the grains disagree by 1h20, 6%: trust the best route no more than that", text)
        shortest = [line for line in text.splitlines() if "<- the shortest" in line]
        self.assertEqual(len(shortest), 1)
        self.assertIn("22h13", shortest[0])

    def test_a_spread_above_five_percent_is_a_warning_and_five_or_less_is_not(self):
        self.assertIn("WARNING", self.lines(self.GRAINS))  # 6%
        close = [dict(parts=2, finals=3, seconds=1.0, total=80000.0), dict(parts=4, finals=3, seconds=1.0, total=83200.0)]
        text = self.lines(close)
        self.assertIn("the grains disagree by 0h53, 4%", text)
        self.assertNotIn("WARNING", text)
        edge = [dict(parts=2, finals=3, seconds=1.0, total=80000.0), dict(parts=4, finals=3, seconds=1.0, total=84000.0)]
        self.assertNotIn("WARNING", self.lines(edge))  # exactly 5% is not above it

    def test_with_fewer_than_two_routes_there_is_nothing_to_compare(self):
        text = self.lines([dict(parts=2, finals=3, seconds=1.0, total=80000.0), dict(parts=4, finals=0, seconds=1.0, total=None)])
        self.assertIn("fewer than two grains finished a route", text)
        self.assertNotIn("disagree", text)
        self.assertIsNone(rp.spread_of([]))
        self.assertEqual(rp.spread_of([dict(total=100.0), dict(total=110.0)]), (10.0, 10.0))


class Fake:
    """An outcome as the install choice sees it."""

    def __init__(self, ok=True, level=6, total=1.0, wins=None, name="greedy"):
        self.evaluation = mock.Mock(lint_errors=[] if ok else ["error"], sim=mock.Mock(violations=[], level=level))
        self.plan = mock.Mock(complete=True, total=total)
        self.preset, self.monte = name, ({} if wins is None else {"wins": wins})


class ChoiceTest(unittest.TestCase):
    def test_a_route_must_pass_every_check_to_be_installed(self):
        self.assertTrue(rp.passes(Fake(), 6))
        self.assertFalse(rp.passes(Fake(ok=False), 6))
        self.assertFalse(rp.passes(Fake(level=5), 6))  # the full simulation stops short of the cap
        incomplete = Fake()
        incomplete.plan.complete = False
        self.assertFalse(rp.passes(incomplete, 6))
        error = Fake()
        error.evaluation.sim.violations = [mock.Mock(reason=mock.Mock(severity="error"))]
        self.assertFalse(rp.passes(error, 6))

    def test_without_a_monte_carlo_the_lowest_total_that_passes_wins(self):
        slow, fast, bad = Fake(total=3.0, name="slow"), Fake(total=2.0, name="fast"), Fake(ok=False, total=1.0, name="bad")
        self.assertIs(rp.choose([slow, bad, fast], [], 6), fast)
        self.assertIsNone(rp.choose([bad], [], 6))

    def test_with_a_monte_carlo_the_shortest_median_wins_whatever_the_totals_and_the_wins(self):
        def measured(name, median, p90, total, wins):
            o = Fake(total=total, wins=wins, name=name)
            o.monte.update(p50={6: median}, p90={6: p90})
            return o

        beam = measured("beam", 100.0, 130.0, 2.0, 0.01)
        lucky = measured("thorough alt 1", 110.0, 120.0, 3.0, 0.46)  # fastest in most runs, a slower typical time
        broken = measured("thorough alt 2", 50.0, 60.0, 1.0, 0.9)
        broken.evaluation.lint_errors = ["error"]  # fails its checks: never chosen, however fast
        self.assertIs(rp.choose([beam], [beam, lucky, broken], 6), beam)
        tie = measured("tie", 100.0, 125.0, 9.0, 0.0)
        self.assertIs(rp.choose([beam], [beam, tie], 6), tie)  # equal medians: the shorter 90th percentile
        same = measured("same", 100.0, 130.0, 1.5, 0.0)
        self.assertIs(rp.choose([beam], [beam, same], 6), same)  # then the lower planner total

    def test_a_run_that_never_gets_to_the_cap_counts_as_infinitely_slow(self):
        def runs(reached):  # results of a Monte Carlo: `reached` of the 10 runs got to level 6, at 100 + i seconds
            return [mock.Mock(levels={6: (100.0 + i, "c")} if i < reached else {}) for i in range(10)]

        steady = rp.monte_summary(runs(10), [6], 3, 10)
        fragile = rp.monte_summary(runs(6), [6], 7, 10)  # four runs never got there
        self.assertEqual(steady["reached"], {6: 1.0})
        self.assertEqual(fragile["reached"], {6: 0.6})
        self.assertEqual(fragile["p10"][6], 100.9)  # the lucky runs are still the quick ones
        self.assertEqual(fragile["p50"][6], 104.5)  # the median of all ten runs, the four that failed counted as the slowest
        self.assertEqual(fragile["p90"][6], float("inf"))
        broken = rp.monte_summary(runs(4), [6], 0, 10)
        self.assertEqual(broken["p50"][6], float("inf"))  # fails more than half the runs: no median at all
        a, b = Fake(total=2.0, name="steady"), Fake(total=1.0, name="fragile")
        a.monte, b.monte = steady, fragile
        self.assertEqual(steady["p50"][6], fragile["p50"][6])  # the same typical time...
        self.assertIs(rp.choose([b, a], [], 6), a)  # ...and the one that never fails has the shorter 90th percentile, whatever the totals
        c = Fake(total=0.5, name="broken")
        c.monte = broken
        self.assertIs(rp.choose([c, a], [], 6), a)  # never the route with no median, however low its total
        self.assertEqual(rp.hms(float("inf")), "never")

    def test_the_report_says_when_a_route_does_not_reach_the_cap_in_every_run(self):
        o = Fake(name="beam")
        o.monte = rp.monte_summary([mock.Mock(levels={6: (100.0, "c")}), mock.Mock(levels={})], [6], 1, 2)
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            rp.report_monte(rp.Out(), [o])
        text = out.getvalue()
        self.assertIn("REACHED THE CAP IN ONLY 50% OF RUNS", text)
        self.assertIn("never", text)  # the 90th percentile of the runs
        self.assertNotIn("shortest median to level 6", text)  # the median is infinite: no route is named for it

    def test_the_planner_of_an_outcome_and_the_command_line_that_made_it(self):
        planners = {"thorough": "T", "beam": "B"}
        self.assertEqual(rp.planner_of(planners, Fake(name="thorough alt 2")), "T")
        self.assertEqual(rp.planner_of(planners, Fake(name="beam")), "B")
        self.assertEqual(rp.command_of(["troll", "--root", "C:/x", "--preset", "all", "--pack", "C:/y", "--install"]), "troll --preset all --install")


class InstallTest(RouteCase):
    def setUp(self):
        super().setUp()
        patch = mock.patch.object(route_install, "find_stylua", lambda root: None)  # never format files of a temporary project
        patch.start()
        self.addCleanup(patch.stop)

    def install(self, *extra):
        return self.run_main("troll", "--preset", "greedy", "--cap", "6", "--no-write", "--install", "--steps", "0", "--decisions", "0", *extra)

    def chapters(self):
        folder = self.root / "Guides" / "Chapters"
        return sorted(folder.glob("test-guide-*.lua")) if folder.exists() else []

    def test_the_best_route_that_passes_its_checks_becomes_the_guides_chapters(self):
        code, text = self.install("--force")  # the fixture guide covers more levels than a route to 6
        self.assertEqual(code, 0, text)
        self.assertIn("INSTALLED", text)
        chapters = self.chapters()
        self.assertTrue(chapters)
        guide = (self.root / "Guides" / "Test.lua").read_text(encoding="utf-8")
        self.assertIn(f"#include {chapters[0].stem}", guide)
        self.assertIn("levels = { 1, 6 }", guide)
        self.assertIn("-- PLANNED: the greedy route for", chapters[0].read_text(encoding="utf-8"))
        self.assertIn("test-guide", guidefile.load_project(self.root).guides)  # the project still loads

    def test_nothing_is_installed_without_asking(self):
        self.run_main("troll", "--preset", "greedy", "--cap", "6", "--no-write", "--steps", "0", "--decisions", "0")
        self.assertEqual(self.chapters(), [])

    def test_a_route_that_would_shorten_the_guide_is_refused_unless_forced(self):
        code, text = self.install()
        self.assertEqual(code, 2, text)
        self.assertIn("would shorten it", text)
        self.assertEqual(self.chapters(), [])

    def test_install_needs_a_guide_the_checks_and_the_guides_own_mode(self):
        with self.assertRaises(SystemExit):
            self.run_main("--install")
        with self.assertRaises(SystemExit):
            self.run_main("troll", "--install", "--no-check")
        with self.assertRaises(SystemExit):
            self.run_main("troll", "--install", "--mode", "hardcore")

    def test_the_guide_stays_as_it_was_when_the_install_is_refused(self):
        before = (self.root / "Guides" / "Test.lua").read_text(encoding="utf-8")
        text = (self.root / "Guides" / "Test.lua").read_text(encoding="utf-8").replace("text = [[", "text = [==[").replace("]],", "]==],")
        (self.root / "Guides" / "Test.lua").write_text(text, encoding="utf-8")
        code, out = self.install("--force")
        self.assertEqual(code, 1, out)
        self.assertIn("not installed", out)
        self.assertEqual((self.root / "Guides" / "Test.lua").read_text(encoding="utf-8"), text)
        self.assertNotEqual(before, text)
        self.assertEqual(self.chapters(), [])

    def test_the_quests_a_guides_chapters_leave_out_on_purpose_are_left_out_with_their_reason(self):
        (self.root / "tools").mkdir(exist_ok=True)
        manifest = {"guides": [{"guide": "test-guide", "chapters": [
            {"id": "a", "args": ["--exclude", 5, "--exclude-reason", "no known source", "--exclude", "6", "--chain", "1,2"]},
            {"id": "b", "args": ["--exclude", 7]}]}]}
        (self.root / "tools" / "drafts.json").write_text(json.dumps(manifest), encoding="utf-8")
        found = rp.manifest_excludes(self.root, "test-guide")
        self.assertEqual(found, {5: "no known source", 6: "no known source", 7: "HARDCORE: not routed"})
        self.assertEqual(rp.manifest_chains(self.root, "test-guide"), [[1, 2]])
        self.assertEqual(rp.manifest_excludes(self.root, "nobody"), {})


if __name__ == "__main__":
    unittest.main()
