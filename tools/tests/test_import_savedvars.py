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
            "taxi": [{"id": 23, "name": "Orgrimmar", "x": 45.1, "y": 63.9, "faction": 1, "atlas": "TaxiNode"}],
        },
        {"id": 5, "error": "attempt to index a nil value"},
    ],
}


class MapsTableTest(unittest.TestCase):
    def test_converts_a_dump(self):
        maps = import_savedvars.maps_table(DUMP)
        self.assertEqual(sorted(maps), [947, 1411])
        self.assertEqual(maps[947], {"n": "Azeroth", "t": 1, "parent": 946})
        self.assertEqual(maps[1411]["world"], [1, -1000.5, 2000.25, -4000.0, -1000.0])
        self.assertEqual(maps[1411]["rect"], [0.5, 0.6, 0.3, 0.5])
        self.assertEqual(maps[1411]["taxi"], [{"id": 23, "n": "Orgrimmar", "x": 45.1, "y": 63.9, "faction": 1}])

    def test_keeps_wowhead_zone_ids(self):
        maps = import_savedvars.maps_table(DUMP, {1411: {"n": "Durotar", "wowhead": 14}})
        self.assertEqual(maps[1411]["wowhead"], 14)


class DataPackTest(unittest.TestCase):
    def test_update_table_writes_the_file_and_meta(self):
        with tempfile.TemporaryDirectory() as tmp:
            pack = Path(tmp)
            datapack.init_stub(pack)
            maps = import_savedvars.maps_table(DUMP)
            datapack.update_table(pack, "Maps.lua", maps, "test", "client dumpmaps, build 70450")
            self.assertEqual(datapack.read_table(pack, "Maps.lua"), maps)
            meta = datapack.read_meta(pack)
            self.assertEqual(meta["source"], "generated")
            self.assertEqual(meta["tables"]["maps"]["count"], 2)
            with self.assertRaises(RuntimeError):
                datapack.init_stub(pack)  # refuses to wipe generated data


if __name__ == "__main__":
    unittest.main()
