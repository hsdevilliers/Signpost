"""lua_corrections: the static reader of QuestieDB's correction providers, against synthetic files (no real data)."""

import tempfile
import unittest
from collections import Counter
from pathlib import Path

from signpost_tools import lua_corrections as lc
from tests import forever_fixtures as fx
from tests.test_questie_import import make_checkout


def value_of(text: str, roots: dict | None = None) -> object:
    parser = lc.Parser(lc.tokenize(text))
    node = parser.expr()
    assert parser.peek()[0] == "eof", text
    return lc.evaluate(node, lc.Scope(roots or {}))


class ExpressionTest(unittest.TestCase):
    def test_literals_comments_and_nil_holes(self):
        self.assertEqual(value_of('{nil, nil, {{277653}}} -- trailing comment'), [None, None, [[277653]]])
        self.assertEqual(value_of("{{1}, nil}"), [[1], None])
        self.assertEqual(value_of("{--[[ block\ncomment ]] 1, 2.5, 0x10, -3}"), [1, 2.5, 16, -3])
        self.assertEqual(value_of(r'"a\"b\n"'), 'a"b\n')
        self.assertEqual(value_of("[[long\nstring]]"), "long\nstring")
        self.assertEqual(value_of("{true, false}"), [True, False])

    def test_keyed_tables_become_dicts(self):
        self.assertEqual(value_of("{[501] = {{40, 70.5}}, name = 'x', 7}"), {501: [[40, 70.5]], "name": "x", 1: 7})

    def test_named_constants_and_sums(self):
        roots = {"raceIDs": {"ORC": 2, "ALL_HORDE": 8589934770}, "zoneIDs": {"DUROTAR": 14}, "ids": {1: 5}}
        self.assertEqual(value_of("raceIDs.ORC + raceIDs.ALL_HORDE", roots), 8589934772)
        self.assertEqual(value_of("{[zoneIDs.DUROTAR] = {{1, 2}}}", roots), {14: [[1, 2]]})
        self.assertEqual(value_of("ids[1] * 2 - 1", roots), 9)

    def test_unresolvable_is_an_error_not_a_guess(self):
        roots = {"zoneIDs": {"DUROTAR": 14}}
        for text, reason in (
            ("zoneIDs.NOPE", "unresolved constant zoneIDs.NOPE"),
            ("missing.thing", "unresolved name missing"),
            ("function() return 1 end", "function value"),
            ("UnitFactionGroup('Player')", "call to UnitFactionGroup"),
            ("zoneIDs.DUROTAR == 14", "operator =="),
            ("'a' .. 'b'", "operator .."),
            ("'a' + 1", "operator + on non-numbers"),
            ("{1, zoneIDs.NOPE}", "unresolved constant zoneIDs.NOPE"),
        ):
            with self.subTest(text=text), self.assertRaises(lc.Unresolved) as caught:
                value_of(text, roots)
            self.assertEqual(caught.exception.reason, reason)

    def test_l10n_is_the_identity_on_its_text(self):
        self.assertEqual(value_of('l10n("Take the portal")'), "Take the portal")


class EnvironmentTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.root = fx.make_layered_checkout(Path(cls.tmp.name) / "q")
        cls.env = lc.load_environment(cls.root)

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def test_constants_come_from_the_enum_files(self):
        db = self.env.roots["QuestieDB"]
        self.assertEqual(db["raceKeys"]["ALL_HORDE"], 2 + 16 + 32 + 128 + 8589934592)  # classic Horde + the Skyborne bit
        self.assertEqual(db["raceKeys"]["SKYBORNE_ALLIANCE"], 4294967296)
        self.assertEqual(db["classKeys"]["HUNTER"], 4)  # Forever has no classKeys: the Classic table, as QuestieDB's compat does
        self.assertEqual(db["npcFlags"]["QUEST_GIVER"], 2)  # Forever's own npcFlags
        self.assertEqual(db["sortKeys"]["HUNTER"], -261)
        self.assertEqual(self.env.roots["ZoneDB"]["zoneIDs"]["ZEPHYR"], 507)
        self.assertEqual(self.env.roots["Questie"]["ICON_TYPE_TALK"], 5)
        self.assertEqual(self.env.shapes["quest"]["startedBy"], "questgivers")
        self.assertEqual(self.env.shapes["npc"]["spawns"], "spawnlist")
        self.assertEqual(self.env.skipped, Counter())

    def test_field_keys_and_operations(self):
        keys = self.env.roots["QuestieDB"]["questKeys"]
        self.assertEqual(keys.field("name"), lc.FieldRef("quest", "name", "set"))
        self.assertEqual(keys.field("finishedBy_add"), lc.FieldRef("quest", "finishedBy", "add"))
        self.assertEqual(keys.field("preQuestSingle_remove"), lc.FieldRef("quest", "preQuestSingle", "remove"))
        with self.assertRaises(lc.Unresolved):
            keys.field("noSuchField_add")

    def test_missing_pieces_are_format_errors(self):
        with tempfile.TemporaryDirectory() as tmp, self.assertRaises(lc.CorrectionsFormatError):
            lc.load_environment(Path(tmp))
        with tempfile.TemporaryDirectory() as tmp:
            root = fx.add_forever_layers(make_checkout(Path(tmp) / "q"))
            (root / "src" / "corrections" / "enum" / "zones.lua").unlink()
            with self.assertRaises(lc.CorrectionsFormatError):
                lc.load_environment(root)


class ProviderTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.root = fx.make_layered_checkout(Path(cls.tmp.name) / "q")
        cls.env = lc.load_environment(cls.root)
        cls.forever = cls.root / "src" / "corrections" / "Forever"

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def read(self, name: str, kind: str = "quest") -> lc.ProviderResult:
        return lc.read_provider(self.forever / name, self.env, kind)

    def test_delta_base_quest_records(self):
        result = self.read("generated/foreverBaseQuest.lua")
        self.assertEqual(sorted(result.records), [1, 50, 51, 52, 53])
        ref = lambda name, op="set": lc.FieldRef("quest", name, op)  # noqa: E731
        start = result.records[50]
        self.assertEqual(start[ref("name")], "Windshaper Start")
        self.assertEqual(start[ref("requiredRaces")], 8589934770)  # raceIDs.ALL_HORDE, resolved from the enum files
        self.assertEqual(start[ref("zoneOrSort")], 507)
        self.assertEqual(start[ref("objectives")], [None, None, [[300]]])  # nil holes kept
        self.assertEqual(start[ref("startedBy")], [[120]])
        self.assertEqual(result.records[1], {ref("questLevel"): 5})
        self.assertEqual(result.skipped, Counter())
        self.assertTrue(result.found_load)

    def test_operation_keys_and_holes(self):
        result = self.read("traces/foreverQuestTraces.lua")
        ref = lambda name, op: lc.FieldRef("quest", name, op)  # noqa: E731
        self.assertEqual(result.records[1][ref("finishedBy", "add")], [[102]])
        self.assertEqual(result.records[2][ref("startedBy", "add")], [None, [200]])

    def test_every_unreadable_construct_is_skipped_and_counted_by_reason(self):
        result = self.read("foreverQuestFixes.lua")
        self.assertEqual(
            result.skipped,
            Counter(
                {
                    "unresolved constant zoneIDs.NO_SUCH_ZONE": 1,
                    "call to string.format": 1,
                    "function value": 1,
                    "operator ..": 1,
                    "unknown quest field noSuchField": 1,
                    "unresolved constant Questie.UNKNOWN_TEXT": 1,
                    "unparsable entry (unexpected token in an expression)": 1,
                    "runtime function LoadDynamic (not read)": 1,  # its faction branch is never evaluated
                    "top-level runtime statement (not read)": 1,
                }
            ),
        )
        ref = lambda name: lc.FieldRef("quest", name, "set")  # noqa: E731
        # what is static and resolvable in the same records survives next to the skipped fields
        self.assertEqual(result.records[2][ref("requiredLevel")], 9)
        self.assertEqual(result.records[2][ref("requiredRaces")], 2 + 128)
        self.assertEqual(result.records[3][ref("objectives")], [[[259377, None, 5]]])
        self.assertNotIn(ref("zoneOrSort"), result.records[3])
        self.assertNotIn(ref("name"), result.records[3])
        self.assertNotIn(ref("startedBy"), result.records[3])
        # the dynamic function's literal (questLevel 40) was not read
        self.assertNotIn(ref("questLevel"), result.records[1])

    def test_a_field_key_of_another_kind_is_skipped(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "p.lua"
            path.write_text(
                fx.provider(
                    "M",
                    fx.QUEST_ALIASES + "\n    local npcKeys = QuestieDB.npcKeys",
                    "[7] = { [npcKeys.name] = 'x', [questKeys.name] = 'y' },\n[0] = {},\n[8] = 5,\n[bad] = {},",
                ),
                encoding="utf-8",
            )
            result = lc.read_provider(path, self.env, "quest")
        self.assertEqual(result.records, {7: {lc.FieldRef("quest", "name", "set"): "y"}})
        self.assertEqual(
            result.skipped,
            Counter(
                {
                    "key that is not a quest field": 1,
                    "record key that is not a positive integer": 1,
                    "record that is not a table constructor": 1,
                    "record key: unresolved name bad": 1,
                }
            ),
        )

    def test_a_provider_without_a_static_table(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "p.lua"
            path.write_text("function M:Load()\n    return build()\nend\n", encoding="utf-8")
            result = lc.read_provider(path, self.env, "quest")
        self.assertEqual(result.records, {})
        self.assertEqual(result.skipped["return that is not a literal table"], 1)


if __name__ == "__main__":
    unittest.main()
