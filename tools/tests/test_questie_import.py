"""questie_import.py against a small synthetic checkout shaped like QuestieDB's Forever files.

Every name, ID and coordinate here is made up. The fixture's field positions also differ from QuestieDB's on purpose:
the importer must take them from the key tables (and the commented part positions under a key), never from constants.
"""

import json
import tempfile
import unittest
from pathlib import Path

import questie_import as qi
from signpost_tools import datapack

QUEST_LAYOUT = [
    "zoneOrSort", "name", "questLevel", "requiredLevel", "requiredRaces", "requiredClasses", "finishedBy", "startedBy",
    "objectivesText", "objectives", "triggerEnd", "sourceItemId", "preQuestGroup", "preQuestSingle", "exclusiveTo",
    "requiredSkill", "requiredSourceItems", "nextQuestInChain", "specialFlags", "parentQuest", "breadcrumbForQuestId",
    "requiredMaxLevel", "extraObjectives",
]
QUEST_PARTS = {
    "startedBy": ["itemStart", "creatureStart", "objectStart"],
    "finishedBy": ["objectEnd", "creatureEnd"],
    "objectives": [
        "itemObjective", "creatureObjective", "objectObjective", "reputationObjective", "killCreditObjective",
        "spellObjective",
    ],
}
NPC_LAYOUT = ["spawns", "name", "minLevel", "friendlyToFaction", "subName", "npcFlags", "rank"]
OBJECT_LAYOUT = ["name", "questStarts", "questEnds", "spawns", "zoneID"]
ITEM_LAYOUT = ["name", "itemLevel", "npcDrops", "objectDrops", "startQuest", "vendors", "class"]

