"""The exporter end to end, offline: every stage runs against a cache of small synthetic pages (invented names and IDs,
written for these tests in the shape the parsers assume; not copies of Wowhead pages). The network is blocked."""

import json
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import wowhead_export
from signpost_tools import datapack, geo, wowhead
from signpost_tools.savedvars import load_savedvars

CLIENT_MAPS = {
    1414: {
        "n": "Kalimdor",
        "t": 2,
        "parent": 947,
        "world": [1, 1000.0, 1000.0, -1000.0, -1000.0],
        "taxi": [
            {"id": 1, "n": "Testhold, Testlands", "x": 50.0, "y": 50.0, "faction": 1},
            {"id": 2, "n": "zzOLDTesthold, Testlands", "x": 50.0, "y": 50.0, "faction": 1},
            {"id": 3, "n": "Far Post, Faraway", "x": 10.0, "y": 10.0, "faction": 2},
        ],
    },
    9411: {"n": "Testlands", "t": 3, "parent": 1414, "world": [1, 500.0, 500.0, -500.0, -500.0]},
    9454: {"n": "Test City", "t": 3, "parent": 1414, "world": [1, 100.0, 900.0, -100.0, 700.0]},
    9499: {"n": "Faraway", "t": 3, "parent": 1414},
    9500: {"n": "Nowhere", "t": 3, "parent": 1414},
}
QUESTIE = {
    "quests": {
        102: {"n": "Known Quest", "s": {"npc": [70]}, "e": {"npc": [71]}},
        301: {"n": "Exclusive", "classes": 4, "side": "Horde", "s": {"npc": [72]}, "e": {"npc": [72]}},
        302: {"n": "Shared", "classes": 5, "side": "Horde", "s": {"npc": [72]}, "e": {"npc": [72]}},
    },
    "npcs": {
        70: {"n": "Seventy", "p": [[9411, 40.0, 40.0]]},
        71: {"n": "Seventy-one"},
        72: {"n": "Seventy-two", "p": [[9454, 10.0, 10.0]]},
        4002: {"n": "Sleepy", "p": [[9411, 30.0, 30.0]]},
    },
}
FACTS = {
    "professions": {165: {"n": "Leatherworking", "primary": True}, 129: {"n": "First Aid", "primary": False}},
    "classes": {"WARRIOR": {"id": 1, "n": "Warrior"}, "HUNTER": {"id": 3, "n": "Hunter"}},
}


def listview(template, view_id, data):
    return f"new Listview({{template: '{template}', id: '{view_id}', data: {json.dumps(data)}}});"


def quick_facts(start=(), end=(), extra=()):
    items = list(extra)
    for label, links in (("Start", start), ("End", end)):
        for kind, ident in links:
            items.append(f"[icon name=quest_{label.lower()}]{label}: [url=/forever/{kind}={ident}]Someone[/url][/icon]")
    markup = "[ul]" + "".join(f"[li]{item}[/li]" for item in items) + "[/ul]"
    return f'WH.markup.printHtml({json.dumps(markup)}, "infobox-contents-0", {{allow: Markup.CLASS_STAFF}});'


def series(chain):
    cells = ["<b>This one</b>" if ident is None else f'<a href="/forever/quest={ident}">Other</a>' for ident in chain]
    rows = "".join(f"<tr><th>{i}.</th><td>{cell}</td></tr>" for i, cell in enumerate(cells, 1))
    return f'<table class="series">{rows}</table>'


def mapper(zone, coords, ui_map=None):
    floor = {"count": len(coords), "coords": coords}
    if ui_map:
        floor["uiMapId"] = ui_map
    return f"var g_mapperData = {json.dumps({str(zone): {'0': floor}})};"


def gatherer(kind, names):
    return f"WH.Gatherer.addData({kind}, 4, {json.dumps({str(k): {'name_enus': v} for k, v in names.items()})});"


def page(*scripts, html=""):
    return "<html><script>\n" + "\n".join(scripts) + "\n</script>" + html + "</html>"


NPC_ROWS_TESTLANDS = [
    {"id": 4001, "name": "Windy", "tag": "Wind Rider Master", "react": [-1, 1]},
    {"id": 4002, "name": "Sleepy", "tag": "Innkeeper", "react": [-1, 1]},
    {"id": 4003, "name": "Zep East", "tag": "Zeppelin Master", "react": [-1, 1]},
    {"id": 4004, "name": "Nobody"},
]
NPC_ROWS_CITY = [
    {"id": 4005, "name": "Zep West", "tag": "Zeppelin Master", "react": [-1, 1]},
    {"id": 4006, "name": "Docky", "tag": "Dockmaster", "react": [1, 1]},
]

