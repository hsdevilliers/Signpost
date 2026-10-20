import contextlib
import io
import re
import unittest

import guide_draft
import guide_lint
from tests.guide_fixtures import MAPS, TRAVEL, TempProject, chapter_lua, guide_lua, write_pack

# NPCs: 1001 and 1003 in Westland (10), 1002 in Eastland (20); 3001 is a kill target in Westland.
NPCS = {
    1001: {"n": "Giver", "p": [[10, 40, 40]], "side": "Horde"},
    1002: {"n": "Far Giver", "p": [[20, 60, 60]], "side": "Horde"},
    1003: {"n": "Second Giver", "p": [[10, 70, 70]], "side": "Horde"},
    3001: {"n": "Boar", "p": [[10, 60, 20]], "side": "none"},
}
START = {"npc": [1001]}
HOME = {"s": START, "e": START, "side": "Horde", "races": 178}

QUESTS = {
    201: {"n": "First", "r": 1, "l": 1, **HOME},
    202: {"n": "Follows First", "r": 1, "l": 1, "preSingle": [201], "s": START, "e": {"npc": [1003]}, "side": "Horde"},
    203: {"n": "Boars", "r": 1, "l": 2, "o": [{"id": 3001, "k": "kill"}], **HOME},
    204: {"n": "Warrior Only", "r": 1, "l": 1, "classes": 1, **HOME},
    205: {"n": "Daily", "r": 1, "l": 1, "repeatable": True, **HOME},
    206: {"n": "Festival", "r": 1, "l": 1, "sort": 366, **HOME},
    207: {"n": "Human Only", "r": 1, "l": 1, "s": START, "e": START, "side": "Horde", "races": 1},
    208: {"n": "Needs Skill", "r": 1, "l": 1, "skill": 164, **HOME},
    209: {"n": "Too High", "r": 30, "l": 30, **HOME},
    210: {"n": "Elsewhere", "r": 1, "l": 1, "zone": 20, **HOME},
    211: {"n": "Ends Far Away", "r": 1, "l": 1, "s": START, "e": {"npc": [1002]}, "side": "Horde"},
    212: {"n": "Either This", "r": 1, "l": 1, "exclusive": [213], **HOME},
    213: {"n": "Or That", "r": 1, "l": 1, "exclusive": [212], **HOME},
    214: {"n": "Alliance", "r": 1, "l": 1, "s": START, "e": START, "side": "Alliance"},
    215: {"n": "After A Dropped One", "r": 1, "l": 1, "preSingle": [211], **HOME},
    216: {"n": "Item Hunt", "r": 1, "l": 2, "o": [{"id": 9999, "k": "item"}], **HOME},
    217: {"n": "Hunter Chain", "r": 1, "l": 1, "classes": 4, **HOME},
}


class DraftCase(TempProject):
    def draft(self, *extra, quests=None, expect=0):
        write_pack(
            self.pack_dir,
            {"maps": MAPS, "quests": quests or QUESTS, "npcs": NPCS, "travel": TRAVEL, "items": {9999: {"n": "Thing"}}},
        )
        args = ["--race", "Orc", "--class", "HUNTER", "--zone", "10", "--levels", "1-6", "--id", "test-chapter"]
        args += ["--name", "Test", "--pack", str(self.pack_dir), *extra]
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = guide_draft.main(args)
        self.assertEqual(code, expect, err.getvalue())
        return out.getvalue(), err.getvalue()

    @staticmethod
    def quests_in(text, directive):
        return [int(n) for n in re.findall(rf"\.{directive} (\d+)", text)]


