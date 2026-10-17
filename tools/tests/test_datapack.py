"""signpost_tools.datapack: layers keep numeric keys at every depth, and the classes table becomes classes/<CLASS>.lua
whichever tool rebuilds the pack (synthetic test records, not real data)."""

import tempfile
import unittest
from pathlib import Path

from signpost_tools import datapack
from signpost_tools.savedvars import load_savedvars

WOWHEAD = {
    "professions": {165: {"n": "Test Craft", "recipes": {601: {"item": 701, "reagents": {702: 2}}}}},
    "classes": {
        "HUNTER": {"spells": {4: [501, 502]}, "trainers": [3001], "quests": [{"id": 201, "quests": [201, 202]}]},
        "not a class": {"spells": {}},
    },
}


class NumericKeysTest(unittest.TestCase):
    def test_digit_keys_at_every_depth(self):
        value = {"1": {"-2": [{"3": "x"}], "n": "y"}, "a": 1, "12b": 2, "-": 3}
        self.assertEqual(datapack.numeric_keys(value), {1: {-2: [{3: "x"}], "n": "y"}, "a": 1, "12b": 2, "-": 3})


class BuildTest(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.pack = Path(tmp.name) / "pack"
        datapack.init_stub(self.pack)

    def test_layers_read_back_with_numeric_keys_inside_records(self):
        datapack.write_layer(self.pack, "wowhead", WOWHEAD, "test")
        tables = datapack.read_layer(self.pack, "wowhead")["tables"]
        self.assertEqual(tables["professions"][165]["recipes"][601]["reagents"], {702: 2})
        self.assertEqual(tables["classes"]["HUNTER"]["spells"], {4: [501, 502]})

    def test_classes_become_class_files_and_survive_other_tools_rebuilding(self):
        datapack.write_layer(self.pack, "wowhead", WOWHEAD, "test")
        counts = datapack.build(self.pack, "test")
        self.assertEqual(counts["classes"], 1)
        hunter = load_savedvars(self.pack / "classes" / "HUNTER.lua")["Signpost_Data.classes.HUNTER"]
        self.assertEqual(hunter["spells"], {4: [501, 502]})
        self.assertEqual(hunter["src"], "wowhead")
        self.assertFalse((self.pack / "classes" / "not a class.lua").exists())
        toc = (self.pack / "Signpost_Data.toc").read_text(encoding="utf-8")
        self.assertIn("classes\\HUNTER.lua", toc)

        # another source rebuilds (the questie import, --merge-learned): the class file stays listed and the recipe
        # keys stay numbers
        datapack.write_layer(self.pack, "questie", {"quests": {9: {"n": "Q"}}}, "test")
        datapack.build(self.pack, "test")
        self.assertIn("classes\\HUNTER.lua", (self.pack / "Signpost_Data.toc").read_text(encoding="utf-8"))
        professions = datapack.read_table(self.pack, "professions")
        self.assertEqual(professions[165]["recipes"][601]["reagents"], {702: 2})
        self.assertEqual(datapack.read_meta(self.pack)["tables"]["classes"], {"count": 1})


if __name__ == "__main__":
    unittest.main()
