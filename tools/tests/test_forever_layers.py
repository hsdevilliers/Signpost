"""forever_layers (applying correction records with `_add` / `_remove`) and the importer on top of it: synthetic data only."""

import json
import tempfile
import unittest
from pathlib import Path

import questie_import as qi
from signpost_tools import datapack
from signpost_tools import forever_layers as fl
from signpost_tools import lua_corrections as lc
from tests import forever_fixtures as fx
from tests.test_questie_import import make_checkout


def ref(name: str, op: str = "set") -> lc.FieldRef:
    return lc.FieldRef("quest", name, op)


class OperationTest(unittest.TestCase):
    def apply(self, slots, name, op, value, shape):
        return fl.apply_field(slots, 1, ref(name, op), value, shape)

    def test_ordinary_assignment_replaces_and_an_empty_table_clears(self):
        slots = {1: [[5]]}
        self.assertEqual(self.apply(slots, "startedBy", "set", [[6]], "questgivers"), (True, None))
        self.assertEqual(slots, {1: [[6]]})
        self.assertEqual(self.apply(slots, "startedBy", "set", [[6]], "questgivers"), (False, None))
        self.assertEqual(self.apply(slots, "startedBy", "set", [], "questgivers"), (True, None))
        self.assertEqual(slots, {})
        self.assertEqual(self.apply(slots, "questLevel", "set", 7, None), (True, None))
        self.assertEqual(slots, {1: 7})

    def test_lists_add_missing_and_remove_exact_values_in_order(self):
        slots = {1: [3, 1]}
        self.apply(slots, "preQuestSingle", "add", [1, 2, 2], "idarray")
        self.assertEqual(slots[1], [3, 1, 2])
        self.apply(slots, "preQuestSingle", "remove", [1, 9], "idarray")
        self.assertEqual(slots[1], [3, 2])
        self.assertEqual(self.apply(slots, "preQuestSingle", "remove", [3, 2], "idarray"), (True, None))
        self.assertEqual(slots, {})  # a list that empties is cleared

    def test_groups_apply_inside_the_named_positions_only_with_nil_holes(self):
        slots = {1: [[5]]}  # creatures {5}
        self.assertEqual(self.apply(slots, "finishedBy", "add", [None, [630696]], "questgivers"), (True, None))
        self.assertEqual(slots[1], {1: [5], 2: [630696]})  # the omitted creature group is preserved
        self.apply(slots, "finishedBy", "add", [[5, 6]], "questgivers")
        self.assertEqual(slots[1], {1: [5, 6], 2: [630696]})
        self.apply(slots, "finishedBy", "remove", [None, [630696]], "questgivers")
        self.assertEqual(slots[1], {1: [5, 6]})  # an emptied group disappears
        self.apply(slots, "finishedBy", "add", {3: [7]}, "questgivers")  # a dict operand names its groups too
        self.assertEqual(slots[1], {1: [5, 6], 3: [7]})

    def test_zone_keyed_groups_and_whole_coordinates(self):
        slots = {1: {501: [[1, 2]]}}
        self.apply(slots, "spawns", "add", {501: [[1, 2], [3, 4]], 507: [[5, 6]]}, "spawnlist")
        self.assertEqual(slots[1], {501: [[1, 2], [3, 4]], 507: [[5, 6]]})
        self.apply(slots, "spawns", "remove", {501: [[1, 2]]}, "spawnlist")
        self.assertEqual(slots[1], {501: [[3, 4]], 507: [[5, 6]]})

    def test_objective_reputation_group_and_atomic_pairs_are_not_lists(self):
        slots = {1: {4: [76, 100]}}
        self.assertEqual(self.apply(slots, "objectives", "add", [None, None, None, [76, 100]], "objectives"), (False, None))
        changed, rejection = self.apply(slots, "objectives", "add", [None, None, None, [54, 5]], "objectives")
        self.assertFalse(changed)
        self.assertIn("different value", rejection)
        self.assertEqual(slots[1], {4: [76, 100]})
        self.assertEqual(self.apply(slots, "objectives", "remove", [None, None, None, [76, 100]], "objectives"), (True, None))
        self.assertEqual(slots, {})
        slots = {}
        self.assertEqual(self.apply(slots, "requiredSkill", "add", [165, 1], "pair"), (True, None))
        self.assertEqual(slots, {1: [165, 1]})
        self.assertIsNotNone(self.apply(slots, "requiredSkill", "add", [171, 1], "pair")[1])

    def test_an_operation_on_a_scalar_is_rejected(self):
        slots = {1: 5}
        changed, rejection = self.apply(slots, "questLevel", "add", [1], None)
        self.assertEqual((changed, slots), (False, {1: 5}))
        self.assertIn("no table shape", rejection)


class LayeredImportTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.root = fx.make_layered_checkout(Path(cls.tmp.name) / "questiedb")
        cls.base = qi.Importer(qi.load(cls.root), max_drops=3).run()  # the baseline alone, for comparison
        cls.questie = qi.load(cls.root)
        cls.report = fl.apply_layers(cls.questie, cls.root)
        cls.importer = qi.Importer(cls.questie, max_drops=3)
        cls.tables = cls.importer.run()

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def test_layers_are_applied_in_order_and_counted(self):
        self.assertTrue(self.report.applied)
        self.assertEqual([layer.name for layer in self.report.layers], ["delta-base", "traces", "authored"])
        delta, traces, authored = self.report.layers
        self.assertEqual((delta.added["quest"], delta.changed["quest"]), (4, 1))  # 50-53 new; quest 1's level changed
        self.assertEqual((delta.added["npc"], traces.added["quest"]), (1, 0))
        self.assertEqual(traces.changed["quest"], 2)  # a finisher added to 1 and a starter object to 2
        self.assertEqual((authored.added["quest"], authored.changed["quest"]), (0, 3))
        self.assertIn("delta-base +", self.report.summary())

    def test_a_delta_adds_a_quest_a_level_and_a_finisher(self):
        quests = self.tables["quests"]
        self.assertNotIn(50, self.base["quests"])
        self.assertEqual(
            quests[50],
            {
                "n": "Windshaper Start",
                "side": "Horde",
                "l": 2,
                "r": 1,
                "races": 8589934770,
                "zone": 2521,  # ZEPHYR (507) -> uiMapID 2521, a zone the baseline does not have
                "s": {"npc": [120]},
                "e": {"npc": [120]},
                "o": [{"k": "item", "id": 300}],
            },
        )
        self.assertEqual(self.base["quests"][1]["l"], 2)
        self.assertEqual(quests[1]["l"], 5)  # level changed by the delta-base
        self.assertEqual(self.base["quests"][1]["e"], {"npc": [100]})
        self.assertEqual(quests[1]["e"], {"npc": [100, 102]})  # finisher added by a trace; the duplicate starter changed nothing
        self.assertEqual(quests[1]["s"], {"npc": [100]})
        self.assertNotIn("preSingle", quests[1])  # removed by the authored layer
        self.assertEqual(quests[2]["s"], {"npc": [102], "obj": [200]})  # a nil-hole operand: the object group
        self.assertEqual(quests[2]["r"], 9)  # authored last
        self.assertEqual(quests[2]["races"], 2 + 128)

    def test_new_entities_come_with_their_positions(self):
        npc = self.tables["npcs"][120]
        self.assertEqual((npc["n"], npc["side"], npc["p"]), ("Windshaper Elder", "Horde", [[2521, 10.5, 20.5]]))

    def test_skyborne_side_logic(self):
        quests = self.tables["quests"]
        self.assertEqual(quests[52]["side"], "Horde")  # a Windshaper-only quest is a Horde quest, not dropped
        self.assertNotIn(51, quests)  # a High Order Skyborne (Alliance) quest is not a Horde quest
        self.assertEqual(self.importer.stats["quests left out (Alliance)"], 1)
        self.assertNotIn(53, quests)  # a bit that is neither Classic nor Skyborne is still reported, never silent
        self.assertIn(
            "quests whose race mask has no Classic or Skyborne race bit (1): 53", self.importer.problem_lines()
        )
        for mask, side in (
            (qi.SKYBORNE_HORDE, "Horde"),
            (qi.SKYBORNE_ALLIANCE, "Alliance"),
            (qi.SKYBORNE_HORDE | qi.SKYBORNE_ALLIANCE, "both"),
            (178 | qi.SKYBORNE_HORDE, "Horde"),  # ALL_HORDE
            (77 | qi.SKYBORNE_ALLIANCE, "Alliance"),  # ALL_ALLIANCE
            (2 | qi.SKYBORNE_ALLIANCE, "both"),
            (0, "both"),
            (256, None),
        ):
            with self.subTest(mask=mask):
                self.assertEqual(qi.race_side(mask), side)
        self.assertEqual((qi.SKYBORNE_ALLIANCE, qi.SKYBORNE_HORDE), (1 << 32, 1 << 33))

    def test_skipped_constructs_are_counted_and_never_applied(self):
        skipped = self.report.skipped
        self.assertEqual(skipped["unresolved constant zoneIDs.NO_SUCH_ZONE"], 1)
        self.assertEqual(skipped["function value"], 1)
        self.assertEqual(skipped["runtime function LoadDynamic (not read)"], 1)
        self.assertEqual(self.tables["quests"][3]["zone"], 1413)  # the baseline zone stays: the bad constant was not guessed
        self.assertEqual(self.tables["quests"][1]["l"], 5)  # LoadDynamic's questLevel 40 was never read

    def test_no_text_is_kept(self):
        text = json.dumps(self.tables)
        for kept in ("Never kept text", "Kill 8 boars"):
            self.assertNotIn(kept, text)

    def test_a_group_position_disagreement_is_refused(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = make_checkout(Path(tmp) / "q")  # the default fixture's startedBy is {item, creature, object}
            fx.add_forever_layers(root)
            with self.assertRaises(lc.CorrectionsFormatError):
                fl.apply_layers(qi.load(root), root)

    def test_a_checkout_without_forever_layers_is_the_baseline(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = make_checkout(Path(tmp) / "q")
            report = fl.apply_layers(qi.load(root), root)
        self.assertFalse(report.applied)
        self.assertIn("no Forever layers", report.summary())


class PackTest(unittest.TestCase):
    def test_import_layer_writes_origin_gaps_and_the_off_switch(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = fx.make_layered_checkout(Path(tmp) / "questiedb")
            pack = Path(tmp) / "pack"
            datapack.init_stub(pack)
            importer, counts = qi.import_layer(root, pack, max_drops=3)
            self.assertEqual(counts["quests"], 5)  # the baseline 1-3 and the Horde quests 50 and 52
            layer = json.loads((pack / "layers" / "questie.json").read_text(encoding="utf-8"))
            self.assertIn("plus Forever layers (delta-base +", layer["origin"])
            self.assertIn("not complete objectives or gameplay behavior", layer["origin"])
            self.assertTrue(any(line.startswith("Forever layers skipped function value") for line in layer["problems"]))
            gaps = (pack / "data-gaps.md").read_text(encoding="utf-8")
            self.assertIn("Zephras Isle (2521): 1 quests, 1 NPCs", gaps)
            self.assertIn("Now covered", gaps)
            self.assertIn("does not supply complete objectives", gaps)
            self.assertNotIn("Classic **baseline**", gaps)
            self.assertEqual(importer.stats["quest records in QuestieDB's base tables"], 3)
            self.assertEqual(importer.stats["quest records after the Forever layers"], 7)
            quests = datapack.read_table(pack, "quests")
            self.assertEqual(quests[50]["races"], 8589934770)

            off = Path(tmp) / "off"
            datapack.init_stub(off)
            importer, counts = qi.import_layer(root, off, forever_layers_on=False, max_drops=3)
            self.assertEqual(counts["quests"], 3)  # quests 1 to 3: the baseline alone
            layer = json.loads((off / "layers" / "questie.json").read_text(encoding="utf-8"))
            self.assertIn("switched off", layer["origin"])
            self.assertIn("no Forever content", layer["origin"])
            self.assertIn("Classic **baseline**", (off / "data-gaps.md").read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