class PoolTest(DraftCase):
    def test_the_pool_keeps_only_what_this_character_can_take_here(self):
        text, report = self.draft()
        accepted = set(self.quests_in(text, "accept"))
        self.assertTrue({201, 202, 203, 212, 216, 217} >= accepted, accepted)
        for dropped, reason in (
            (204, "other class"),
            (205, "repeatable"),
            (206, "seasonal or event"),
            (207, "other race"),
            (208, "needs a profession skill"),
            (209, "above the level range"),
            (210, "belongs to another zone"),
            (211, "turn-in outside the zones"),
            (214, "other faction"),
        ):
            self.assertNotIn(dropped, accepted)
            self.assertIn(reason, report)

    def test_a_chain_follows_its_prerequisite_and_one_of_two_exclusive_quests_is_routed(self):
        text, report = self.draft()
        self.assertLess(text.index(".turnin 201"), text.index(".accept 202"))
        routed = {212, 213} & set(self.quests_in(text, "accept"))
        self.assertEqual(len(routed), 1)
        self.assertIn("is exclusive with", report)

    def test_a_quest_behind_a_dropped_prerequisite_is_never_routed(self):
        text, report = self.draft()
        self.assertNotIn(215, self.quests_in(text, "accept"))
        self.assertIn("never available", report)
        self.assertIn("215", report)

    def test_objectives_are_pinned_and_unplaced_ones_become_a_todo(self):
        text, report = self.draft()
        self.assertIn(".goto 10,60.0,20.0", text)
        self.assertIn(".complete 203,1", text)
        self.assertIn('.todo "Item Hunt: objective 1 (item 9999) has no position in the pack"', text)
        self.assertIn("quest 216 (Item Hunt) objective 1", report)

    def test_class_quests_carry_a_class_gate_unless_asked_not_to(self):
        text, _ = self.draft()
        self.assertRegex(text, r"\.accept 217 \.class HUNTER")
        text, _ = self.draft("--no-gate-class")
        self.assertNotIn(".class HUNTER", text)

    def test_excluded_quests_become_skipquest_lines(self):
        text, report = self.draft("--exclude", "203", "--exclude-reason", "hardcore: elite")
        self.assertNotIn(203, self.quests_in(text, "accept"))
        self.assertIn("#skipquest 203 >> hardcore: elite", text)
        self.assertIn("excluded by the author", report)

    def test_the_level_estimate_does_not_stall_on_a_gate(self):
        quests = {**QUESTS, 218: {"n": "Level Three", "r": 3, "l": 3, **HOME}}
        text, report = self.draft(quests=quests)
        self.assertIn(218, self.quests_in(text, "accept"))
        self.assertIn("assumed", report)


class OutputTest(DraftCase):
    def test_the_draft_is_a_chapter_the_linter_accepts(self):
        text, _ = self.draft()
        files = {
            "Guides/Test.lua": guide_lua("#include test-chapter\n", races=("Orc",)),
            "Guides/Chapters/test-chapter.lua": chapter_lua("test-chapter", text),
        }
        self.files(files)
        report, _, _ = guide_lint.lint(self.root, self.pack_dir)
        errors = [key for key in report.entries if key[0] == "error"]
        self.assertEqual(errors, [])

    def test_the_chapter_file_has_a_draft_header_and_registers_the_chapter(self):
        self.draft("--out", str(self.root / "Guides" / "Chapters" / "test-chapter.lua"))
        written = (self.root / "Guides" / "Chapters" / "test-chapter.lua").read_text(encoding="utf-8")
        self.assertTrue(written.startswith("-- DRAFT"))
        self.assertIn('ns.Chapters:Register("test-chapter", [[', written)

    def test_a_race_the_tool_does_not_know_needs_its_bit(self):
        with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
            self.draft("--race", "Brandnew")
        with contextlib.redirect_stderr(io.StringIO()):
            self.draft("--race", "Brandnew", "--race-bit", "2")

    def test_without_a_pack_it_stops(self):
        with contextlib.redirect_stderr(io.StringIO()):
            code = guide_draft.main(
                ["--race", "Orc", "--class", "HUNTER", "--zone", "10", "--levels", "1-6", "--id", "x", "--name", "X"]
                + ["--pack", str(self.root / "nowhere")]
            )
        self.assertEqual(code, 1)


if __name__ == "__main__":
    unittest.main()