PAGES = {
    "zones": page(
        listview(
            "zone",
            "zones",
            [
                {"id": 9014, "name": "Testlands", "minlevel": 1, "maxlevel": 10, "category": 1},
                {"id": 9637, "name": "Test City", "category": 1},
                {"id": 9099, "name": "Faraway", "minlevel": 50, "maxlevel": 55, "category": 1},
            ],
        )
    ),
    "quests=1.9014": page(
        listview(
            "quest",
            "quests",
            [
                {"id": 101, "name": "First Quest", "level": 2, "reqlevel": 1, "side": 2},
                {"id": 102, "name": "Known Quest", "level": 3, "reqlevel": 2, "side": 3},
                {"id": 103, "name": "Other Side", "level": 3, "side": 1},
                {"id": 104, "name": "Too High", "level": 40, "side": 2},
            ],
        )
    ),
    "quests=1.9637": "<html>no list here</html>",
    "quest=101": page(
        quick_facts(start=[("npc", 7)], end=[("object", 8)], extra=["Level: 2", "Requires level 1"]),
        gatherer(wowhead.TYPE_NPC, {7: "Seven"}),
        gatherer(wowhead.TYPE_OBJECT, {8: "Eight"}),
        html=series([None, 105]),
    ),
    "npc=7": page(mapper(9014, [[42.0, 68.0], [42.2, 68.1], [80.0, 10.0]], 9411)),
    "object=8": page(mapper(9014, [[10.0, 20.0]])),
    "npc=71": "<html>nothing to see</html>",
    "class=3": page(
        listview(
            "spell",
            "spells",
            [
                {"id": 501, "level": 4, "cat": 7, "source": [6]},
                {"id": 502, "level": 4, "cat": 7, "source": [6]},
                {"id": 503, "level": 1, "cat": 7, "source": [10]},
                {"id": 504, "level": 10, "cat": -2, "source": [6]},
            ],
        ),
        listview(
            "npc",
            "trainers",
            [
                {"id": 3001, "name": "Horde Trainer", "react": [-1, 1]},
                {"id": 3002, "name": "Alliance Trainer", "react": [1, -1]},
            ],
        ),
    ),
    "quests=4.-261": page(
        listview(
            "quest",
            "quests",
            [
                {"id": 201, "name": "Class One", "level": 10, "reqlevel": 10, "side": 2},
                {"id": 202, "name": "Class Two", "level": 10, "reqlevel": 10, "side": 2},
                {"id": 203, "name": "Class Elsewhere", "level": 10, "reqlevel": 10, "side": 1},
            ],
        )
    ),
    "quest=201": page(quick_facts(start=[("npc", 3001)], end=[("npc", 3001)]), html=series([None, 202])),
    "quest=202": page(quick_facts(start=[("npc", 3001)], end=[("npc", 3001)]), html=series([201, None])),
    "npc=3001": page(mapper(9637, [[50.0, 50.0]], 9454)),
    "skill=165": page(
        listview(
            "spell",
            "recipes",
            [
                {"id": 601, "skill": [165], "colors": [1, 30, 45, 60], "creates": [701, 1, 1], "reagents": [[702, 2], [703, 1]], "source": [6]},
                {"id": 602, "skill": [165], "colors": [0, 40, 55, 70], "learnedat": 35, "reagents": [[702, 4]], "source": [2, 5]},
                {"id": 603, "skill": [999], "colors": [1, 2, 3, 4], "reagents": [[704, 1]]},
                {"id": 604, "skill": [165], "level": 1},
            ],
        ),
        listview("npc", "trainers", [{"id": 3101, "name": "Hide Trainer", "react": [-1, 1]}]),
    ),
    "npc=3101": page(mapper(9637, [[40.0, 40.0]], 9454)),
    "skill=129": "<html>no listviews</html>",
    "spells=9.129": page(listview("spell", "recipes", [{"id": 611, "colors": [1, 30, 45, 60], "creates": [711, 1, 1], "source": [6]}])),
    "zone=9014": page(listview("npc", "npcs", NPC_ROWS_TESTLANDS)),
    "zone=9637": page(listview("npc", "npcs", NPC_ROWS_CITY)),
    "npc=4001": page(mapper(9014, [[50.0, 52.0]], 9411)),
    "npc=4003": page(mapper(9014, [[60.0, 60.0]], 9411)),
    "npc=4005": page(mapper(9637, [[20.0, 20.0]], 9454)),
    "npc=4006": page(mapper(9637, [[30.0, 30.0]], 9454)),
}
CLASSIC_PAGES = {
    "quest=201": (200, page(quick_facts(start=[("npc", 3001)], end=[("npc", 3001)]))),
    "quest=202": (404, ""),
    "quest=301": (404, ""),
}
ALL_STAGES = ["--stages", "zones,quests,class,professions,travel", "--class", "hunter", "--transport", "zeppelin:4003,4005"]


