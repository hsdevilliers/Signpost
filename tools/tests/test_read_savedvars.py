import json
import tempfile
import unittest
from pathlib import Path

import read_savedvars
from signpost_tools import svfiles


class ReadSavedVarsTest(unittest.TestCase):
    def test_json_handles_mixed_lua_keys(self):
        # e.g. the probe's packed results: { n = 2, [1] = false, [2] = "message" }
        self.assertEqual(
            json.loads(read_savedvars.to_json({"n": 2, 1: False, 2: "message"})),
            {"n": 2, "1": False, "2": "message"},
        )

    def test_finds_account_and_character_files_in_a_copied_folder(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "SavedVariables").mkdir()
            (root / "SavedVariables" / "Signpost.lua").write_text('SignpostDB = {\n["ping"] = {\n["text"] = "pong",\n},\n}\n')
            char_dir = root / "Realm" / "Char" / "SavedVariables"
            char_dir.mkdir(parents=True)
            (char_dir / "Signpost.lua").write_text("SignpostCharDB = {\n}\n")
            files = svfiles.find_files(root)
            self.assertEqual([(f.variable, f.owner) for f in files], [("SignpostDB", "account"), ("SignpostCharDB", "Char - Realm")])
            self.assertEqual(svfiles.load_db(files[0]), {"ping": {"text": "pong"}})
            self.assertEqual(svfiles.load_db(files[1]), {})

    def test_names_characters_in_the_forever_layout(self):
        # Forever keeps per-character files in <number>/<Character>-<Realm>/SavedVariables/
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            char_dir = root / "70" / "Name-Realm" / "SavedVariables"
            char_dir.mkdir(parents=True)
            (char_dir / "Signpost.lua").write_text("SignpostCharDB = {\n}\n")
            self.assertEqual([f.owner for f in svfiles.find_files(root)], ["account", "Name-Realm"])


if __name__ == "__main__":
    unittest.main()
