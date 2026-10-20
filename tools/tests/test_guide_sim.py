import unittest

import guide_sim
from guide_sim import Model
from signpost_tools import guidefile
from tests.guide_fixtures import MAPS, TRAVEL, TempProject, chapter_lua, guide_lua
from tests.test_guide_travel import world

QUESTS = {
    1: {"n": "Early", "l": 1, "r": 1, "o": [{"id": 50, "k": "kill"}], "s": {"npc": [1001]}, "e": {"npc": [1001]}},
    2: {"n": "Gated", "l": 5, "r": 5, "o": [{"id": 51, "k": "kill"}], "s": {"npc": [1001]}, "e": {"npc": [1001]}},
    3: {"n": "Elite", "l": 5, "r": 1, "o": [{"id": 52, "k": "kill"}], "s": {"npc": [1001]}, "e": {"npc": [1001]}},
}
NPCS = {50: {"n": "Boar"}, 51: {"n": "Boar"}, 52: {"n": "Ogre", "rank": 1}, 1001: {"n": "Giver", "p": [[10, 40, 40]]}}


def model(overrides=None, quests=None, quest_xp=None):
    params = guide_sim.load_params(overrides=overrides)
    return Model(params, QUESTS if quests is None else quests, NPCS, {}, quest_xp)


class ParamsTest(unittest.TestCase):
    def test_overrides_and_unknown_names(self):
        params = guide_sim.load_params(overrides=["kill_seconds=30", "respawn_seconds.normal=60"])
        self.assertEqual(params["kill_seconds"], 30)
        self.assertEqual(params["respawn_seconds"]["normal"], 60)
        self.assertEqual(params["xp_to_level"][1], 400)
        for bad in ("nope=1", "respawn_seconds=1", "respawn_seconds.huge=1", "xp_to_level=1", "kill_seconds"):
            with self.assertRaises(ValueError, msg=bad):
                guide_sim.load_params(overrides=[bad])

    def test_scaling_a_parameter_leaves_the_rest(self):
        params = guide_sim.load_params()
        faster = guide_sim.scaled(params, "kill_seconds", 0.5)
        self.assertEqual(faster["kill_seconds"], params["kill_seconds"] / 2)
        self.assertEqual(faster["loot_seconds"], params["loot_seconds"])
        slower = guide_sim.scaled(params, "respawn_seconds", 2)
        self.assertEqual(slower["respawn_seconds"]["elite"], params["respawn_seconds"]["elite"] * 2)
        self.assertEqual(params["respawn_seconds"]["elite"], 300)  # the original is untouched
        self.assertIn("respawn_seconds", guide_sim.tunable(params))
        self.assertNotIn("xp_to_level", guide_sim.tunable(params))

    def test_quest_xp_seed_is_read_as_text(self):
        import tempfile
        from pathlib import Path

        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / guide_sim.XP_FILE
            path.parent.mkdir(parents=True)
            path.write_text("QuestXP.db = {\n  [2] = {30, 2450}, -- Classic\n  [5] = {20, 390},\n}\n", encoding="utf-8")
            self.assertEqual(guide_sim.read_quest_xp(Path(tmp)), {2: 2450, 5: 390})
            self.assertEqual(guide_sim.read_quest_xp(Path(tmp) / "missing"), {})
            self.assertEqual(guide_sim.read_quest_xp(None), {})