def no_network(*args, **kwargs):
    raise AssertionError("the exporter tests must never touch the network")


class ExportTest(unittest.TestCase):
    def setUp(self):
        patcher = mock.patch("urllib.request.urlopen", side_effect=no_network)
        self.urlopen = patcher.start()
        self.addCleanup(patcher.stop)
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.pack = Path(tmp.name) / "pack"
        self.cache = Path(tmp.name) / "cache"
        datapack.init_stub(self.pack)
        datapack.write_layer(self.pack, "client", {"maps": CLIENT_MAPS}, "test dump")
        datapack.write_layer(self.pack, "questie", QUESTIE, "test questie")
        datapack.build(self.pack, "test")
        client = wowhead.Wowhead(self.cache, offline=True)
        for path, text in PAGES.items():
            client._write_cache(client.url(path), 200, text)
        for path, (status, text) in CLASSIC_PAGES.items():
            client._write_cache(client.url(path, wowhead.CLASSIC_FLAVOR), status, text)

    def export(self, *args):
        argv = ["--out", str(self.pack), "--cache", str(self.cache), "--offline", "--map-overrides", str(self.pack / "none.json")]
        options = wowhead_export.parse_args(argv + list(args))
        export, counts = wowhead_export.run(options, facts=FACTS, log=lambda message: None)
        self.assertEqual(export.client.requests, 0)
        return export, counts

    def test_every_stage_offline(self):
        export, counts = self.export(*ALL_STAGES)
        self.urlopen.assert_not_called()
        problems = set(export.problems)
        layer = datapack.read_layer(self.pack, "wowhead")["tables"]

        # zones: Wowhead IDs and level ranges only (the client layer keeps the rest)
        self.assertEqual(layer["maps"][9411], {"wowhead": 9014, "lmin": 1, "lmax": 10})
        self.assertEqual(layer["maps"][9454], {"wowhead": 9637})
        self.assertEqual(layer["maps"][9499], {"wowhead": 9099, "lmin": 50, "lmax": 55})
        self.assertIn("client zone not on Wowhead's zone list (add a map override): 9500", problems)

        # quests: list facts for every kept quest, the page only where no layer has start and end
        quests = datapack.read_table(self.pack, "quests")
        self.assertEqual(quests[101]["s"], {"npc": [7]})
        self.assertEqual(quests[101]["e"], {"obj": [8]})
        self.assertEqual((quests[101]["next"], quests[101]["zone"], quests[101]["side"]), (105, 9411, "Horde"))
        self.assertNotIn("s", layer["quests"][102])
        self.assertEqual((quests[102]["s"], quests[102]["l"], quests[102]["src"]), ({"npc": [70]}, 3, "questie,wowhead"))
        self.assertNotIn(103, quests)
        self.assertNotIn(104, quests)
        self.assertIn("quest list empty or missing (HTTP 200): zone 9454", problems)

        # entities: pages only for what no layer has placed; names from the quest page's Gatherer data
        npcs, objects = datapack.read_table(self.pack, "npcs"), datapack.read_table(self.pack, "objects")
        # spawns grouped by signpost_tools.geo.cluster: a group is the real spawn nearest its centre
        self.assertEqual(npcs[7], {"n": "Seven", "p": [[9411, 42, 68], [9411, 80, 10]], "src": "wowhead"})
        self.assertEqual(objects[8]["p"], [[9411, 10, 20]])
        self.assertNotIn(70, layer["npcs"])
        self.assertIn("npc without coordinates: 71", problems)
        self.assertEqual(npcs[3001]["side"], "Horde")

        # class: trainer spells by level, trainers usable by the faction, chains with the Classic check
        hunter = load_savedvars(self.pack / "classes" / "HUNTER.lua")["Signpost_Data.classes.HUNTER"]
        self.assertEqual(hunter["spells"], {4: [501, 502]})
        self.assertEqual(hunter["trainers"], [3001])
        self.assertEqual(
            hunter["quests"],
            [
                {"id": 301, "n": "Exclusive", "quests": [301], "new": True},
                {"id": 201, "n": "Class One", "l": 10, "quests": [201, 202], "new": True},
            ],
        )
        self.assertIn("classes\\HUNTER.lua", (self.pack / "Signpost_Data.toc").read_text(encoding="utf-8"))
        self.assertEqual(counts["classes"], 1)
        # the series' previous quest is the questie layer's preSingle, not a field of its own
        self.assertEqual(quests[202]["preSingle"], [201])
        self.assertEqual(quests[201]["next"], 202)
        self.assertNotIn("prev", quests[202])

        # professions: numeric keys survive the JSON layer; a secondary skill falls back to its recipe list
        professions = datapack.read_table(self.pack, "professions")
        leather = professions[165]
        self.assertEqual(leather["n"], "Leatherworking")
        self.assertEqual(leather["trainers"], [3101])
        self.assertEqual(sorted(leather["recipes"]), [601, 602])
        self.assertEqual(leather["recipes"][601], {"item": 701, "skill": [1, 30, 45, 60], "reagents": {702: 2, 703: 1}, "src": "trainer"})
        self.assertEqual(leather["recipes"][602], {"skill": [35, 40, 55, 70], "reagents": {702: 4}, "src": "vendor"})
        self.assertEqual(professions[129]["recipes"], {611: {"item": 711, "skill": [1, 30, 45, 60], "src": "trainer"}})
        self.assertIn("recipe without reagents: 611", problems)
        self.assertIn("page without a trainer listview: profession 129", problems)

        # travel: flight node from the client dump (retired zz nodes skipped), inns, a paired zeppelin route
        travel = datapack.read_table(self.pack, "travel")
        self.assertEqual(travel["flightMasters"][4001], {"node": "Testhold, Testlands", "p": [9411, 50, 52], "side": "Horde"})
        self.assertEqual(travel["inns"][4002], {"p": [9411, 30, 30], "side": "Horde"})
        self.assertEqual(
            travel["transports"],
            [{"kind": "zeppelin", "from": [9411, 60, 60], "to": [9454, 20, 20], "side": "Horde", "npcs": [4003, 4005]}],
        )
        self.assertIn("boat master without a --transport pair: 4006", problems)

        # no item records, and problems carry IDs and kinds only
        self.assertEqual(datapack.read_table(self.pack, "items"), {})
        for text in ("Windy", "Zeppelin", "Seven", "Someone", "This one"):
            self.assertFalse(any(text in problem for problem in problems), text)
        self.assertIn("Problems reported by the wowhead source", (self.pack / "data-gaps.md").read_text(encoding="utf-8"))

    def test_all_reads_pages_other_layers_already_cover(self):
        export, _ = self.export("--stages", "quests", "--zones", "Testlands", "--all")
        problems = set(export.problems)
        self.assertIn("quest page not in the cache: 102", problems)
        self.assertIn("npc page not in the cache: 70", problems)
        gap_only, _ = self.export("--stages", "quests", "--zones", "Testlands")
        self.assertFalse(any(problem.endswith(": 102") or problem.endswith(": 70") for problem in gap_only.problems))

    def test_runs_add_to_the_layer_and_fresh_starts_over(self):
        self.export("--stages", "quests", "--zones", "Testlands")
        self.export("--stages", "professions", "--professions", "Leatherworking")
        tables = datapack.read_layer(self.pack, "wowhead")["tables"]
        self.assertIn(101, tables["quests"])
        self.assertEqual(sorted(tables["professions"]), [165])
        self.export("--stages", "class", "--class", "HUNTER", "--no-classic-check")
        self.export("--stages", "professions", "--professions", "129")
        layer = datapack.read_layer(self.pack, "wowhead")
        self.assertEqual(sorted(layer["tables"]["professions"]), [129, 165])
        self.assertIn("HUNTER", layer["tables"]["classes"])
        self.assertNotIn("new", layer["tables"]["classes"]["HUNTER"]["quests"][0])
        self.export("--fresh", "--stages", "professions", "--professions", "165")
        layer = datapack.read_layer(self.pack, "wowhead")
        self.assertNotIn(101, layer["tables"]["quests"])
        self.assertEqual(layer["tables"]["classes"], {})

    def test_a_profession_or_class_that_gives_nothing_keeps_the_earlier_export(self):
        self.export("--stages", "professions,class", "--professions", "165", "--class", "HUNTER")
        client = wowhead.Wowhead(self.cache, offline=True)
        for path in ("skill=165", "class=3", "quests=4.-261"):
            client._cache_file(client.url(path)).unlink()
        export, _ = self.export("--stages", "professions,class", "--professions", "165", "--class", "HUNTER")
        self.assertIn("profession pages gave nothing; the earlier export is kept: 165", export.problems)
        self.assertIn("class pages could not be read; the earlier export is kept: HUNTER", export.problems)
        layer = datapack.read_layer(self.pack, "wowhead")
        self.assertEqual(sorted(layer["tables"]["professions"][165]["recipes"]), [601, 602])
        self.assertEqual(layer["tables"]["classes"]["HUNTER"]["trainers"], [3001])

    def test_missing_maps_stop_the_export(self):
        (self.pack / "Maps.lua").unlink()
        with self.assertRaises(SystemExit):
            self.export("--stages", "quests")


