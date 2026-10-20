import unittest

from signpost_tools import steps
from signpost_tools.guidefile import Coord


def step(*lines):
    return [f"  {line}" for line in lines]


def near(a, b):  # the same map, and a few percent apart
    return a.map == b.map and abs(a.x - b.x) + abs(a.y - b.y) <= 5


ALL = {7: [1, 2], 8: [1]}


class KindTest(unittest.TestCase):
    def test_a_step_is_read_by_its_directives(self):
        self.assertEqual(steps.kind(step(".goto 1,10,10", ".accept 5 -- A")), steps.PLACE)
        self.assertEqual(steps.kind(step(".goto 1,10,10", ".turnin 5 -- A", ".accept 6 -- B")), steps.PLACE)
        self.assertEqual(steps.kind(step(".goto 1,10,10", ".complete 5 -- A")), steps.DO)
        self.assertEqual(steps.kind(step(".goto 1,10,10", ".complete 5,1 -- A", ".complete 6,2 -- B")), steps.DO)
        # a talk-to objective at the NPC is part of the NPC's step
        self.assertEqual(steps.kind(step(".goto 1,10,10", ".accept 5 -- A", ".complete 5,1 -- A")), steps.PLACE)
        for other in (step(".level 5 -- reach it first"), step(".zone 12 >> Go"), step(".goto 1,1,1"), step(".todo \"x\"", ".complete 5,1 -- A")):
            self.assertEqual(steps.kind(other), steps.OTHER, other)

    def test_the_first_goto_is_the_steps_position(self):
        self.assertEqual(steps.goto(step(".level 3", ".goto 1411,43.29,68.53", ".goto 1,2,3")), Coord(1411, 43.29, 68.53))
        self.assertEqual(steps.goto(step(".goto 12,5,6,20 -- with a radius")), Coord(12, 5.0, 6.0))
        self.assertIsNone(steps.goto(step(".accept 5")))


class GroupTest(unittest.TestCase):
    def test_pick_ups_and_hand_ins_near_each_other_are_one_step_that_keeps_the_first_goto(self):
        out = steps.group(
            [step(".goto 1,10,10", ".turnin 4 -- Z"), step(".goto 1,12,11", ".accept 5 -- A"), step(".goto 1,13,10", ".accept 6 -- B")], near
        )
        self.assertEqual(len(out), 1)
        self.assertEqual(out[0], step(".goto 1,10,10", ".turnin 4 -- Z", ".accept 5 -- A", ".accept 6 -- B"))

    def test_doing_steps_near_each_other_are_one_step(self):
        out = steps.group([step(".goto 1,10,10", ".complete 5 -- A"), step(".goto 1,11,12", ".complete 6 -- B")], near)
        self.assertEqual(out, [step(".goto 1,10,10", ".complete 5 -- A", ".complete 6 -- B")])

    def test_kinds_do_not_mix_and_a_far_or_other_step_breaks_a_run(self):
        pick, do, hand = step(".goto 1,10,10", ".accept 5 -- A"), step(".goto 1,11,10", ".complete 5 -- A"), step(".goto 1,12,10", ".turnin 5 -- A")
        self.assertEqual(steps.group([pick, do, hand], near), [pick, do, hand])  # pick up, do, hand in: three steps even side by side
        far = step(".goto 1,60,60", ".accept 6 -- B")
        self.assertEqual(len(steps.group([pick, far], near)), 2)
        gate = step(".level 4 -- reach it first")
        self.assertEqual(len(steps.group([pick, gate, step(".goto 1,11,10", ".accept 7 -- C")], near)), 3)
        other_map = step(".goto 2,10,10", ".accept 8 -- D")
        self.assertEqual(len(steps.group([pick, other_map], near)), 2)

    def test_a_step_that_says_something_is_missing_stays_alone(self):
        todo = step(".goto 1,10,10", ".todo \"no position\"", ".complete 5,1 -- A")
        self.assertEqual(len(steps.group([step(".goto 1,10,10", ".complete 6 -- B"), todo, step(".goto 1,10,10", ".complete 7 -- C")], near)), 3)

    def test_grouping_twice_changes_nothing_and_the_input_is_not_touched(self):
        original = [step(".goto 1,10,10", ".accept 5 -- A"), step(".goto 1,12,10", ".accept 6 -- B")]
        copy = [list(s) for s in original]
        once = steps.group(original, near)
        self.assertEqual(original, copy)
        self.assertEqual(steps.group(once, near), once)


class WholeQuestTest(unittest.TestCase):
    def test_a_quest_whose_every_objective_is_in_the_step_is_one_complete_line(self):
        out = steps.group(
            [step(".goto 1,10,10", ".complete 7,1 -- Q", ".complete 8,1 .class HUNTER -- R", ".complete 7,2 -- Q")], near, ALL.get
        )
        self.assertEqual(out, [step(".goto 1,10,10", ".complete 7 -- Q", ".complete 8 .class HUNTER -- R")])  # gate and name kept

    def test_a_quest_with_objectives_in_other_steps_keeps_its_objective_numbers(self):
        out = steps.group([step(".goto 1,10,10", ".complete 7,1 -- Q")], near, ALL.get)
        self.assertEqual(out, [step(".goto 1,10,10", ".complete 7,1 -- Q")])

    def test_unknown_objectives_and_other_kinds_are_left_alone(self):
        text = step(".goto 1,10,10", ".complete 9,1 -- Unknown")
        self.assertEqual(steps.group([text], near, ALL.get), [text])
        place = step(".goto 1,10,10", ".accept 8 -- R", ".complete 8,1 -- R")
        self.assertEqual(steps.group([place], near, ALL.get), [place])  # a talk-to objective in an NPC's step is not collapsed


if __name__ == "__main__":
    unittest.main()
