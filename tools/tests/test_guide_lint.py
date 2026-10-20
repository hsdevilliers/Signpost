import contextlib
import io
import unittest

import guide_lint
import guide_travel
from signpost_tools import datapack, guidefile
from signpost_tools.guidefile import OTHER, Gate, Variant
from tests.guide_fixtures import (
    BORDERS_LUA,
    FIRSTAID_LUA,
    GUIDE_FIRST_LINE,
    HUNTER_LUA,
    MAPS,
    NPCS,
    QUESTS,
    SKINNING_LUA,
    TEXT_FIRST_LINE,
    TRAVEL,
    TempProject,
    chapter_lua,
    guide_lua,
    track_lua,
    write_pack,
)


def guide_line(n):
    return GUIDE_FIRST_LINE + n - 1


def text_line(n):
    return TEXT_FIRST_LINE + n - 1


class LintCase(TempProject):
    def lint(self, files, pack=False, tables=None, classes=None, guides=None):
        self.files(files)
        pack_dir = write_pack(self.pack_dir, tables, classes) if pack else None
        report, project, _ = guide_lint.lint(self.root, pack_dir, guides)
        return report

    def found(self, report, severity="error"):
        """(code, path, line) of every problem of that severity."""
        return sorted((key[1], key[3], key[4]) for key in report.entries if key[0] == severity)

    def codes(self, report, severity="error"):
        return report.codes(severity)