# Lua literals per field. startedBy is {item, creature, object} and finishedBy {object, creature} in this layout;
# objectives are {item, creature, object, reputation, killCredit, spell}. AreaIDs: 501 and 505 lie on map 1411, 502 on
# 1413, 503 on 1429, 504 is suppressed, 506 is an instance, and 1 (whose table parses as a Lua list) lies on 1418.
QUESTS = {
    1: {  # a Horde zone quest: kill and collect
        "name": '"Boar Cull"', "zoneOrSort": "501", "questLevel": "2", "requiredLevel": "1", "requiredRaces": "178",
        "startedBy": "{nil,{100}}", "finishedBy": "{nil,{100}}", "objectivesText": '{"Kill 8 boars"}',
        "objectives": '{{{300,"Collect the tusks"}},{{101}}}', "preQuestSingle": "{40}", "nextQuestInChain": "2",
    },
    2: {  # a class quest filed under a QuestSort, with every chain field
        "name": '"Beast Lessons"', "zoneOrSort": "-999", "questLevel": "10", "requiredLevel": "10",
        "requiredRaces": "130", "requiredClasses": "4", "startedBy": "{nil,{102}}", "finishedBy": "{nil,{102}}",
        "sourceItemId": "301", "specialFlags": "1", "requiredSkill": "{999,1}", "parentQuest": "1",
        "breadcrumbForQuestId": "3", "requiredMaxLevel": "20", "preQuestGroup": "{5,1}", "exclusiveTo": "{6}",
    },
    3: {  # neutral, started by an object, with an explore objective
        "name": '"Posted Bounty"', "zoneOrSort": "502", "questLevel": "12", "requiredLevel": "10",
        "requiredRaces": "0", "startedBy": "{nil,nil,{200}}", "finishedBy": "{nil,{105}}",
        "objectives": '{nil,nil,{{201,"Open the chest"}}}',
        "triggerEnd": '{"Scout the camp",{[502]={{30,40},{30.5,40.2}}}}',
    },
    4: {  # race-neutral, but only an Alliance NPC starts it
        "name": '"Alliance by its giver"', "zoneOrSort": "503", "requiredRaces": "0",
        "startedBy": "{nil,{109}}", "finishedBy": "{nil,{109}}",
    },
    5: {  # started by an item nobody drops, in a sub-zone
        "name": '"Gift Card"', "zoneOrSort": "505", "questLevel": "1", "requiredLevel": "1", "requiredRaces": "130",
        "startedBy": "{{302}}", "finishedBy": "{nil,{100}}",
    },
    6: {
        "name": '"Alliance quest"', "zoneOrSort": "503", "requiredRaces": "77",
        "startedBy": "{nil,{109}}", "finishedBy": "{nil,{109}}",
    },
    7: {  # suppressed zone; a cloth objective with many drop sources; a required source item
        "name": '"Cloth for the cause"', "zoneOrSort": "504", "requiredRaces": "178",
        "startedBy": "{nil,{107}}", "finishedBy": "{nil,{104}}", "objectives": "{{{303}}}",
        "requiredSourceItems": "{305}",
    },
    8: {  # instance quest: the giver is inside the instance and nobody ends it
        "name": '"Into the deep"', "zoneOrSort": "506", "requiredRaces": "0", "startedBy": "{nil,{106}}",
    },
    9: {  # kill credit and spell objectives; race-neutral, but only a Horde NPC starts it
        "name": '"Credit where due"', "zoneOrSort": "501", "requiredRaces": "0",
        "startedBy": "{nil,{100}}", "finishedBy": "{nil,{100}}",
        "objectives": '{nil,nil,nil,nil,{{{101,107},101,"Boars slain"}},{{1234,"Use the rod",301}}}',
    },
    10: {  # a race bit outside the Classic races
        "name": '"New race"', "zoneOrSort": "501", "requiredRaces": "256",
        "startedBy": "{nil,{100}}", "finishedBy": "{nil,{100}}",
    },
}
NPCS = {
    100: {"name": "'Quest Giver'", "spawns": "{[501]={{40,70}}}", "friendlyToFaction": '"H"', "npcFlags": "3"},
    101: {
        "name": "'Field Boar'",
        "spawns": "{[501]={{44,61},{44.5,61.5},{45,61},{60,60},{60.5,60.2}},[502]={{10,10}}}",
        "friendlyToFaction": '"AH"',
        "npcFlags": "0",
    },
    102: {
        "name": "'Beast Trainer'", "spawns": "{[501]={{50,40}}}", "friendlyToFaction": '"H"',
        "subName": '"Class Trainer"', "npcFlags": "19",
    },
    103: {
        "name": "'Alliance Vendor'", "spawns": "{[503]={{40,40}}}", "friendlyToFaction": '"A"',
        "subName": '"General Goods"', "npcFlags": "4",
    },
    104: {
        "name": "'Innkeeper Ana'", "spawns": "{[501]={{52,41}}}", "friendlyToFaction": '"H"',
        "subName": '"Innkeeper"', "npcFlags": "135",
    },
    105: {
        "name": "'Goblin Vendor'", "spawns": "{[502]={{62,37}}}", "friendlyToFaction": '"AH"',
        "subName": '"Trade Supplies"', "npcFlags": "6",
    },
    106: {"name": "'Instance Boss'", "spawns": "{[506]={{-1,-1}}}", "npcFlags": "0"},
    107: {"name": "'Cave Bear'", "spawns": "{[1]={{20,20},{20.5,20}}}", "npcFlags": "0", "rank": "1"},
    108: {
        "name": "'Hidden Vendor'", "spawns": "{[506]={{-1,-1}}}", "friendlyToFaction": '"H"',
        "subName": '"Food & Drink"', "npcFlags": "4",
    },
    109: {"name": "'Alliance Giver'", "spawns": "{[503]={{30,30}}}", "friendlyToFaction": '"A"', "npcFlags": "2"},
    110: {"name": "'Trogg A'", "spawns": "{[1]={{30,30}}}"},
    111: {"name": "'Trogg B'", "spawns": "{[1]={{31,31}}}"},
    112: {"name": "'Raider A'", "spawns": "{[502]={{40,40}}}"},
    113: {"name": "'Raider B'", "spawns": "{[502]={{41,41}}}"},
    114: {"name": "'Raider C'", "spawns": "{[502]={{42,42}}}"},
    115: {"name": "'Raider D'", "spawns": "{[502]={{43,43}}}"},
}
OBJECTS = {
    200: {"name": '"Bounty Board"', "questStarts": "{3}", "spawns": "{[502]={{50,50}}}", "zoneID": "502"},
    201: {"name": '"Chest"', "spawns": "{[501]={{20,20}}}", "zoneID": "501"},
    202: {"name": '"Unrelated Object"', "spawns": "{[501]={{1,1}}}", "zoneID": "501"},
}
ITEMS = {
    300: {"name": "'Boar Tusk'", "npcDrops": "{101}", "itemLevel": "3", "class": "12"},
    301: {"name": "'Lesson Rod'"},
    302: {"name": "'Gift Voucher'"},
    303: {"name": "'Cloth'", "npcDrops": "{110,111,112,113,114,115}", "vendors": "{103,105}"},
    304: {"name": "'Unrelated Sword'", "itemLevel": "10", "class": "2"},
    305: {"name": "'Needed Tool'", "vendors": "{105,103}", "objectDrops": "{201}"},
}
ZONES = """-- synthetic zone tables (the comments and the code around them are ignored)
local ZoneDB = QuestieLoader:ImportModule("ZoneDB")

---@type string
ZoneDB.private.areaIdToUiMapIdOverride = [[return {
    [0] = 0, -- fail-safe
    [504] = 0, -- suppressed
    [506] = 9001, -- an instance
}]]

---@type string
ZoneDB.private.areaIdToUiMapId = [[return {
    [1] = 1418,
    [501] = 1411,
    [502] = 1413,
    [503] = 1429,
    [504] = 1413,
    [505] = 1411, -- a sub-zone of 501
}]]
"""
SHA = "0123456789abcdef0123456789abcdef01234567"
BUILD = "1.2.3.4"
TEXTS = ("Kill 8 boars", "Collect the tusks", "Open the chest", "Scout the camp", "Boars slain", "Use the rod")