class OptionsTest(unittest.TestCase):
    def test_stage_options(self):
        options = wowhead_export.parse_args(["--class", "hunter", "--transport", "boat:1,2", "--out", "pack"])
        self.assertEqual((options.class_name, options.stage_set), ("HUNTER", {"zones", "quests", "class"}))
        self.assertEqual(options.transports, [("boat", 1, 2)])
        self.assertEqual(options.cache, Path("pack") / "cache" / "wowhead")
        with mock.patch("sys.stderr"):
            for argv in (["--stages", "class"], ["--stages", "quests,entities"], ["--transport", "ship:1,2"]):
                with self.assertRaises(SystemExit):
                    wowhead_export.parse_args(argv)


class HelperTest(unittest.TestCase):
    def test_client_facts_from_the_newest_probe(self):
        probe = {
            "professions": {
                "byEnum": {
                    "Skinning": {"skillLine": 393, "info": {"professionName": "Skinning", "isPrimaryProfession": True}},
                    "Cooking": {"skillLine": 185, "info": {"professionName": "Cooking", "isPrimaryProfession": False}},
                    "Archaeology": {"skillLine": 0, "info": {"professionName": ""}},
                }
            },
            "player": {"classes": {"3": {"classFile": "HUNTER", "classID": 3, "className": "Hunter"}}},
        }
        with tempfile.TemporaryDirectory() as tmp:
            (Path(tmp) / "1.60.1.9.json").write_text("{}", encoding="utf-8")
            (Path(tmp) / "1.60.1.70450.json").write_text(json.dumps(probe), encoding="utf-8")
            facts = wowhead_export.client_facts(Path(tmp))
            self.assertEqual(wowhead_export.client_facts(Path(tmp) / "missing"), {"professions": {}, "classes": {}})
        self.assertEqual(facts["professions"], {393: {"n": "Skinning", "primary": True}, 185: {"n": "Cooking", "primary": False}})
        self.assertEqual(facts["classes"], {"HUNTER": {"id": 3, "n": "Hunter"}})

    def test_the_repository_probe_lists_professions_and_classes(self):
        facts = wowhead_export.client_facts()
        self.assertTrue(facts["professions"] and all(isinstance(skill, int) and skill > 0 for skill in facts["professions"]))
        self.assertTrue(facts["classes"] and all(isinstance(info["id"], int) for info in facts["classes"].values()))

    def test_sides(self):
        self.assertEqual(wowhead_export.combined_side(["Horde", "both"]), "Horde")
        self.assertEqual(wowhead_export.combined_side(["Horde", "Alliance"]), "both")
        self.assertEqual(wowhead_export.combined_side([None, "hostile"]), None)

    def test_cluster_is_the_shared_helper(self):
        self.assertIs(wowhead_export.cluster, geo.cluster)

    def test_map_overrides(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "overrides.json"
            self.assertEqual(wowhead_export.load_overrides(path), {})
            path.write_text('{"9411": 9014}', encoding="utf-8")
            self.assertEqual(wowhead_export.load_overrides(path), {9411: 9014})
            path.write_text("[1, 2]", encoding="utf-8")
            with self.assertRaises(SystemExit):
                wowhead_export.load_overrides(path)


if __name__ == "__main__":
    unittest.main()