class ModelTest(unittest.TestCase):
    def test_kill_xp_falls_off_below_the_character_and_is_zero_when_gray(self):
        m = model()
        self.assertEqual(m.kill_xp(5, 5), 70)
        self.assertGreater(m.kill_xp(6, 5), m.kill_xp(5, 5))
        self.assertLess(m.kill_xp(3, 5), m.kill_xp(5, 5))
        self.assertEqual(m.kill_xp(1, 20), 0.0)

    def test_reward_xp_uses_the_seed_then_a_fraction_of_the_level_and_drops_for_trivial_quests(self):
        self.assertEqual(model(quest_xp={1: 123}).reward_xp(1, 1), 123)
        m = model()
        self.assertEqual(m.reward_xp(2, 5), m.to_next(5) * 0.1)
        self.assertLess(m.reward_xp(1, 12) / m.to_next(1), m.reward_xp(1, 1) / m.to_next(1))
        self.assertGreaterEqual(m.reward_xp(1, 40), m.to_next(1) * 0.1 * 0.1)

    def test_a_kill_objective_costs_kills_times_the_kill_cycle(self):
        m = model(["default_kills=5", "spawns_in_reach=10"])
        seconds, wait, xp = m.objective(1, 1, 1)
        cycle = 12 + 4 + 8
        self.assertEqual((seconds, wait), (5 * cycle, 0))
        self.assertEqual(xp, 5 * m.kill_xp(1, 1))

    def test_more_kills_than_spawns_wait_for_respawns_by_creature_kind(self):
        normal = model(["default_kills=20", "spawns_in_reach=4", "respawn_seconds.normal=300"])
        seconds, wait, _ = normal.objective(1, 1, 1)
        cycle = 24
        self.assertEqual(wait, 4 * (300 - 4 * cycle))  # five rounds: four waits, each the respawn minus the round's own time
        self.assertAlmostEqual(seconds, 20 * cycle + wait)
        elite = model(["default_kills=20", "spawns_in_reach=4", "respawn_seconds.elite=900"])
        self.assertGreater(elite.objective(3, 1, 5)[1], normal.objective(1, 1, 1)[1])
        quick = model(["default_kills=20", "spawns_in_reach=4", "respawn_seconds.normal=10"])
        self.assertEqual(quick.objective(1, 1, 1)[1], 0)  # the respawn is faster than the round: no wait

    def test_there_is_no_crowding_parameter(self):
        self.assertFalse([key for key in guide_sim.load_params() if "crowd" in key.lower()])

    def test_quests_above_the_character_take_longer(self):
        m = model()
        self.assertGreater(m.objective(2, 1, 1)[0], m.objective(2, 1, 5)[0])
        self.assertLess(m.objective(1, 1, 20)[0], m.objective(1, 1, 1)[0])

    def test_item_objectives_use_their_drop_source_or_count_as_gathering(self):
        quests = {7: {"n": "Gather", "l": 3, "o": [{"id": 900, "k": "item"}]}}
        items = {900: {"n": "Fang", "drops": [50]}}
        m = Model(guide_sim.load_params(), quests, NPCS, items)
        with_drops = m.objective(7, 1, 3)
        no_source = Model(guide_sim.load_params(), quests, NPCS, {}).objective(7, 1, 3)
        self.assertGreater(with_drops[2], 0)  # kills give XP
        self.assertEqual(no_source[2], 0)  # a ground item gives none


class RunTest(TempProject):
    def run_text(self, text, overrides=None, quest_xp=None):
        files = {"Guides/Test.lua": guide_lua("#include c\n"), "Guides/Chapters/c.lua": chapter_lua("c", text)}
        self.files(files)
        project = guidefile.load_project(self.root)
        guide = project.guides["test-guide"]
        route = guidefile.build_route(project, guide, guidefile.variants(project, guide)[0])
        m = Model(guide_sim.load_params(overrides=overrides), QUESTS, NPCS, {}, quest_xp)
        return guide_sim.run(route, world(), m)

    def test_a_quest_gives_xp_and_the_levels_come_with_the_clock(self):
        text = "#chapter 1-5 One\nstep\n  .goto 10,40,40\n  .accept 1\nstep\n  .goto 10,40,40\n  .complete 1,1\nstep\n  .goto 10,40,40\n  .turnin 1\n"
        result = self.run_text(text, quest_xp={1: 450})
        self.assertEqual(result.level, 2)
        self.assertIn(2, result.levels)
        self.assertGreater(result.seconds, 0)
        self.assertEqual(result.chapters[0].name, "One")
        self.assertEqual(result.stall, 0)

    def test_a_level_gate_stalls_until_the_xp_is_ground(self):
        text = "#chapter 1-5 One\nstep\n  .goto 10,40,40\n  .accept 2\n"
        result = self.run_text(text)
        self.assertEqual(len(result.stalls), 1)
        self.assertEqual(result.stalls[0].needs, 5)
        self.assertGreater(result.stall, 0)
        self.assertEqual(result.level, 5)
        slower = self.run_text(text, ["kill_seconds=60"])
        self.assertGreater(slower.stall, result.stall)

    def test_report_and_sensitivity_name_the_numbers(self):
        text = "#chapter 1-5 One\nstep\n  .goto 10,40,40\n  .accept 1\nstep\n  .complete 1,1\n"
        result = self.run_text(text)
        lines = "\n".join(guide_sim.report(result, with_steps=True))
        self.assertIn("test-guide", lines)
        self.assertIn("One", lines)
        self.assertEqual(guide_sim.hours(3660), "1h01")


if __name__ == "__main__":
    unittest.main()