def keys_text(kind: str, layout: list[str], parts: dict | None = None) -> str:
    lines = [f"QuestieDB.{kind}Keys = {{"]
    for index, name in enumerate(layout, 1):
        lines.append(f"    ['{name}'] = {index}, -- a comment with {{braces}}")
        for part_index, part_name in enumerate((parts or {}).get(name, ()), 1):
            lines.append(f"        --['{part_name}'] = {part_index}, -- a part, {{also with braces}}")
    return "\n".join(lines + ["}"])


def db_file(kind: str, layout: list[str], records: dict, parts: dict | None = None) -> str:
    rows = "\n".join(
        f"[{ident}] = {{{','.join(values.get(name, 'nil') for name in layout)}}}," for ident, values in records.items()
    )
    return (
        "-- synthetic fixture\n\n"
        'local QuestieDB = QuestieLoader:ImportModule("QuestieDB");\n'
        'error("this file is data to the importer and must never run")\n\n'
        f"{keys_text(kind, layout, parts)}\n\nQuestieDB.{kind}Data = [[return {{\n{rows}\n}}]]\n"
    )


def make_checkout(root: Path, quests: dict = QUESTS, quest_keys: str | None = None) -> Path:
    forever = root / "data" / "Forever"
    forever.mkdir(parents=True)
    quest_file = db_file("quest", QUEST_LAYOUT, quests, QUEST_PARTS)
    if quest_keys is not None:
        quest_file = quest_file.replace(keys_text("quest", QUEST_LAYOUT, QUEST_PARTS), quest_keys)
    (forever / "foreverQuestDB.lua").write_text(quest_file, encoding="utf-8")
    (forever / "foreverNpcDB.lua").write_text(db_file("npc", NPC_LAYOUT, NPCS), encoding="utf-8")
    (forever / "foreverObjectDB.lua").write_text(db_file("object", OBJECT_LAYOUT, OBJECTS), encoding="utf-8")
    (forever / "foreverItemDB.lua").write_text(db_file("item", ITEM_LAYOUT, ITEMS), encoding="utf-8")
    zones = root / "support" / "Forever" / "Zones"
    zones.mkdir(parents=True)
    (zones / "areaIdToUiMapId.lua").write_text(ZONES, encoding="utf-8")
    (root / "support" / "Forever" / "provenance.json").write_text(
        json.dumps({"dbc_report": {"build": BUILD}}), encoding="utf-8"
    )
    git = root / ".git"
    git.mkdir()
    (git / "HEAD").write_text("ref: refs/heads/forever\n", encoding="utf-8")
    (git / "packed-refs").write_text(f"# pack-refs with: peeled\n{SHA} refs/heads/forever\n", encoding="utf-8")
    return root


class ImportTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.root = make_checkout(Path(cls.tmp.name) / "questiedb")
        cls.questie = qi.load(cls.root)
        cls.importer = qi.Importer(cls.questie, max_drops=3)
        cls.tables = cls.importer.run()

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def test_positions_come_from_the_key_tables(self):
        self.assertEqual(self.questie.keys["quest"]["zoneOrSort"], 1)
        self.assertEqual(self.questie.keys["npc"]["spawns"], 1)
        self.assertEqual(self.questie.parts["startedBy"], {"itemStart": 1, "creatureStart": 2, "objectStart": 3})
        self.assertEqual(self.questie.parts["objectives"]["killCreditObjective"], 5)
        self.assertEqual(self.questie.area_maps[504], 0)  # the override wins, 0 is kept as "suppressed"
        self.assertEqual((self.questie.commit, self.questie.build), (SHA[:10], BUILD))

    def test_horde_layer_keeps_horde_and_neutral_quests(self):
        quests = self.tables["quests"]
        self.assertEqual(sorted(quests), [1, 2, 3, 5, 7, 8, 9])
        self.assertEqual(quests[3]["side"], "both")
        self.assertEqual(quests[8]["side"], "both")  # its giver is friendly to neither faction
        self.assertEqual(quests[9]["side"], "Horde")  # race-neutral, but only a Horde NPC starts it

    def test_zone_quest(self):
        self.assertEqual(
            self.tables["quests"][1],
            {
                "n": "Boar Cull",
                "side": "Horde",
                "l": 2,
                "r": 1,
                "races": 178,
                "zone": 1411,
                "s": {"npc": [100]},
                "e": {"npc": [100]},
                "o": [{"k": "kill", "id": 101}, {"k": "item", "id": 300}],
                "preSingle": [40],
                "next": 2,
            },
        )

    def test_class_quest_with_chain_fields(self):
        self.assertEqual(
            self.tables["quests"][2],
            {
                "n": "Beast Lessons",
                "side": "Horde",
                "l": 10,
                "r": 10,
                "maxLevel": 20,
                "races": 130,
                "classes": 4,
                "sort": 999,
                "s": {"npc": [102]},
                "e": {"npc": [102]},
                "preGroup": [1, 5],
                "exclusive": [6],
                "parent": 1,
                "breadcrumbFor": 3,
                "skill": [999, 1],
                "repeatable": True,
                "gives": 301,
            },
        )

    def test_objects_explore_kill_credit_and_spell_objectives(self):
        quests = self.tables["quests"]
        self.assertEqual(quests[3]["s"], {"obj": [200]})
        self.assertEqual(quests[3]["o"], [{"k": "object", "id": 201}, {"k": "explore", "p": [[1413, 30, 40]]}])
        self.assertEqual(
            quests[9]["o"],
            [{"k": "kill", "id": 101, "credit": [101, 107]}, {"k": "spell", "id": 1234, "item": 301}],
        )
        self.assertEqual(quests[5]["s"], {"item": [302]})
        self.assertEqual(quests[5]["zone"], 1411)  # a sub-zone AreaID resolves to its zone's map
        self.assertEqual(quests[8]["zone"], 9001)  # the override's instance map
        self.assertNotIn("zone", quests[7])  # suppressed
        self.assertEqual(quests[7]["needs"], [305])

    def test_no_text_and_no_stats(self):
        dumped = json.dumps(self.tables)
        for text in TEXTS:
            self.assertNotIn(text, dumped)
        self.assertNotIn("Unrelated", dumped)
        fields = {key for table in self.tables.values() for record in table.values() for key in record}
        self.assertEqual(
            fields - {"n", "side", "p", "s", "e", "o", "zone", "sort", "l", "r", "races", "classes"},
            {
                "next", "preSingle", "preGroup", "exclusive", "parent", "breadcrumbFor", "skill", "maxLevel",
                "repeatable", "gives", "needs", "flags", "sub", "quest", "drops", "objDrops", "vendors", "many", "rank", "sp",
            },
        )

    def test_npcs(self):
        npcs = self.tables["npcs"]
        self.assertEqual(sorted(npcs), [100, 101, 102, 104, 105, 106, 107, 110, 111])
        self.assertEqual(npcs[100], {"n": "Quest Giver", "side": "Horde", "p": [[1411, 40, 70]]})
        # clustered per map, the map with most spawns first, a real spawn point per cluster
        self.assertEqual(npcs[101]["p"], [[1411, 44.5, 61.5], [1411, 60, 60], [1413, 10, 10]])
        self.assertEqual(npcs[101]["side"], "both")
        trainer = {"n": "Beast Trainer", "side": "Horde", "p": [[1411, 50, 40]], "flags": 16, "sub": "Class Trainer"}
        self.assertEqual(npcs[102], trainer)
        self.assertEqual((npcs[104]["flags"], npcs[104]["sub"]), (qi.INNKEEPER | qi.VENDOR, "Innkeeper"))
        self.assertEqual((npcs[105]["flags"], npcs[105]["side"]), (qi.VENDOR, "both"))
        self.assertEqual(npcs[106], {"n": "Instance Boss", "side": "none"})  # only inside an instance
        self.assertEqual(npcs[107]["p"], [[1418, 20, 20]])  # AreaID 1 (the table parsed as a list)
        self.assertEqual(npcs[107]["rank"], 1)  # an elite keeps its rank; a normal creature has none
        self.assertNotIn("rank", npcs[101])
        self.assertEqual(npcs[107]["sp"], 2)  # every spawn point is counted, though the position is one cluster
        self.assertEqual(npcs[101]["sp"], 6)
        self.assertNotIn("sp", npcs[102])  # a single spawn has no count

    def test_items(self):
        items = self.tables["items"]
        self.assertEqual(sorted(items), [300, 301, 302, 303, 305])
        self.assertEqual(items[300], {"n": "Boar Tusk", "drops": [101]})
        self.assertEqual(items[301], {"n": "Lesson Rod"})
        self.assertEqual(items[302], {"n": "Gift Voucher", "quest": 5})
        # 6 sources > max_drops 3: only those on the quest's maps (where its giver stands), and the total
        self.assertEqual(items[303], {"n": "Cloth", "drops": [110, 111], "many": 6, "vendors": [105]})
        self.assertEqual(items[305], {"n": "Needed Tool", "objDrops": [201], "vendors": [105]})

    def test_objects(self):
        objects = self.tables["objects"]
        self.assertEqual(
            objects, {200: {"n": "Bounty Board", "p": [[1413, 50, 50]]}, 201: {"n": "Chest", "p": [[1411, 20, 20]]}}
        )

    def test_problems(self):
        self.assertEqual(
            self.importer.problem_lines(),
            [
                "AreaIDs without a uiMapID (1): 504",
                "quests whose race mask has no Classic or Skyborne race bit (1): 10",
                "quests whose start has no position (2): 5, 8",
                "quests whose zone AreaID has no uiMapID (1): 7",
                "quests without an end entity (1): 8",
            ],
        )

    def test_other_factions(self):
        both = qi.Importer(self.questie, faction="both", max_drops=3).run()
        self.assertEqual(sorted(both["quests"]), list(range(1, 11)))
        self.assertNotIn("side", both["quests"][10])
        self.assertEqual(both["quests"][4]["side"], "Alliance")
        self.assertIn(103, both["npcs"])  # the Alliance vendor is a service NPC of "both"
        self.assertNotIn(108, both["npcs"])  # a service NPC without a position
        alliance = qi.Importer(self.questie, faction="alliance").run()
        self.assertEqual(sorted(alliance["quests"]), [3, 4, 6, 8])
        self.assertEqual(alliance["npcs"][103]["flags"], qi.VENDOR)
        self.assertNotIn(102, alliance["npcs"])  # the Horde trainer


