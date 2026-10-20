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
    def draft(self, *extra, quests=None, npcs=None, expect=0):
        write_pack(
            self.pack_dir,
            {"maps": MAPS, "quests": quests or QUESTS, "npcs": npcs or NPCS, "travel": TRAVEL, "items": {9999: {"n": "Thing"}, 9998: {"n": "Elite Drop", "drops": [3002]}, 9997: {"n": "Stone", "drops": [3002], "objDrops": [1]}}},
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
        self.assertIn(".complete 203 -- Boars", text)  # one objective, all in this step: the quest-level form
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
        text, report = self.draft("--exclude", "203", "--exclude-reason", "HARDCORE: elite")
        self.assertNotIn(203, self.quests_in(text, "accept"))
        self.assertIn("#skipquest 203 >> HARDCORE: elite", text)
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
        self.assertIn("HARDCORE: needs an elite or boss kill", report)
        self.assertIn(203, self.quests_in(text, "accept"))  # a normal boar is fine
        self.assertIn(222, self.quests_in(text, "accept"))  # an elite drops it, but an object gives it too

    def test_hardcore_drops_quests_far_above_the_chapter_level(self):
        normal, _ = self.draft()
        self.assertIn(223, self.quests_in(normal, "accept"))  # level 9 in a 1-6 chapter
        text, report = self.draft("--hardcore", self.rules_file([]))
        self.assertNotIn(223, self.quests_in(text, "accept"))
        self.assertIn("HARDCORE: quest level too far above the chapter", report)
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

    def test_a_quest_above_the_walk_gets_a_level_step_and_a_level_line(self):
        quests = {**QUESTS, 218: {"n": "Level Six", "r": 6, "l": 6, **HOME}}
        text, report = self.draft(quests=quests)
        self.assertIn(218, self.quests_in(text, "accept"))
        self.assertIn("level 6 is needed here", report)  # a few level-1 quests do not give five levels of XP
        self.assertLess(text.index(".level 6"), text.index(".accept 218"))
        again, _ = self.draft(quests=quests)
        self.assertEqual(text, again)  # the same pack and parameters give the same chapter

    def test_each_quest_above_the_last_level_asked_for_gets_a_level_line_before_its_accept(self):
        quests = {
            **QUESTS,
            250: {"n": "Needs Two", "r": 2, "l": 2, **HOME},
            251: {"n": "Needs Three", "r": 3, "l": 3, **HOME},
            252: {"n": "Also Three", "r": 3, "l": 3, **HOME},
        }
        text, _ = self.draft(quests=quests)
        for quest, level in ((250, 2), (251, 3)):
            self.assertRegex(text, rf"\.level {level}\n  \.accept {quest} ")  # the line comes right before the accept
        self.assertRegex(text, r"\.accept 252 ")
        self.assertEqual(text.count(".level 3\n"), 1)  # asked for once: the second level-3 quest needs no line

    def test_the_walk_carries_over_from_the_chapter_before(self):
        quests = {**QUESTS, 250: {"n": "Needs Four", "r": 4, "l": 4, **HOME}}
        text, _ = self.draft("--start-level", "4", "--gated", "4", quests=quests)
        self.assertRegex(text, r"\.accept 250 ")
        self.assertNotIn(".level 4", text)  # the chapter before already asked for it, and the walk is there
        text, _ = self.draft("--start-level", "4", quests=quests)
        self.assertRegex(text, r"\.level 4\n  \.accept 250 ")  # the walk is there, but nothing has asked for it yet

    def test_in_hardcore_objectives_still_wait_for_the_level(self):
        text, _ = self.draft("--hardcore", self.rules_file([]))
        self.assertNotIn(".complete 229,1", text.split("step\n")[1])
        self.assertLess(text.index(".level"), text.index(".complete 229,1"))

    def test_a_prerequisite_of_another_class_does_not_open_the_quest_that_follows_it(self):
        # the Burning Blade Medallion (794): it follows Vile Familiars, which the Warlock has its own version of; the
        # Warlock's version being someone else's must not make the Medallion available before the hunter's version is done
        quests = {
            **QUESTS,
            240: {"n": "Everyone's Familiars", "r": 1, "l": 2, "classes": 1247, "next": 242, **HOME},
            241: {"n": "Warlock Familiars", "r": 1, "l": 2, "classes": 256, "next": 242, **HOME},
            242: {"n": "The Medallion", "r": 1, "l": 3, "preSingle": [240, 241], **HOME},
        }
        text, report = self.draft(quests=quests)
        self.assertNotIn(241, self.quests_in(text, "accept"))
        self.assertIn(242, self.quests_in(text, "accept"))
        self.assertLess(text.index(".turnin 240"), text.index(".accept 242"))
        # and a quest whose only alternatives are other classes' is not routed at all
        quests[242] = {"n": "The Medallion", "r": 1, "l": 3, "preSingle": [241], **HOME}
        text, report = self.draft(quests=quests)
        self.assertNotIn(242, self.quests_in(text, "accept"))
        self.assertIn("a prerequisite is closed to this character", report)

    def test_a_quest_the_game_hands_over_on_turn_in_is_accepted_after_that_turn_in(self):
        quests = {
            **QUESTS,
            243: {"n": "Lead In", "r": 1, "l": 1, "next": 244, **HOME},
            244: {"n": "Handed Over", "r": 1, "l": 1, **HOME},  # no prerequisite in the pack, like Cutting Teeth
        }
        text, _ = self.draft(quests=quests)
        self.assertLess(text.index(".turnin 243"), text.index(".accept 244"))

    def test_without_grouping_a_step_is_one_place(self):
        text, _ = self.draft("--group-yards", "0")
        for step in text.split("step\n")[1:]:
            places = {line.split("--")[0].strip() for line in step.splitlines() if line.strip().startswith(".goto")}
            self.assertLessEqual(len(places), 1, step)  # a .todo step (no position) has none
        # 202 ends with another NPC than the one that gave 201: they are two steps
        steps = text.split("step\n")
        accept_201 = next(step for step in steps if ".accept 201" in step)
        self.assertNotIn(".turnin 202", accept_201)

    def test_without_grouping_kills_and_collecting_are_steps_of_their_own(self):
        text, _ = self.draft("--group-yards", "0")
        for step in text.split("step\n")[1:]:
            has_npc = ".accept" in step or ".turnin" in step
            has_work = ".complete" in step
            if has_npc and has_work:
                # only a "talk to" objective that is the NPC itself may share its step: nothing here is far from its NPC
                coords = {line.strip() for line in step.splitlines() if line.strip().startswith(".goto")}
                self.assertEqual(len(coords), 1, step)
        accept_203 = next(step for step in text.split("step\n") if ".accept 203" in step)
        self.assertNotIn(".complete 203,1", accept_203)  # the boars are not at Gornek

    NEIGHBOURS = {
        1004: {"n": "Neighbour", "p": [[10, 41, 40]], "side": "Horde"},
        3005: {"n": "Second Boar", "p": [[10, 61, 20]], "side": "none"},
    }

    def neighbour_quests(self):
        return {
            **QUESTS,
            260: {"n": "Next Door", "r": 1, "l": 1, "s": {"npc": [1004]}, "e": {"npc": [1004]}, "side": "Horde", "races": 178},
            262: {"n": "More Boars", "r": 1, "l": 2, "o": [{"id": 3005, "k": "kill"}], **HOME},
            263: {"n": "Two Places", "r": 1, "l": 2, "o": [{"id": 3001, "k": "kill"}, {"id": 3003, "k": "kill"}], **HOME},
        }

    def draft_with_neighbours(self, *extra):
        return self.draft(*extra, quests=self.neighbour_quests(), npcs={**NPCS, **self.NEIGHBOURS})

    def test_quest_givers_next_to_each_other_are_one_pick_up_step(self):
        only = ("--only", "201", "--only", "260")  # nothing else in between
        steps = self.draft_with_neighbours(*only)[0].split("step\n")
        together = next(s for s in steps if ".accept 260" in s)
        self.assertIn(".accept 201", together)  # the NPC next door and the one at the hub are one area
        gotos = [line.strip().split("--")[0].strip() for line in together.splitlines() if line.strip().startswith(".goto")]
        self.assertEqual(sorted(gotos), [".goto 10,40.0,40.0", ".goto 10,41.0,40.0"])  # each NPC keeps its own position: the pins without the pack
        apart = self.draft_with_neighbours(*only, "--group-yards", "0")[0].split("step\n")
        self.assertNotIn(".accept 201", next(s for s in apart if ".accept 260" in s))

    def test_a_cave_and_its_zone_are_two_places_however_near_they_lie(self):
        # Westland (10) and the cave inside it (11): the cave's (50, 50) is Westland's (47.5, 45), no yards apart, but two maps (and a
        # joined step would hold gotos in two zones, which the travel check calls a zone jump)
        npcs = {
            **NPCS,
            1010: {"n": "On The Hill", "p": [[10, 47.5, 45]], "side": "Horde"},
            1011: {"n": "In The Cave", "p": [[11, 50, 50]], "side": "Horde"},
        }
        quests = {
            **QUESTS,
            270: {"n": "Hill Errand", "r": 1, "l": 1, "s": {"npc": [1010]}, "e": {"npc": [1010]}, "side": "Horde", "races": 178},
            271: {"n": "Cave Errand", "r": 1, "l": 1, "s": {"npc": [1011]}, "e": {"npc": [1011]}, "side": "Horde", "races": 178},
        }
        text = self.draft("--only", "270", "--only", "271", quests=quests, npcs=npcs)[0]
        steps = text.split("step\n")
        hill = next(s for s in steps if ".accept 270" in s)
        self.assertIn(".goto 10,47.5,45.0", hill)
        self.assertNotIn(".accept 271", hill)  # not joined with the cave's giver
        self.assertIn(".goto 11,50.0,50.0", next(s for s in steps if ".accept 271" in s))

    def test_objectives_close_to_each_other_are_one_doing_step_and_a_far_one_is_not(self):
        steps = self.draft_with_neighbours()[0].split("step\n")
        doing = next(s for s in steps if ".complete 203" in s)
        self.assertIn(".complete 262", doing)  # two boar camps 20 units apart
        self.assertNotIn(".accept", doing)
        self.assertNotIn(".turnin", doing)
        far = next((s for s in steps if ".complete 229" in s), None)
        self.assertIsNotNone(far)  # the hub rats are routed, about 450 yards from the boars...
        self.assertNotIn(".complete 229", doing)  # ...and are a doing step of their own

    def test_a_quest_finished_in_one_step_is_one_complete_line_and_a_split_quest_keeps_its_objectives(self):
        text = self.draft_with_neighbours()[0]
        self.assertIn(".complete 263,1", text)  # the boar camp and the hub rats are two steps: each says its objective
        self.assertIn(".complete 263,2", text)
        self.assertNotRegex(text, r"\.complete 263 ")
        self.assertIn(".complete 203 -- Boars", text)

    def test_group_quests_are_optional_in_a_normal_guide_and_left_out_of_a_hardcore_one(self):
        text, _ = self.draft()
        self.assertIn(220, self.quests_in(text, "accept"))  # kills an elite
        self.assertRegex(text, r"\.optional 220 -- group quest: Elite Hunt")
        self.assertNotIn(".optional 203", text)  # an ordinary boar quest is not optional
        hardcore, _ = self.draft("--hardcore", self.rules_file([]))
        self.assertNotIn(".optional", hardcore)

    def test_only_drafts_the_named_quests_and_a_note_goes_after_the_accept(self):
        text, report = self.draft("--only", "201", "--only", "202", "--note", "202=Unverified: from the data.")
        self.assertEqual(set(self.quests_in(text, "accept")), {201, 202})
        self.assertIn("not named by --only", report)
        self.assertRegex(text, r"\.accept 202 -- Follows First\n  \.note Unverified: from the data\.")
        with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
            self.draft("--note", "not a note")

    def test_a_chain_orders_quests_the_pack_does_not_link(self):
        text, _ = self.draft("--chain", "203,201")  # 201 has no prerequisite in the pack; the chain makes it wait for 203
        self.assertLess(text.index(".turnin 203"), text.index(".accept 201"))
        plain, _ = self.draft()
        self.assertLess(plain.index(".accept 201"), plain.index(".turnin 203"))  # without it the lowest ID goes first


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
