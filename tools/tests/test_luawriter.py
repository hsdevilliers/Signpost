import math
import unittest

from signpost_tools.luawriter import lua_string, to_lua
from signpost_tools.savedvars import parse_savedvars


class LuaWriterTest(unittest.TestCase):
    def roundtrip(self, value, **options):
        return parse_savedvars("X = " + to_lua(value, **options))["X"]

    def test_roundtrip(self):
        value = {
            787: {"n": "The Basics", "l": 1, "s": {"npc": [3143]}, "p": [[1411, 42.1, 68.3]]},
            "end": "keyword key",
            "with space": 'tab\t"quote"\nline',
            "utf8": "Orgrimmar – Valley",
            "float": 0.125,
            "flag": False,
        }
        self.assertEqual(self.roundtrip(value), value)
        self.assertEqual(self.roundtrip(value, expand_depth=3), value)

    def test_layout_is_sorted_and_expanded_at_the_top(self):
        self.assertEqual(to_lua({"b": 1, 10: {"x": 1}, 2: [1, 2]}), "{\n\t[2] = { 1, 2 },\n\t[10] = { x = 1 },\n\tb = 1,\n}")
        self.assertEqual(to_lua({}), "{}")

    def test_keys(self):
        self.assertEqual(to_lua({"end": 1, "ok_1": 2, "1x": 3}, expand_depth=0), '{ ["1x"] = 3, ["end"] = 1, ok_1 = 2 }')

    def test_strings(self):
        self.assertEqual(lua_string('a"b\\c\n\x01'), '"a\\"b\\\\c\\n\\001"')

    def test_rejects_holes_and_non_finite_numbers(self):
        with self.assertRaises(ValueError):
            to_lua([1, None, 3])
        with self.assertRaises(ValueError):
            to_lua(math.nan)
        with self.assertRaises(TypeError):
            to_lua({True: 1})


if __name__ == "__main__":
    unittest.main()