class ScriptedTest(unittest.TestCase):
    """QuestieDB's specialFlags: bit 1 repeatable, bit 2 "needs event" (the quest is completed by a script: an escort, an ambush)."""

    def quests(self, flags: dict[int, str]) -> dict:
        found = {}
        for number, (qid, value) in enumerate(flags.items()):
            found[qid] = {
                "name": f'"Quest {qid}"', "zoneOrSort": "501", "questLevel": "5", "requiredLevel": "1", "requiredRaces": "178",
                "startedBy": "{nil,{100}}", "finishedBy": "{nil,{102}}", "specialFlags": value,
            }
            if number == 0:
                found[qid]["objectives"] = "{{{300}},{{101}}}"  # a quest with objectives and the flag keeps both
        return found

    def test_the_needs_event_bit_is_kept_as_scripted(self):
        flags = {11: "2", 12: "3", 13: "1", 14: "0", 15: "4", 16: "nil"}
        with tempfile.TemporaryDirectory() as tmp:
            root = make_checkout(Path(tmp) / "questiedb", self.quests(flags))
            quests = qi.Importer(qi.load(root), max_drops=3).run()["quests"]
        self.assertEqual({qid: record.get("scripted", False) for qid, record in quests.items()}, {11: True, 12: True, 13: False, 14: False, 15: False, 16: False})
        self.assertEqual({qid: record.get("repeatable", False) for qid, record in quests.items()}, {11: False, 12: True, 13: True, 14: False, 15: False, 16: False})
        self.assertEqual(quests[11]["o"], [{"k": "kill", "id": 101}, {"k": "item", "id": 300}])  # the flag does not replace objectives
        self.assertNotIn("o", quests[12])  # an escort or an event: the data lists no objective for it
        self.assertNotIn("scripted", quests[13])


