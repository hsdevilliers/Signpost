import math
import unittest

from signpost_tools.savedvars import LuaParseError, parse_savedvars

# Shaped like the client's own SavedVariables output: ["key"] fields, `-- [n]` array comments, trailing commas.
CLIENT_OUTPUT = r"""
SignpostDB = {
["settings"] = {
},
["errors"] = {
{
["msg"] = "Interface/AddOns/Signpost/Core/Probe.lua:12: attempt to index a nil value",
["count"] = 2,
["ours"] = true,
["stack"] = "line one\nline two",
}, -- [1]
},
["lastLoad"] = {
["interface"] = 16001,
["build"] = "70450",
["time"] = 1790000000,
},
["eventLog"] = {
{
["e"] = "UI_INFO_MESSAGE",
["a"] = {
["n"] = 2,
1, -- [1]
"Boar slain: 1/10", -- [2]
},
["t"] = 100.5,
}, -- [1]
},
["negative"] = -5,
["small"] = 1.5e-05,
["quote"] = "say \"hi\" \\ ok",
["utf8"] = "Orgrimmar – Valley of Strength",
["bytes"] = "\226\128\147",
[1411] = "Durotar",
}
SignpostCharDB = nil
"""


class ClientOutputTest(unittest.TestCase):
    def setUp(self):
        self.data = parse_savedvars(CLIENT_OUTPUT)

    def test_variables(self):
        self.assertEqual(set(self.data), {"SignpostDB", "SignpostCharDB"})
        self.assertIsNone(self.data["SignpostCharDB"])

    def test_values(self):
        db = self.data["SignpostDB"]
        self.assertEqual(db["settings"], {})
        self.assertEqual(db["lastLoad"], {"interface": 16001, "build": "70450", "time": 1790000000})
        self.assertEqual(db["negative"], -5)
        self.assertAlmostEqual(db["small"], 1.5e-05)
        self.assertEqual(db["quote"], 'say "hi" \\ ok')
        self.assertEqual(db["utf8"], "Orgrimmar – Valley of Strength")
        self.assertEqual(db["bytes"], "–")
        self.assertEqual(db[1411], "Durotar")

    def test_arrays_become_lists(self):
        errors = self.data["SignpostDB"]["errors"]
        self.assertIsInstance(errors, list)
        self.assertEqual(errors[0]["stack"], "line one\nline two")
        self.assertIs(errors[0]["ours"], True)

    def test_mixed_tables_stay_dicts(self):
        args = self.data["SignpostDB"]["eventLog"][0]["a"]
        self.assertEqual(args, {"n": 2, 1: 1, 2: "Boar slain: 1/10"})


class SyntaxTest(unittest.TestCase):
    def test_lua_literal_forms(self):
        data = parse_savedvars(
            """
            --[[ block
            comment ]] X = { 'single', [==[long ]] string]==], name = true, [3] = 0x10; nested = { [2] = 1 } }
            """
        )
        self.assertEqual(
            data["X"], {1: "single", 2: "long ]] string", "name": True, 3: 16, "nested": {2: 1}}
        )

    def test_explicit_sequence_is_a_list(self):
        self.assertEqual(parse_savedvars("X = { [2] = 'b', [1] = 'a' }")["X"], ["a", "b"])

    def test_special_numbers(self):
        data = parse_savedvars("A = inf B = -1.#INF C = nan")
        self.assertEqual(data["A"], math.inf)
        self.assertEqual(data["B"], -math.inf)
        self.assertTrue(math.isnan(data["C"]))

    def test_errors_carry_line_numbers(self):
        with self.assertRaisesRegex(LuaParseError, "line 3"):
            parse_savedvars("X = {\n  1,\n  2 3\n}")
        with self.assertRaises(LuaParseError):
            parse_savedvars('X = "unterminated')


if __name__ == "__main__":
    unittest.main()