class ParserTest(TempProject):
    def load(self, files):
        self.files(files)
        return guidefile.load_project(self.root)

    def test_steps_lines_text_gates_and_sticky(self):
        guide = (
            "#professions skinning,firstaid\n"
            "step\n"
            "  .goto 10,42.1,68.7\n"
            "  .accept 101 >> Accept it -- a comment\n"
            "  .accept 102 .class HUNTER\n"
            "#include west-1-5\n"
        )
        chapter = "#chapter 1-5 West\n-- a comment line\nstep\n  .turnin 101\n  .race Troll\n  .sticky .skill skinning 50\n"
        project = self.load({"Guides/Test.lua": guide_lua(guide), "Guides/Chapters/west-1-5.lua": chapter_lua("west-1-5", chapter)})
        self.assertEqual([p for s in project.sources() for p in s.problems] + project.problems, [])
        test = project.guides["test-guide"]
        self.assertEqual(test.source.first_line, GUIDE_FIRST_LINE)
        self.assertEqual(test.professions, ["skinning", "firstaid"])
        step = test.source.steps()[0]
        self.assertEqual((step.id, step.line, step.end_line), ("test-guide:1", 2, 5))
        goto, accept, gated = step.directives
        self.assertEqual(goto.args["coord"], guidefile.Coord(10, 42.1, 68.7))
        self.assertEqual((accept.args, accept.text), ({"quest": 101}, "Accept it"))
        self.assertEqual(gated.gates, (Gate("class", ("HUNTER",), 5),))
        west = project.chapters["west-1-5"].steps()[0]
        self.assertEqual(west.id, "west-1-5:1")
        self.assertEqual(west.gates, [Gate("race", ("Troll",), 5)])
        sticky = west.directives[1]
        self.assertEqual((sticky.name, sticky.inner.name, sticky.inner.args), ("sticky", "skill", {"key": "skinning", "level": 50}))
        route = guidefile.build_route(project, test, guidefile.variants(project, test)[0])
        self.assertEqual([rs.id for rs in route.steps], ["test-guide:1", "west-1-5:1"])
        self.assertEqual([(c.name, c.levels, c.first) for c in route.chapters], [("Test Guide", (1, 20), 0), ("West", (1, 5), 1)])
        self.assertEqual([d.name for d in route.steps[1].sticky], ["sticky"])

    def test_language_errors_have_file_lines(self):
        chapter = (
            "#chapter 1-5 West\n"  # 1
            ".goto 10,1,1\n"  # 2 outside a step
            "step\n"  # 3
            "  .bogus 1\n"  # 4 unknown directive
            "  .goto 10,101,5\n"  # 5 out of range
            "  .skill cooking,75\n"  # 6 comma instead of a space
            "  .todo no quotes\n"  # 7 taken, with a warning
            "  .accept 101\n"  # 8
            "#professions skinning\n"  # 9 guide only (it does not end the step)
            "#skipquest 5\n"  # 10 no reason
            "#frobnicate\n"  # 11 unknown header
            "step @hub orgrimmar\n"  # 12 anchors are for tracks
            "  .accept 104\n"  # 13
            "what is this\n"  # 14
            "step\n"  # 15
            "  .class HUNTER ROGUE\n"  # 16 a gate list has no spaces: the step is dropped
            "  .accept 103\n"  # 17
            "  .home now\n"  # 18 takes no arguments
            "  .reward 101\n"  # 19 needs two numbers
        )
        project = self.load({"Guides/Chapters/west-1-5.lua": chapter_lua("west-1-5", chapter)})
        problems = project.chapters["west-1-5"].problems
        errors = sorted(p.line for p in problems if p.severity == "error")
        self.assertEqual(errors, [text_line(n) for n in (2, 4, 5, 6, 9, 10, 11, 12, 14, 16, 18, 19)])
        self.assertEqual([(p.code, p.line) for p in problems if p.severity == "warning"], [("todo-quotes", text_line(7))])
        steps = project.chapters["west-1-5"].steps()
        found = [(s.invalid, [d.name for d in s.directives]) for s in steps]
        self.assertEqual(found, [(False, ["todo", "accept"]), (False, ["accept"]), (True, ["accept"])])

    def test_lines_as_the_in_game_parser_reads_them(self):
        text = (
            "step\n  .goto 10,1,1\n  .accept 101 >> Accept it .class HUNTER\n"  # 1-3: a gate after the >> text
            "#skipquest 9 >> not this one\n  .turnin 101\n"  # 4-5: only #chapter and #include end a step
            "step\n  .note see the .class trainer here\n  .accept 102 >>\n"  # 6-8: a gate mid-line; nothing after >>
            "step\n  .hub town\n  .hub city\n  .goto 10,1,1\n"  # 9-12: a second, different hub
            "step\n  .sticky .note hello\n  .sticky .hub town\n  .goto 10,1,1\n  .optional 5 >> maybe\n"  # 13-17
            "step\n  .hub town\n  .optional 5\n"  # 18-20: modifiers alone: an empty step
            "#chapter 1-5 West\n  .accept 103\n"  # 21-22: #chapter ends the step
            "#chapter 6 #dungeon\n"  # 23: no name
            "#professions skinning\n#professions firstaid\n"  # 24-25: the first counts
        )
        self.files({"Guides/Test.lua": guide_lua(text)})
        project = guidefile.load_project(self.root)
        source = project.guides["test-guide"].source
        errors = [p for p in source.problems if p.severity == "error"]
        found = sorted((p.line - GUIDE_FIRST_LINE + 1, p.message.split(" (")[0]) for p in errors)
        self.assertEqual(
            found,
            [
                (7, "misplaced or malformed gate .class"),
                (8, "nothing after >>"),
                (11, "a step has one .hub"),
                (14, ".sticky needs a directive that can be satisfied, not .note"),
                (15, ".hub cannot be sticky"),
                (17, ">> text is not allowed on .optional"),
                (18, "step has no directives"),
                (22, "a directive line outside a step"),
                (23, "expected #chapter <N or N-M> <name> [#dungeon]"),
                (25, "duplicate #professions"),
            ],
        )
        first = source.steps()[0]
        self.assertEqual([d.name for d in first.directives], ["goto", "accept", "turnin"])
        self.assertEqual((first.directives[1].text, first.directives[1].gates), ("Accept it", (Gate("class", ("HUNTER",), 3),)))
        self.assertEqual(project.guides["test-guide"].professions, ["skinning"])

    def test_gates_compare_case_insensitively_and_guide_name_fallback(self):
        text = "#guide Named By Header\nstep\n  .goto 10,1,1\n  .class hunter\n  .race TROLL\n"
        guide_file = guide_lua(text).replace('\tname = "Test Guide",\n', "")
        self.files({"Guides/Test.lua": guide_file})
        project = guidefile.load_project(self.root)
        guide = project.guides["test-guide"]
        route = guidefile.build_route(project, guide, guidefile.variants(project, guide)[0])
        self.assertEqual([rs.id for rs in route.steps], ["test-guide:1"])
        self.assertEqual(route.chapters[0].name, "Named By Header")

    def test_empty_track_and_dungeon_gap_chapter(self):
        guide = (
            "#chapter 10-12 Zone\nstep\n  .goto 10,1,1\n"
            "#chapter 13 Cave #dungeon\nstep\n  .goto 10,2,2\n"
        )
        track = "#track skinning\nstep @level 13\n  .trainprof skinning\n"
        self.files(
            {
                "Guides/Test.lua": guide_lua(guide),
                "Guides/Professions/skinning.lua": track_lua("skinning", track),
                "Guides/Professions/firstaid.lua": track_lua("firstaid", ""),
            }
        )
        project = guidefile.load_project(self.root)
        self.assertEqual([p.code for p in project.tracks["firstaid"].problems], ["track-header"])
        guide = project.guides["test-guide"]
        route = guidefile.build_route(project, guide, guidefile.variants(project, guide)[0])
        merged, _ = guidefile.merge_tracks(project, route, ["skinning"])
        self.assertEqual([rs.id for rs in merged.steps], ["test-guide:1", "track:skinning:1", "test-guide:2"])
        # between a zone chapter and a dungeon chapter the track step stays in the zone chapter
        self.assertEqual(merged.chapters[merged.steps[1].chapter].name, "Zone")

    def test_track_files(self):
        project = self.load(
            {
                "Guides/Professions/skinning.lua": track_lua(
                    "skinning",
                    "#track fishing\nstep\n  .trainprof skinning\n"  # 1-3: the wrong key; no anchor
                    "step @level x\n  .trainprof skinning\n"  # 4-5: not a number
                    "step @hub a b\n  .trainprof skinning\n",  # 6-7: two anchors
                ),
                "Guides/Professions/firstaid.lua": track_lua("firstaid", "step @hub town\n  .trainprof firstaid\n"),
            }
        )
        skinning = project.tracks["skinning"]
        self.assertEqual(
            sorted((p.code, p.line) for p in skinning.problems if p.severity == "error"),
            [("parse", text_line(2)), ("parse", text_line(4)), ("parse", text_line(6)), ("track-header", text_line(1))],
        )
        self.assertEqual(skinning.steps()[0].id, "track:skinning:1")
        self.assertTrue(all(step.invalid for step in skinning.steps()))
        firstaid = project.tracks["firstaid"]
        self.assertEqual([p.code for p in firstaid.problems], ["track-header"])  # no #track line

    def test_register_tables_must_be_literals(self):
        project = self.load(
            {
                "Guides/Bad.lua": 'local ADDON_NAME, ns = ...\nlocal T = "x"\nns.Guides:Register({ id = T, text = [[step]] })\n',
                "Guides/Chapters/bad.lua": 'local ADDON_NAME, ns = ...\nns.Chapters:Register("Bad_Id", [[step\n  .level 2\n]])\n',
            }
        )
        self.assertEqual(
            sorted((p.code, p.path, p.line) for p in project.problems),
            [("file-name", "Guides/Chapters/bad.lua", 2), ("register", "Guides/Bad.lua", 3), ("register", "Guides/Chapters/bad.lua", 2)],
        )

    def test_includes(self):
        project = self.load(
            {
                "Guides/Test.lua": guide_lua("#include a\n#include missing\n#include a\n"),
                "Guides/Chapters/a.lua": chapter_lua("a", "#include b\n"),
                "Guides/Chapters/b.lua": chapter_lua("b", "#include a\n"),
            }
        )
        expansion = guidefile.expand(project, project.guides["test-guide"])
        messages = sorted(p.message.split(":")[0] for p in expansion.problems)
        self.assertEqual(messages, ["#include a a second time", "#include cycle", "#include missing"])
        self.assertEqual(expansion.included, ["a", "b"])

    def test_gates(self):
        variant = Variant("Horde", "Troll", "HUNTER", frozenset({"skinning"}))
        cases = [
            (("class", ("HUNTER",)), True),
            (("class", ("ROGUE", "HUNTER")), True),
            (("class", ("!HUNTER",)), False),
            (("class", ("!ROGUE", "!MAGE")), True),
            (("class", ("HUNTER", "!HUNTER")), False),
            (("class", ("ROGUE", "!MAGE")), False),
            (("race", ("Troll",)), True),
            (("faction", ("Alliance",)), False),
            (("prof", ("skinning",)), True),
            (("prof", ("!skinning",)), False),
            (("prof", ("mining",)), False),
            (("hc", ()), False),
        ]
        for (kind, items), expected in cases:
            self.assertEqual(Gate(kind, items, 1).passes(variant), expected, (kind, items))

    def test_gating_drops_lines_and_steps(self):
        text = (
            "step\n  .goto 10,1,1\n  .accept 101 .race Orc\n"  # the line goes, the step stays
            "step\n  .accept 102 .race Orc\n"  # every line gated away: the step goes
            "step\n  .race !Troll\n  .accept 103\n"  # a gate line drops the whole step
            "step\n  .hc\n  .accept 104\n"  # .hc is always false
        )
        project = self.load({"Guides/Test.lua": guide_lua(text)})
        guide = project.guides["test-guide"]
        route = guidefile.build_route(project, guide, guidefile.variants(project, guide)[0])
        self.assertEqual([(rs.id, [d.name for d in rs.directives]) for rs in route.steps], [("test-guide:1", ["goto"])])

    def test_variants(self):
        text = "step\n  .goto 10,1,1\n  .race Troll\nstep\n  .goto 10,1,1\n  .race !Orc\nstep\n  .goto 10,2,2\n  .prof fishing\n"
        project = self.load({"Guides/Test.lua": guide_lua("#professions skinning\n" + text, faction="*", races=("*",))})
        found = guidefile.variants(project, project.guides["test-guide"])
        self.assertEqual(sorted({v.faction for v in found}), ["Alliance", "Horde"])
        self.assertEqual(sorted({v.race for v in found}), sorted(["Orc", "Troll", OTHER]))
        self.assertEqual({v.cls for v in found}, {"HUNTER"})
        self.assertEqual(sorted({tuple(sorted(v.plan)) for v in found}), [(), ("fishing", "skinning"), ("skinning",)])

    def test_track_merging(self):
        guide = (
            "#chapter 1-5 West\n"
            "step\n  .goto 10,50,50\n  .hub westhold\n"
            "step\n  .goto 10,60,60\n"
            "#chapter 6-10 East\n"
            "step\n  .goto 20,50,50\n"
            "step\n  .goto 20,60,60\n  .hub towne\n"
        )
        skinning = (
            "#track skinning\n"
            "step @hub westhold\n  .trainprof skinning\n"
            "step @level 6\n  .sticky .skill skinning 50\n"
            "step @zone 20\n  .goto 20,55,55\n"
            "step @hub nowhere\n  .trainprof skinning\n"
            "step @zone 100\n  .goto 20,56,56\n"
        )
        project = self.load(
            {
                "Guides/Test.lua": guide_lua(guide),
                "Guides/Professions/skinning.lua": track_lua("skinning", skinning),
                "Guides/Professions/firstaid.lua": track_lua("firstaid", "#track firstaid\nstep @hub westhold\n  .trainprof firstaid\n"),
            }
        )
        guide = project.guides["test-guide"]
        route = guidefile.build_route(project, guide, guidefile.variants(project, guide)[0])
        merged, unmatched = guidefile.merge_tracks(project, route, ["skinning", "firstaid"])
        self.assertEqual(
            [rs.id for rs in merged.steps],
            [
                "test-guide:1",
                "track:skinning:1",
                "track:firstaid:1",
                "test-guide:2",
                "track:skinning:2",
                "track:skinning:3",
                "test-guide:3",
                "test-guide:4",
            ],
        )
        self.assertEqual([merged.chapters[rs.chapter].name for rs in merged.steps[:5]], ["West"] * 4 + ["East"])
        self.assertEqual([(key, step.id) for key, step in unmatched], [("skinning", "track:skinning:4"), ("skinning", "track:skinning:5")])
        # with the map tree, @zone 100 (the continent) matches a route step in a zone below it
        world = guide_travel.World(guide_travel.Pack(guide_travel.Path("."), {}, {"maps": MAPS}), [], "Horde")
        merged, unmatched = guidefile.merge_tracks(project, route, ["skinning"], world.within)
        self.assertEqual([step.id for _, step in unmatched], ["track:skinning:4"])
        ids = [rs.id for rs in merged.steps]
        self.assertEqual(ids.index("track:skinning:5"), ids.index("test-guide:3") - 1)