class BuildTest(unittest.TestCase):
    def test_import_layer_writes_the_layer_and_builds_the_pack(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = make_checkout(Path(tmp) / "questiedb")
            pack = Path(tmp) / "pack"
            datapack.init_stub(pack)
            importer, counts = qi.import_layer(root, pack, max_drops=3)
            self.assertEqual((counts["quests"], counts["npcs"], counts["objects"], counts["items"]), (7, 9, 2, 5))
            layer = json.loads((pack / "layers" / "questie.json").read_text(encoding="utf-8"))
            self.assertIn(f"QuestieDB {SHA[:10]}: a Classic Era baseline", layer["origin"])
            self.assertIn(f"geometry of build {BUILD}", layer["origin"])
            self.assertIn("no Forever content", layer["origin"])  # the pack must never present the baseline as Forever's data
            quests = datapack.read_table(pack, "quests")  # the generated Lua parses back
            self.assertEqual(quests[1]["src"], "questie")
            self.assertEqual(quests[2]["s"], {"npc": [102]})
            gaps = (pack / "data-gaps.md").read_text(encoding="utf-8")
            self.assertIn("- quests whose start has no position (2): 5, 8", gaps)
            self.assertIn("## Not in this pack: Forever's own content", gaps)
            self.assertIn("Zephras Isle (2521): 0 quests, 0 NPCs (nothing)", gaps)
            self.assertIn("Classic **baseline**", gaps)
            for text in TEXTS:
                for path in pack.glob("*.lua"):
                    self.assertNotIn(text, path.read_text(encoding="utf-8"))

            result = qi.check(pack, {1411}, races=128, classes=4, sides=qi.FACTION_SIDES["horde"])
            self.assertEqual(result["checked"], [1, 2, 5, 9])  # 2 by where its giver stands
            self.assertEqual((result["start"], result["end"], result["coordinate"]), (4, 4, 4))
            self.assertEqual((result["start placed"], result["failing"], result["listed"]), (3, [], [5]))
            result = qi.check(pack, {9001}, races=None, classes=None, sides=qi.FACTION_SIDES["horde"])
            self.assertEqual((result["failing"], result["unlisted"]), ([8], []))
            result = qi.check(pack, {1411}, races=16, classes=1, sides=qi.FACTION_SIDES["horde"])
            self.assertEqual(result["checked"], [1, 9])  # 2 needs class bit 4, 5 race bit 2 or 128

    def test_listed_quests(self):
        gaps = "\n".join(
            [
                "## Quests without a start (3)",
                "",
                "7, 8 (and 1 more)",
                "",
                "## Quest givers and enders without a position (1)",
                "",
                "npc 9",
                "",
                "## Problems reported by the questie source (2)",
                "",
                "- quests whose start has no position (2): 5, 11",
                "- AreaIDs without a uiMapID (1): 99",
            ]
        )
        self.assertEqual(qi.listed_quests(gaps), {5, 7, 8, 11})


class FormatTest(unittest.TestCase):
    def test_missing_field_or_part_is_an_error(self):
        with tempfile.TemporaryDirectory() as tmp:
            keys = keys_text("quest", [name for name in QUEST_LAYOUT if name != "zoneOrSort"], QUEST_PARTS)
            root = make_checkout(Path(tmp) / "a", quest_keys=keys)
            with self.assertRaisesRegex(qi.QuestieFormatError, "has no zoneOrSort"):
                qi.load(root)
            parts = {**QUEST_PARTS, "startedBy": ["itemStart", "creatureStart"]}
            root = make_checkout(Path(tmp) / "b", quest_keys=keys_text("quest", QUEST_LAYOUT, parts))
            with self.assertRaisesRegex(qi.QuestieFormatError, "startedBy part objectStart"):
                qi.load(root)

    def test_missing_file_or_table_is_an_error(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = make_checkout(Path(tmp) / "questiedb")
            (root / "data" / "Forever" / "foreverItemDB.lua").write_text("QuestieDB.itemKeys = {}\n", encoding="utf-8")
            with self.assertRaisesRegex(qi.QuestieFormatError, "no QuestieDB.itemData"):
                qi.load(root)
            (root / "data" / "Forever" / "foreverItemDB.lua").unlink()
            with self.assertRaisesRegex(qi.QuestieFormatError, "is missing"):
                qi.load(root)

    def test_broken_data_is_an_error(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = make_checkout(Path(tmp) / "questiedb", quests={1: {"name": '"Unclosed'}})
            with self.assertRaisesRegex(qi.QuestieFormatError, "QuestieDB.questData"):
                qi.load(root)

    def test_helpers(self):
        self.assertEqual(qi.race_side(0), "both")
        self.assertEqual(qi.race_side(None), "both")
        self.assertEqual(qi.race_side(128), "Horde")
        self.assertEqual(qi.race_side(77), "Alliance")
        self.assertEqual(qi.race_side(77 | 178), "both")
        self.assertIsNone(qi.race_side(512))
        self.assertEqual(
            [qi.npc_side(v) for v in ("AH", "HA", "A", "H", None, "")],
            ["both", "both", "Alliance", "Horde", "none", "none"],
        )
        self.assertEqual(qi.id_map([["a"], None, ["c"]]), {1: ["a"], 3: ["c"]})
        self.assertEqual(qi.ids({2: 5, 1: 7, "x": 9}), [5, 7])
        self.assertEqual(qi.part({3: "x"}, 3), "x")
        self.assertIsNone(qi.part([1, 2], 3))


if __name__ == "__main__":
    unittest.main()
