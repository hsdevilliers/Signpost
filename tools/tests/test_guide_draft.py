import contextlib
import io
import json
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
    3002: {"n": "Elite Boar", "p": [[10, 80, 20]], "side": "none", "rank": 1},
    3003: {"n": "Hub Rat", "p": [[10, 40, 40]], "side": "none"},
    3004: {"n": "Far Rat", "p": [[20, 50, 50]], "side": "none"},
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
    220: {"n": "Elite Hunt", "r": 1, "l": 2, "o": [{"id": 3002, "k": "kill"}], **HOME},
    221: {"n": "Elite Loot", "r": 1, "l": 2, "o": [{"id": 9998, "k": "item"}], **HOME},
    222: {"n": "Well Stone", "r": 1, "l": 2, "o": [{"id": 9997, "k": "item"}], **HOME},
    223: {"n": "Red Quest", "r": 1, "l": 9, **HOME},
    226: {"n": "Skinning Only", "r": 1, "l": 1, "skill": [393, 1], **HOME},
    227: {"n": "After Skinning", "r": 1, "l": 1, "preSingle": [226], **HOME},
    228: {"n": "Far Rats", "r": 1, "l": 2, "o": [{"id": 3004, "k": "kill"}], **HOME},
    229: {"n": "Hub Rats", "r": 1, "l": 6, "o": [{"id": 3003, "k": "kill"}], **HOME},
}