class LintTest(LintCase):
    def run_main(self, *args):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = guide_lint.main(["--root", str(self.root), *args])
        return code, out.getvalue()

    def test_no_guides_passes_strict(self):
        self.files({"Guides/Travel/Borders.lua": BORDERS_LUA})
        code, out = self.run_main("--strict", "--no-pack")
        self.assertEqual(code, 0)
        self.assertIn("0 guide(s), 0 chapter(s), 0 track(s): 0 error(s)", out)

    def test_strict_exits_1_on_errors_only(self):
        self.files({"Guides/Test.lua": guide_lua("step\n  .goto 10,50,50\n  .accept 101\n")})
        self.assertEqual(self.run_main("--strict", "--no-pack")[0], 1)
        code, out = self.run_main("--no-pack")
        self.assertEqual(code, 0)
        self.assertIn("error [never-turned-in] quest 101 is accepted but never turned in (guide test-guide)", out)
        self.files({"Guides/Test.lua": guide_lua("step\n  .goto 10,50,50\n  .accept 101\nstep\n  .goto 10,50,50\n  .turnin 101\n")})
        self.assertEqual(self.run_main("--strict", "--no-pack")[0], 0)

    def test_quest_flow(self):
        text = (
            "step\n  .goto 10,50,50\n  .accept 101\n  .accept 102\n  .turnin 103\n  .complete 104\n"
            "step\n  .goto 10,51,51\n  .accept 101\n  .accept 103\n  .turnin 101\n"
            "step\n  .goto 10,52,52\n  .turnin 101\n  .turnin 105\n"
        )
        report = self.lint({"Guides/Test.lua": guide_lua(text)})
        self.assertEqual(
            self.found(report),
            [
                ("complete-outside", "Guides/Test.lua", guide_line(6)),
                ("duplicate-accept", "Guides/Test.lua", guide_line(9)),
                ("duplicate-turnin", "Guides/Test.lua", guide_line(14)),
                ("never-accepted", "Guides/Test.lua", guide_line(15)),
                ("never-turned-in", "Guides/Test.lua", guide_line(4)),
                ("turnin-before-accept", "Guides/Test.lua", guide_line(5)),
            ],
        )

    def test_a_quest_above_the_walk_needs_a_level_step(self):
        text = "#chapter 1-10 West\nstep\n  .goto 10,50,50\n  .accept 103\nstep\n  .goto 10,50,50\n  .accept 102\n  .accept 101\n"
        report = self.lint({"Guides/Test.lua": guide_lua(text)}, pack=True)
        errors = sorted((key[4], "Bit Early" in key[2] or "Too Early" in key[2]) for key in report.entries if key[0] == "error" and key[1] == "quest-level")
        self.assertEqual(errors, [(guide_line(4), True), (guide_line(7), True)])
        gated = "#chapter 1-10 West\nstep\n  .goto 10,50,50\n  .level 9\n  .accept 103\nstep\n  .goto 10,50,50\n  .turnin 103\n"
        report = self.lint({"Guides/Test.lua": guide_lua(gated)}, pack=True)
        self.assertEqual([key for key in report.entries if key[1].startswith("quest-")], [])  # the guide asks for level 9 itself

    def test_a_quest_the_walk_has_the_level_for_still_wants_a_level_line(self):
        # the walk's estimate is not a promise: without a `.level` the guide does not guarantee the level, and says so
        quests = {**QUESTS, 111: {"n": "Needs Two", "r": 2, "l": 2, "s": {"npc": [1001]}, "e": {"npc": [1001]}}}
        text = (
            "#chapter 1-10 West\nstep\n  .goto 10,50,50\n  .level 5\n  .accept 101\nstep\n  .goto 10,50,50\n  .turnin 101\n"
            "step\n  .goto 10,50,50\n  .accept 111\nstep\n  .goto 10,50,50\n  .turnin 111\n"
        )
        report = self.lint({"Guides/Test.lua": guide_lua(text)}, pack=True, tables={"maps": MAPS, "quests": quests, "npcs": NPCS, "travel": TRAVEL})
        self.assertEqual(self.codes(report), [])  # `.level 5` asked for earlier covers a level 2 quest
        text = text.replace("  .level 5\n", "")
        report = self.lint({"Guides/Test.lua": guide_lua(text)}, pack=True, tables={"maps": MAPS, "quests": quests, "npcs": NPCS, "travel": TRAVEL})
        self.assertEqual(self.codes(report), ["quest-level"])  # the walk is level 1 there: it cannot have it

    def test_prerequisites_chains_and_other_races_are_checked(self):
        quests = {
            **QUESTS,
            120: {"n": "Lead In", "r": 1, "next": 121, "side": "Horde", "s": {"npc": [1001]}, "e": {"npc": [1001]}},
            121: {"n": "Handed Over", "r": 1, "side": "Horde", "s": {"npc": [1001]}, "e": {"npc": [1001]}},
            122: {"n": "Second Part", "r": 1, "preSingle": [120], "side": "Horde", "s": {"npc": [1001]}, "e": {"npc": [1001]}},
            123: {"n": "Orc Only", "r": 1, "races": 2, "side": "Horde", "s": {"npc": [1001]}, "e": {"npc": [1001]}},
        }
        tables = {"maps": MAPS, "quests": quests, "npcs": NPCS, "travel": TRAVEL}
        text = (
            "step\n  .goto 10,50,50\n  .accept 122\n  .accept 120\n  .accept 121\n  .accept 123\n"
            "step\n  .goto 10,50,50\n  .turnin 120\n  .turnin 121\n  .turnin 122\n  .turnin 123\n"
        )
        report = self.lint({"Guides/Test.lua": guide_lua(text, races=("Troll",))}, pack=True, tables=tables)
        found = sorted((key[1], key[4]) for key in report.entries if key[0] == "error")
        self.assertEqual(
            found,
            [("quest-chain", guide_line(5)), ("quest-prerequisite", guide_line(3)), ("quest-race", guide_line(6))],
        )
        ordered = (
            "step\n  .goto 10,50,50\n  .accept 120\nstep\n  .goto 10,50,50\n  .turnin 120\n  .accept 121\n  .accept 122\n"
            "step\n  .goto 10,50,50\n  .turnin 121\n  .turnin 122\n"
        )
        report = self.lint({"Guides/Test.lua": guide_lua(ordered, races=("Troll",))}, pack=True, tables=tables)
        self.assertEqual(self.codes(report), [])

    def test_chapter_order(self):
        text = "#chapter 5-10 B\nstep\n  .goto 10,50,50\n#chapter 1-5 A\nstep\n  .goto 10,50,50\n#chapter 30 C\nstep\n  .goto 10,1,1\n"
        report = self.lint({"Guides/Test.lua": guide_lua(text)})
        self.assertEqual(self.found(report), [("chapter-order", "Guides/Test.lua", guide_line(4))])
        self.assertEqual(self.found(report, "warning"), [("chapter-range", "Guides/Test.lua", guide_line(7))])

    def test_todo_steps_are_listed_and_soften_unknown_ids(self):
        chapter = '#chapter 1-5 West\nstep\n  .goto 10,50,50\n  .todo "Somebody: position not known yet"\n  .accept 999\n  .turnin 999\n'
        report = self.lint({"Guides/Test.lua": guide_lua("#include west\n"), "Guides/Chapters/west.lua": chapter_lua("west", chapter)}, pack=True)
        self.assertEqual(list(report.todos.values()), ["Somebody: position not known yet"])
        self.assertEqual(self.codes(report), [])
        self.assertEqual(self.codes(report, "warning"), ["unknown-id", "unknown-id"])

    def test_unknown_ids_need_the_pack_table(self):
        text = (
            "step\n  .goto 10,50,50\n  .accept 999\n  .turnin 999\n"  # quest 999 is not in the pack
            "step\n  .goto 999,1,1\n"  # nor is map 999
            "step\n  .goto 10,1,1\n  .buy 5,1\n"  # the pack has no items: not checked
            "step\n  .goto 10,1,1\n  .fp 10,Nowhere\n"
            "step\n  .goto 10,1,1\n  .fp 10,Allyport\n"
        )
        report = self.lint({"Guides/Test.lua": guide_lua(text)}, pack=True)
        unknown = sorted(key[4] for key in report.entries if key[1] == "unknown-id")
        self.assertEqual(unknown, [guide_line(n) for n in (3, 4, 6, 12, 15)])
        self.assertIn("not available to Horde", next(key[2] for key in report.entries if key[4] == guide_line(15)))
        no_pack = self.lint({"Guides/Test.lua": guide_lua(text)})
        self.assertNotIn("unknown-id", self.codes(no_pack))

    def test_item_ids_and_skip_ids(self):
        tables = {"maps": MAPS, "quests": QUESTS, "npcs": NPCS, "travel": TRAVEL, "items": {5: {"n": "Known Item"}}}
        self.files({"Guides/Test.lua": guide_lua("step\n  .goto 10,1,1\n  .buy 5,1\n  .collect 6,2\n")})
        pack_dir = write_pack(self.pack_dir, tables)
        report, _, _ = guide_lint.lint(self.root, pack_dir)
        self.assertEqual(self.found(report), [("unknown-id", "Guides/Test.lua", guide_line(4))])
        report, _, _ = guide_lint.lint(self.root, pack_dir, skip=("item",))
        self.assertEqual(self.codes(report), [])
        self.assertTrue(any("--skip-ids: item" in note for note in report.notes))

    def test_uncovered_transitions(self):
        report = self.lint({"Guides/Test.lua": guide_lua("step\n  .goto 10,50,50\nstep\n  .goto 20,50,50\n")})
        self.assertEqual(self.found(report), [("uncovered-transition", "Guides/Test.lua", guide_line(3))])
        travel = "step\n  .goto 10,50,50\nstep\n  .path 10,95,50 ; 20,5,50\n  .zone 20\nstep\n  .goto 20,50,50\n"
        self.assertEqual(self.codes(self.lint({"Guides/Test.lua": guide_lua(travel)})), [])

    def test_fly_needs_an_earlier_fp(self):
        text = "step\n  .goto 10,50,50\n  .fly Towne\nstep\n  .goto 30,50,50\n  .fp 30,Towne\n"
        report = self.lint({"Guides/Test.lua": guide_lua(text)})
        self.assertEqual(self.codes(report), ["fly-without-fp"])

    def test_class_directives_need_a_class_gate(self):
        chapter = (
            "#chapter 1-5 West\n"
            "step\n  .goto 10,1,1\n  .tame 3100\n"  # 3, 4: no gate
            "step\n  .class HUNTER\n  .tame 3100\n"
            "step\n  .goto 10,1,1\n  .tame 3100 .class HUNTER\n"
            "step\n  .class HUNTER,ROGUE\n  .tame 3100\n"  # 12, 13: a rogue cannot tame
        )
        files = {
            "Classes/HUNTER.lua": HUNTER_LUA,
            "Guides/Test.lua": guide_lua("#skipquest 6061 >> test\n#skipquest 6062 >> test\nstep\n  .goto 10,1,1\n  .tame 3100\n#include west\n"),
            "Guides/Any.lua": guide_lua("step\n  .goto 10,1,1\n  .tame 3100\n", gid="any-guide", classes=("*",)),
            "Guides/Chapters/west.lua": chapter_lua("west", chapter),
        }
        report = self.lint(files)
        found = [(path, line) for code, path, line in self.found(report) if code == "class-directive"]
        self.assertEqual(
            found,
            [("Guides/Any.lua", guide_line(3)), ("Guides/Chapters/west.lua", text_line(4)), ("Guides/Chapters/west.lua", text_line(13))],
        )

    def test_class_quest_coverage(self):
        routed = "#chapter 1-12 West\nstep\n  .goto 10,1,1\n  .accept 6061\nstep\n  .goto 10,1,1\n  .turnin 6061\n"
        files = {"Classes/HUNTER.lua": HUNTER_LUA, "Guides/Test.lua": guide_lua(routed + "#skipquest 6062 >> not on this route\n")}
        report = self.lint(files)
        self.assertEqual(self.codes(report), [])
        self.assertTrue(any("above its highest chapter level" in note for note in report.notes))
        files["Guides/Test.lua"] = guide_lua(routed)
        report = self.lint(files)
        self.assertEqual(self.found(report), [("class-quest", "Guides/Test.lua", 3)])
        self.assertIn("quest 6062", next(key[2] for key in report.entries if key[1] == "class-quest"))
        # the pack's class chains count too
        classes = {"HUNTER": {"quests": [{"id": "p", "n": "Pack", "l": 5, "quests": [6063]}]}}
        routed = routed.replace("  .accept 6061", "  .level 10\n  .accept 6061")  # the pack knows 6061 needs level 10
        files["Guides/Test.lua"] = guide_lua(routed + "#skipquest 6062 >> x\n")
        report = self.lint(files, pack=True, classes=classes)
        self.assertEqual(self.codes(report), ["class-quest"])

    def test_class_quest_coverage_ignores_the_case_of_the_class(self):
        routed = "#chapter 1-12 West\nstep\n  .goto 10,1,1\n  .accept 6061\nstep\n  .goto 10,1,1\n  .turnin 6061\n"
        files = {"Classes/HUNTER.lua": HUNTER_LUA, "Guides/Test.lua": guide_lua(routed, classes=("hunter",))}
        self.assertEqual(self.codes(self.lint(files)), ["class-quest"])  # 6062 is neither routed nor skipped

    def test_an_unreadable_data_pack_is_an_error(self):
        files = {"Guides/Test.lua": guide_lua("step\n  .goto 10,1,1\n")}
        self.assertEqual(self.codes(self.lint(files, pack=True)), [])
        (self.pack_dir / datapack.TABLE_FILES["quests"]).write_text("garbage", encoding="utf-8")
        report, _, pack = guide_lint.lint(self.root, self.pack_dir)
        self.assertTrue(pack.problems)
        self.assertIn("pack-load", report.codes("error"))
        report, _, _ = guide_lint.lint(self.root, None, why_no_pack="--no-pack")
        self.assertNotIn("pack-load", report.codes("error"))

    def test_an_unknown_guide_id_is_an_error(self):
        files = {"Guides/Test.lua": guide_lua("step\n  .goto 10,1,1\n")}
        self.assertEqual(self.codes(self.lint(files, guides=["typo"])), ["unknown-guide"])
        self.assertEqual(self.codes(self.lint(files, guides=["test-guide"])), [])

    def test_a_chain_for_other_races_does_not_apply(self):
        druid = (
            "local ADDON_NAME, ns = ...\n"
            'ns.Classes:Register("DRUID", { classQuests = {\n'
            '  { id = "a", name = "Tauren Chain", level = 10, quests = { 6061 }, races = { "Tauren" } },\n'
            '  { id = "b", name = "Any Chain", level = 10, quests = { 6062 } },\n'
            "} })\n"
        )
        routed = "#chapter 1-12 West\nstep\n  .goto 10,1,1\n  .accept 6062\nstep\n  .goto 10,1,1\n  .turnin 6062\n"
        for race, expected in (("Tauren", ["class-quest"]), ("Skyborne", [])):
            files = {"Classes/DRUID.lua": druid, "Guides/Test.lua": guide_lua(routed, races=(race,), classes=("DRUID",))}
            self.assertEqual(self.codes(self.lint(files)), expected, race)

    def test_a_pending_chain_must_be_marked_by_a_todo(self):
        druid = (
            "local ADDON_NAME, ns = ...\n"
            'ns.Classes:Register("DRUID", { classQuests = {\n'
            '  { id = "cat", name = "Cat Form", level = 20, quests = {}, pending = true },\n'
            "} })\n"
        )
        plain = "#chapter 1-20 West\nstep\n  .goto 10,1,1\n"
        files = {"Classes/DRUID.lua": druid, "Guides/Test.lua": guide_lua(plain, classes=("DRUID",), levels=(1, 20))}
        report = self.lint(files)
        self.assertEqual(self.codes(report), ["class-quest-unmarked"])  # a Forever chain with no IDs and no marker is lost
        marked = plain + 'step\n  .todo "Cat Form (level 20): new in Forever; IDs pending"\n'
        files["Guides/Test.lua"] = guide_lua(marked, classes=("DRUID",), levels=(1, 20))
        report = self.lint(files)
        self.assertEqual(self.codes(report), [])
        self.assertEqual(self.codes(report, "warning"), ["class-quest-pending"])
        # above the guide's highest chapter level it is not required yet
        files["Guides/Test.lua"] = guide_lua("#chapter 1-12 West\nstep\n  .goto 10,1,1\n", classes=("DRUID",), levels=(1, 12))
        self.assertEqual(self.codes(self.lint(files)), [])

    def test_profession_quests_per_track(self):
        tables = {"maps": MAPS, "quests": QUESTS, "npcs": NPCS, "travel": TRAVEL, "professions": {393: {"n": "Skinning", "quests": [7001]}}}
        guide = guide_lua("#professions skinning\nstep\n  .goto 10,50,50\n  .hub westhold\n")
        track = "#track skinning\nstep @hub westhold\n  .goto 10,50,50\n  .trainprof skinning\n"
        files = {"Professions/SKINNING.lua": SKINNING_LUA, "Guides/Test.lua": guide, "Guides/Professions/skinning.lua": track_lua("skinning", track)}
        report = self.lint(files, pack=True, tables=tables)
        self.assertEqual(self.codes(report), ["profession-quest"])
        files["Guides/Professions/skinning.lua"] = track_lua("skinning", track + "  .accept 7001\nstep @hub westhold\n  .goto 10,50,50\n  .turnin 7001\n")
        self.assertEqual(self.codes(self.lint(files, pack=True, tables=tables)), [])

    def test_track_problems_are_reported_per_guide(self):
        guide = guide_lua("step\n  .goto 10,50,50\n  .hub westhold\nstep\n  .goto 10,60,60\n")
        track = "#track skinning\nstep @hub westhold\n  .goto 20,50,50\n  .trainprof skinning\nstep @hub nowhere\n  .trainprof skinning\n"
        report = self.lint({"Guides/Test.lua": guide, "Guides/Professions/skinning.lua": track_lua("skinning", track)})
        self.assertEqual(
            self.found(report),
            [
                ("uncovered-transition", "Guides/Professions/skinning.lua", text_line(2)),
                ("uncovered-transition", "Guides/Test.lua", guide_line(4)),
                ("unmatched-anchor", "Guides/Professions/skinning.lua", text_line(5)),
            ],
        )

    def test_gate_tokens_and_profession_keys(self):
        text = (
            "#professions skinning,skining\n"
            "step\n  .goto 10,1,1\n  .class HUNTR\n"
            "step\n  .goto 10,1,1\n  .race Trol\n"
            "step\n  .goto 10,1,1\n  .faction Hord\n"
            "step\n  .goto 10,1,1\n  .trainprof skining\n  .prof fishing\n"
        )
        files = {"Professions/SKINNING.lua": SKINNING_LUA, "Professions/FIRSTAID.lua": FIRSTAID_LUA, "Guides/Test.lua": guide_lua(text)}
        report = self.lint(files)
        self.assertEqual(
            self.found(report),
            [
                ("gate", "Guides/Test.lua", guide_line(4)),
                ("gate", "Guides/Test.lua", guide_line(10)),
                ("unknown-profession", "Guides/Test.lua", guide_line(1)),
                ("unknown-profession", "Guides/Test.lua", guide_line(13)),
                ("unknown-profession", "Guides/Test.lua", guide_line(14)),
            ],
        )
        self.assertIn(("gate", "Guides/Test.lua", guide_line(7)), self.found(report, "warning"))

    def test_unused_chapter_and_variant_notes(self):
        text = "step\n  .goto 10,1,1\n  .accept 101 .race Orc\n"
        files = {"Guides/Test.lua": guide_lua(text, races=("Orc", "Troll")), "Guides/Chapters/spare.lua": chapter_lua("spare", "step\n  .level 2\n")}
        report = self.lint(files)
        self.assertIn(("unused-chapter", "Guides/Chapters/spare.lua", 2), self.found(report, "warning"))
        rendered = "\n".join(report.render())
        self.assertIn("never-turned-in] quest 101 is accepted but never turned in (guide test-guide; only for Horde Orc HUNTER", rendered)


if __name__ == "__main__":
    unittest.main()
