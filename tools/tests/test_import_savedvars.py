import tempfile
import unittest
from pathlib import Path

import import_savedvars
from signpost_tools import datapack

DUMP = {
    "build": "70450",
    "maps": [
        {"id": 947, "name": "Azeroth", "type": 1, "parent": 946},
        {
            "id": 1411,
            "name": "Durotar",
            "type": 3,
            "parent": 1414,
            "world": {"instance": 1, "x0": -1000.5, "y0": 2000.25, "x1": -4000.0, "y1": -1000.0},
            "onParent": {"minX": 0.5, "maxX": 0.6, "minY": 0.3, "maxY": 0.5},
            "size": {"n": 0},
            "taxi": [{"id": 23, "name": "Orgrimmar", "x": 44.5, "y": 3.7, "faction": 1, "atlas": "TaxiNode"}],
        },
        {
            "id": 1414,
            "name": "Kalimdor",
            "type": 2,
            "parent": 947,
            "taxi": [{"id": 23, "name": "Orgrimmar", "x": 58.1, "y": 45.3, "faction": 1, "atlas": "TaxiNode"}],
        },
        {"id": 5, "error": "attempt to index a nil value"},
    ],
}


class MapsTableTest(unittest.TestCase):
    def test_converts_a_dump(self):
        maps = import_savedvars.maps_table(DUMP)
        self.assertEqual(sorted(maps), [947, 1411, 1414])
        self.assertEqual(maps[947], {"n": "Azeroth", "t": 1, "parent": 946})
        self.assertEqual(maps[1411]["world"], [1, -1000.5, 2000.25, -4000.0, -1000.0])
        self.assertEqual(maps[1411]["rect"], [0.5, 0.6, 0.3, 0.5])
        # flight nodes are kept once, on the continent
        self.assertNotIn("taxi", maps[1411])
        self.assertEqual(maps[1414]["taxi"], [{"id": 23, "n": "Orgrimmar", "x": 58.1, "y": 45.3, "faction": 1}])

class DataPackTest(unittest.TestCase):
    def test_build_merges_layers_field_by_field(self):
        with tempfile.TemporaryDirectory() as tmp:
            pack = Path(tmp)
            datapack.init_stub(pack)
            datapack.write_layer(pack, "client", {"maps": import_savedvars.maps_table(DUMP)}, "client dumpmaps")
            datapack.write_layer(
                pack,
                "questie",
                {"quests": {1: {"n": "One", "s": {"npc": [7]}}}, "npcs": {7: {"n": "Seven", "p": [[1411, 1, 2]]}}},
                "QuestieDB",
            )
            datapack.write_layer(
                pack,
                "wowhead",
                {"maps": {1411: {"wowhead": 14}}, "npcs": {7: {"p": [[1411, 3, 4]]}}},
                "Wowhead",
                ["quest page without Quick Facts: 9"],
            )
            counts = datapack.build(pack, "test")
            self.assertEqual(counts["maps"], 3)
            maps = datapack.read_table(pack, "maps")
            self.assertEqual((maps[1411]["n"], maps[1411]["wowhead"], maps[1411]["src"]), ("Durotar", 14, "client,wowhead"))
            npc = datapack.read_table(pack, "npcs")[7]
            self.assertEqual((npc["n"], npc["p"], npc["src"]), ("Seven", [[1411, 3, 4]], "questie,wowhead"))
            self.assertEqual(sorted(datapack.read_table(pack, "travel")), ["crossings", "flightMasters", "inns", "transports"])
            meta = datapack.read_meta(pack)
            self.assertEqual(meta["source"], "generated")
            self.assertEqual(meta["tables"]["quests"]["count"], 1)
            self.assertEqual(sorted(meta["layers"]), ["client", "questie", "wowhead"])
            gaps = (pack / "data-gaps.md").read_text(encoding="utf-8")
            self.assertIn("Quests without an end (1)", gaps)
            self.assertIn("quest page without Quick Facts: 9", gaps)
            with self.assertRaises(RuntimeError):
                datapack.init_stub(pack)  # refuses to wipe generated data

    def test_unknown_layer_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp, self.assertRaises(ValueError):
            datapack.write_layer(Path(tmp), "elsewhere", {}, "nowhere")


if __name__ == "__main__":
    unittest.main()