class DraftCase(TempProject):
    def draft(self, *extra, quests=None, expect=0):
        write_pack(
            self.pack_dir,
            {"maps": MAPS, "quests": quests or QUESTS, "npcs": NPCS, "travel": TRAVEL, "items": {9999: {"n": "Thing"}, 9998: {"n": "Elite Drop", "drops": [3002]}, 9997: {"n": "Stone", "drops": [3002], "objDrops": [1]}}},
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
        self.assertTrue({201, 202, 203, 212, 216, 217, 220, 221, 222, 223, 229} >= accepted, accepted)
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
        other = ({212, 213} - routed).pop()
        self.assertIn(f"#skipquest {other} >> alternative to quest {routed.pop()}, which is routed", text)
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

    def test_class_gates_name_the_classes_of_the_mask(self):
        gate = guide_draft.class_gate
        self.assertEqual(gate(4, "HUNTER"), " .class HUNTER")
        self.assertEqual(gate(4 | 8, "HUNTER"), " .class HUNTER,ROGUE")
        self.assertEqual(gate(1247, "HUNTER"), " .class !WARLOCK")  # everyone but the warlock
        self.assertEqual(gate(None, "HUNTER"), "")
        self.assertEqual(gate(sum(guide_draft.CLASS_BITS.values()), "HUNTER"), "")
        self.assertEqual(gate(4, "HUNTER", gate_class=False), "")

    def test_the_walk_starts_in_the_first_zone_asked_for(self):
        quests = {**QUESTS, 224: {"n": "Two Places", "r": 1, "l": 1, "s": {"npc": [1002, 1001]}, "e": START, "side": "Horde"}}
        text, _ = self.draft("--zone", "20", quests=quests)  # zones 10 and 20; the first quest has givers in both
        first_goto = re.search(r"\.goto (\d+),", text).group(1)
        self.assertEqual(first_goto, "10")

    def test_the_walk_starts_with_the_races_own_first_quest(self):
        # a generic Horde quest with a lower ID and a giver in another zone must not pull the start away from the race's own start
        quests = {
            230: {"n": "Breadcrumb From Afar", "r": 1, "l": 1, "s": {"npc": [1002]}, "e": START, "side": "Horde", "races": 178},
            231: {"n": "Our Own First", "r": 1, "l": 1, "s": START, "e": START, "side": "Horde", "races": 2},
            # a lower ID than 231, the same race, but a level 6 quest at a place away from the start: not where level 1 begins
            229: {"n": "Own But Harder", "r": 1, "l": 6, "s": {"npc": [1003]}, "e": START, "side": "Horde", "races": 2},
        }
        text, _ = self.draft("--zone", "20", quests=quests)  # zones 10 then 20
        first_step = text.split("step\n")[1]
        self.assertIn(".goto 10,40.0,40.0", first_step)  # the Orc's own start, not the other zone's breadcrumb giver
        self.assertIn(".accept 231", first_step)

    def test_a_race_only_quest_above_the_starting_level_is_not_the_start(self):
        # Tauren-style: the only race-limited quests are village quests that need level 3; the real start is a generic Horde one
        quests = {
            228: {"n": "Village Own", "r": 3, "l": 3, "s": {"npc": [1003]}, "e": START, "side": "Horde", "races": 2},
            234: {"n": "Camp Start", "r": 1, "l": 2, "s": START, "e": START, "side": "Horde", "races": 178},
        }
        text, _ = self.draft(quests=quests)
        first_step = text.split("step\n")[1]
        self.assertIn(".goto 10,40.0,40.0", first_step)
        self.assertIn(".accept 234", first_step)

    def test_class_quests_carry_a_class_gate_unless_asked_not_to(self):
        text, _ = self.draft()
        self.assertRegex(text, r"\.accept 217 \.class HUNTER")
        text, _ = self.draft("--no-gate-class")
        self.assertNotIn(".class HUNTER", text)

    def test_a_quest_behind_a_profession_prerequisite_is_not_routed(self):
        text, report = self.draft()
        self.assertNotIn(227, self.quests_in(text, "accept"))  # its prerequisite needs a skill the chapter cannot assume
        self.assertIn("needs a profession skill", report)

    def test_a_quest_whose_objective_is_only_in_another_zone_is_dropped(self):
        text, report = self.draft()
        self.assertNotIn(228, self.quests_in(text, "accept"))
        self.assertIn("objective lies outside the zones", report)

    def test_in_hardcore_objectives_wait_for_the_level(self):
        normal, _ = self.draft()
        step = normal.split("step\n")[1]
        self.assertIn(".complete 229,1", step)  # without --hardcore it is done at once, beside the hub
        text, _ = self.draft("--hardcore", self.rules_file([]))
        first = text.split("step\n")[1]
        self.assertNotIn(".complete 229,1", first)
        self.assertIn(".complete 229,1", text)  # but it is routed, later
        self.assertLess(text.index(".level"), text.index(".complete 229,1"))

    def test_class_only_keeps_just_the_class_limited_quests(self):
        text, report = self.draft("--class-only")
        self.assertEqual(set(self.quests_in(text, "accept")), {217})
        self.assertIn("not a class quest", report)

    def test_done_quests_are_not_drafted_again_but_unlock_their_chain(self):
        text, _ = self.draft("--done", "201")
        accepted = self.quests_in(text, "accept")
        self.assertNotIn(201, accepted)
        self.assertIn(202, accepted)  # 202 follows 201
        self.assertNotIn("#skipquest 201", text)

    def test_excluded_quests_become_skipquest_lines(self):
        text, report = self.draft("--exclude", "203", "--exclude-reason", "hardcore: elite")
        self.assertNotIn(203, self.quests_in(text, "accept"))
        self.assertIn("#skipquest 203 >> hardcore: elite", text)
        self.assertIn("excluded by the author", report)

    def rules_file(self, rules):
        path = self.root / "rules.json"
        path.write_text(json.dumps({"rules": rules}), encoding="utf-8")
        return str(path)

    def test_hardcore_rules_skip_quests_and_add_notes(self):
        rules = [
            {"id": 203, "action": "skip", "reason": "hardcore: elite boar"},
            {"id": 201, "action": "note", "text": "Heal up first."},
            {"id": 999, "action": "skip", "reason": "not in this chapter"},
        ]
        text, report = self.draft("--hardcore", self.rules_file(rules))
        self.assertIn("#skipquest 203 >> hardcore: elite boar", text)
        self.assertNotIn("#skipquest 999", text)  # only quests the chapter would have routed
        self.assertNotIn(203, self.quests_in(text, "accept"))
        self.assertRegex(text, r"\.accept 201 -- First\n  \.note Heal up first\.")
        self.assertIn("excluded by the author", report)

    def test_hardcore_drops_quests_that_need_an_elite_kill_or_an_elite_only_item(self):
        normal, _ = self.draft()
        self.assertTrue({220, 221} <= set(self.quests_in(normal, "accept")))
        text, report = self.draft("--hardcore", self.rules_file([]))
        self.assertFalse({220, 221} & set(self.quests_in(text, "accept")))
        self.assertIn("hardcore: needs an elite or boss kill", report)
        self.assertIn(203, self.quests_in(text, "accept"))  # a normal boar is fine
        self.assertIn(222, self.quests_in(text, "accept"))  # an elite drops it, but an object gives it too

    def test_hardcore_drops_quests_far_above_the_chapter_level(self):
        normal, _ = self.draft()
        self.assertIn(223, self.quests_in(normal, "accept"))  # level 9 in a 1-6 chapter
        text, report = self.draft("--hardcore", self.rules_file([]))
        self.assertNotIn(223, self.quests_in(text, "accept"))
        self.assertIn("hardcore: quest level too far above the chapter", report)
        text, _ = self.draft("--hardcore", self.rules_file([]), "--hardcore-over", "3")
        self.assertIn(223, self.quests_in(text, "accept"))  # 6 + 3 allows level 9

    def test_a_missing_rules_file_is_an_error(self):
        with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
            self.draft("--hardcore", str(self.root / "nowhere.json"))

    def test_the_shipped_hardcore_rules_are_complete(self):
        rules = json.loads(guide_draft.Path(guide_draft.__file__).with_name("hardcore_rules.json").read_text(encoding="utf-8"))
        for rule in rules["rules"]:
            self.assertIsInstance(rule["id"], int)
            self.assertIn(rule["action"], ("skip", "note"))
            self.assertTrue(rule.get("source") and rule.get("confidence") in ("high", "medium", "low"), rule)
            self.assertTrue(rule.get("reason") if rule["action"] == "skip" else rule.get("text"), rule)

    def test_the_level_estimate_does_not_stall_on_a_gate(self):
        quests = {**QUESTS, 218: {"n": "Level Six", "r": 6, "l": 6, **HOME}}
        text, report = self.draft(quests=quests)
        self.assertIn(218, self.quests_in(text, "accept"))
        self.assertIn("assumed", report)

    def test_xp_levels_estimate_from_quest_xp_and_still_do_not_stall(self):
        quests = {**QUESTS, 218: {"n": "Level Six", "r": 6, "l": 6, **HOME}}
        text, report = self.draft("--xp-levels", quests=quests)
        self.assertIn(218, self.quests_in(text, "accept"))
        self.assertIn("assumed", report)  # a few level-1 quests do not give six levels of XP
        again, _ = self.draft("--xp-levels", quests=quests)
        self.assertEqual(text, again)  # the same pack and parameters give the same chapter

    def test_xp_levels_keep_the_hardcore_wait(self):
        text, _ = self.draft("--xp-levels", "--hardcore", self.rules_file([]))
        self.assertNotIn(".complete 229,1", text.split("step" + chr(10))[1])
        self.assertLess(text.index(".level"), text.index(".complete 229,1"))


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
