"""Parser tests on small synthetic pages (invented names, written for these tests; not copies of Wowhead pages)."""

import json
import tempfile
import unittest
from pathlib import Path

from signpost_tools import wowhead

LISTVIEW_PAGE = """<script>var x = 1;
new Listview({"template":"quest","id":"quests","name":"Quests","data":[{"category":14,"category2":1,"id":101,"level":3,
"name":"Alpha [x]","reqlevel":1,"side":2},{"id":102,"name":"Beta \\"quoted\\" {brace}","level":4,"side":3}]});
new Listview({template: 'npc', id: 'npcs', data: [{"id":7,"name":"Seven","location":[14]}]});
</script>"""

ENTITY_PAGE = r"""<script>
WH.Gatherer.addData(1, 4, {"7":{"name_enus":"Seven"}});
WH.Gatherer.addData(3, 4, {"9":{"name_enus":"Nine","quality":1}});
var g_mapperData = {"14":{"0":{"count":2,"coords":[[42.1,68.3],[42.5,68]],"uiMapId":1411,"uiMapName":"Durotar"}}};
WH.markup.printHtml("[ul][li]Level: 3[\/li][li]Requires level 1[\/li][li]Side: [span class=icon-horde]Horde[\/span][\/li][li][icon name=quest_start]Start: [url=\/forever\/npc=7]Seven[\/url][\/icon][\/li][li][icon name=quest_end]End: [url=\/forever\/object=8]Eight[\/url][\/icon][\/li][\/ul]", "infobox-contents-0", {allow: Markup.CLASS_STAFF});
WH.dataEnv = 21;
</script>
<table class="series"><tr><th>1.</th><td><a href="/forever/quest=100">A</a></td></tr>
<tr><th>2.</th><td><b>B</b></td></tr><tr><th>3.</th><td><a href="/forever/quest=103">C</a></td></tr></table>"""


class ParserTest(unittest.TestCase):
    def test_listviews(self):
        views = wowhead.listviews(LISTVIEW_PAGE)
        self.assertEqual([(v["template"], v["id"], len(v["data"])) for v in views], [("quest", "quests", 2), ("npc", "npcs", 1)])
        self.assertEqual(views[0]["data"][1]["name"], 'Beta "quoted" {brace}')

    def test_gatherer(self):
        data = wowhead.gatherer(ENTITY_PAGE)
        self.assertEqual(data[wowhead.TYPE_NPC]["7"]["name_enus"], "Seven")
        self.assertEqual(data[wowhead.TYPE_ITEM]["9"]["quality"], 1)

    def test_mapper_coordinates(self):
        points = wowhead.coordinates(wowhead.mapper(ENTITY_PAGE))
        self.assertEqual(points, [{"zone": 14, "uiMapId": 1411, "x": 42.1, "y": 68.3}, {"zone": 14, "uiMapId": 1411, "x": 42.5, "y": 68}])

    def test_infobox(self):
        facts = wowhead.infobox_facts(wowhead.infobox_markup(ENTITY_PAGE))
        self.assertEqual(facts["level"], 3)
        self.assertEqual(facts["reqlevel"], 1)
        self.assertEqual(facts["side"], "Horde")
        self.assertEqual(facts["start"], [{"type": "npc", "id": 7}])
        self.assertEqual(facts["end"], [{"type": "object", "id": 8}])

    def test_series_marks_the_current_quest(self):
        chain = wowhead.series(ENTITY_PAGE)
        self.assertEqual(chain, [100, None, 103])
        self.assertEqual(wowhead.neighbours(chain), (100, 103))
        self.assertEqual(wowhead.neighbours([None, 5]), (None, 5))
        self.assertEqual(wowhead.neighbours([]), (None, None))

    def test_data_env(self):
        self.assertEqual(wowhead.data_env(ENTITY_PAGE), [21])

    def test_describe_reports_structure_without_text(self):
        report = wowhead.describe(wowhead.Page("https://example.invalid/x", 200, LISTVIEW_PAGE + ENTITY_PAGE, False))
        self.assertTrue(report["markers"]["listview"])
        self.assertEqual(report["listviews"][0]["row_keys"], ["category", "category2", "id", "level", "name", "reqlevel", "side"])
        self.assertEqual(report["mapper"]["floor_keys"], ["coords", "count", "uiMapId", "uiMapName"])
        self.assertEqual(report["infobox"]["link_kinds"], ["npc", "object"])
        flat = json.dumps(report)
        for text in ("Alpha", "Seven", "Durotar", "Eight"):
            self.assertNotIn(text, flat)

    def test_describe_reports_row_shapes_and_npc_roles_without_text(self):
        report = wowhead.describe(wowhead.Page("https://example.invalid/zone", 200, STAGE_PAGE, False))
        npcs, recipes = report["listviews"]
        self.assertEqual(npcs["row_keys"], ["id", "name", "react", "tag"])
        self.assertEqual(npcs["row_keys_all"], ["id", "location", "name", "react", "tag"])
        self.assertEqual(npcs["shapes"], {"location": "list[1]<int>", "react": "list[2]<int>", "tag": "str"})
        self.assertEqual(recipes["shapes"]["reagents"], "list[2]<list[2]<int>>")
        self.assertEqual(recipes["shapes"]["colors"], "list[4]<int>")
        self.assertEqual(report["npc_roles"], {"flight": 1, "inn": 1, "trainer": 1, "transport": 2})
        flat = json.dumps(report)
        for text in ("Windy", "Wind Rider", "Innkeeper", "Zeppelin", "Dockmaster", "Leatherworking", "Plain"):
            self.assertNotIn(text, flat)

    def test_shape(self):
        self.assertEqual(wowhead.shape([[1, 2], [3, 4.5]]), "list[2]<list[2]<float|int>|list[2]<int>>")
        self.assertEqual(wowhead.shape({"a": 1}), "dict[1]")
        self.assertEqual((wowhead.shape([]), wowhead.shape(None), wowhead.shape(True)), ("list[0]", "null", "bool"))


STAGE_PAGE = """<script>
new Listview({template: 'npc', id: 'npcs', data: [{"id":11,"name":"Windy","tag":"Wind Rider Master","react":[-1,1]},
{"id":12,"name":"Sleepy","tag":"Innkeeper","react":[1,1]},{"id":13,"name":"Zed","tag":"Zeppelin Master","react":[-1,1]},
{"id":14,"name":"Docky","tag":"Dockmaster","react":[1,-1]},{"id":15,"name":"Plain","location":[14]},
{"id":16,"name":"Hides","tag":"Leatherworking Trainer","react":[-1,1]}]});
new Listview({template: 'spell', id: 'recipes', data: [{"id":21,"skill":[165],"colors":[1,30,45,60],"creates":[31,1,1],
"reagents":[[41,2],[42,1]],"source":[2,6]}]});
</script>
<h1 class="heading-size-1">Windy</h1>"""


class RowParserTest(unittest.TestCase):
    def test_rows_by_template(self):
        self.assertEqual([row["id"] for row in wowhead.rows(STAGE_PAGE, "npc")], [11, 12, 13, 14, 15, 16])
        self.assertEqual([row["id"] for row in wowhead.rows(STAGE_PAGE, "spell")], [21])
        self.assertEqual(len(wowhead.rows(STAGE_PAGE)), 7)
        self.assertEqual(wowhead.rows(STAGE_PAGE, "quest"), [])

    def test_react_side(self):
        cases = {(-1, 1): "Horde", (1, -1): "Alliance", (1, 1): "both", (0, 0): "both", (-1, -1): "hostile"}
        for react, side in cases.items():
            self.assertEqual(wowhead.react_side(list(react)), side)
        for react in (None, [1], ["x", 1], "1,1"):
            self.assertIsNone(wowhead.react_side(react))

    def test_npc_roles_and_transport_kind(self):
        roles = {row["id"]: wowhead.npc_role(row.get("tag")) for row in wowhead.rows(STAGE_PAGE, "npc")}
        self.assertEqual(roles, {11: "flight", 12: "inn", 13: "transport", 14: "transport", 15: None, 16: "trainer"})
        self.assertEqual(wowhead.npc_role("Hippogryph Master"), "flight")
        self.assertEqual(wowhead.npc_role("Bat Handler"), "flight")
        self.assertEqual((wowhead.transport_kind("Zeppelin Master"), wowhead.transport_kind("Harbormaster")), ("zeppelin", "boat"))

    def test_recipe(self):
        record, missing = wowhead.recipe(wowhead.rows(STAGE_PAGE, "spell")[0])
        self.assertEqual(record, {"item": 31, "skill": [1, 30, 45, 60], "reagents": {41: 2, 42: 1}, "src": "trainer"})
        self.assertEqual(missing, [])
        record, missing = wowhead.recipe({"id": 22, "colors": [0, 40, 55, 70], "learnedat": 35, "reagents": [], "source": [2, 5]})
        self.assertEqual(record, {"skill": [35, 40, 55, 70], "src": "vendor"})
        self.assertEqual(missing, [])
        record, missing = wowhead.recipe({"id": 23, "creates": [33, 1, 1], "colors": [1, 2]})
        self.assertEqual((record, missing), ({"item": 33}, ["skill colors", "reagents"]))
        self.assertIsNone(wowhead.recipe({"id": 24, "level": 1, "name": "Apprentice"}))

    def test_trainer_spells(self):
        rows = [
            {"id": 1, "level": 4, "cat": 7, "source": [6]},
            {"id": 2, "level": 4, "cat": 7, "source": [6]},
            {"id": 3, "level": 1, "cat": 7, "source": [10]},
            {"id": 4, "level": 10, "cat": -2, "source": [6]},
            {"id": 5, "level": 0, "cat": 7, "source": [6]},
            {"id": 6, "level": 12, "cat": 7, "source": [6, 4]},
        ]
        self.assertEqual(wowhead.trainer_spells(rows), ({4: [1, 2], 12: [6]}, "source"))
        costs = [{"id": 7, "level": 6, "trainingcost": 100}, {"id": 8, "level": 1, "trainingcost": 0}]
        self.assertEqual(wowhead.trainer_spells(costs), ({6: [7]}, "trainingcost"))
        self.assertEqual(wowhead.trainer_spells([{"id": 9, "level": 2}]), ({2: [9]}, "none"))
        self.assertEqual(wowhead.trainer_spells([]), ({}, "none"))

    def test_heading_and_entity_exists(self):
        self.assertEqual(wowhead.heading(STAGE_PAGE), "Windy")
        self.assertIsNone(wowhead.heading("<h2>x</h2>"))
        def page(status, text=""):
            return wowhead.Page("https://example.invalid/q", status, text, True)

        self.assertIs(wowhead.entity_exists(page(404)), False)
        self.assertIs(wowhead.entity_exists(page(200, ENTITY_PAGE)), True)
        self.assertIsNone(wowhead.entity_exists(page(200, "<html>no facts</html>")))
        self.assertIsNone(wowhead.entity_exists(page(0)))

    def test_to_int(self):
        self.assertEqual([wowhead.to_int(v) for v in (3, "4", 5.0, None, "x", True)], [3, 4, 5, None, None, None])


class CacheTest(unittest.TestCase):
    def test_offline_reads_only_the_cache(self):
        with tempfile.TemporaryDirectory() as tmp:
            client = wowhead.Wowhead(Path(tmp), offline=True)
            url = client.url("quest=1")
            self.assertEqual(client.fetch(url).status, 0)
            client._write_cache(url, 200, "<html>cached</html>")
            page = client.fetch(url)
            self.assertEqual((page.status, page.text, page.from_cache), (200, "<html>cached</html>", True))
            self.assertEqual(client.requests, 0)

    def test_fresh_cache_entries_are_used(self):
        with tempfile.TemporaryDirectory() as tmp:
            client = wowhead.Wowhead(Path(tmp), max_age_days=7)
            url = client.url("npc=2")
            client._write_cache(url, 404, "")
            self.assertEqual(client.fetch(url).status, 404)
            self.assertEqual(client.requests, 0)

    def test_minimum_delay_is_enforced(self):
        self.assertEqual(wowhead.Wowhead(Path("."), delay=0.1).delay, wowhead.MIN_DELAY)

    def test_flavor_selects_another_database_with_its_own_cache_entry(self):
        with tempfile.TemporaryDirectory() as tmp:
            client = wowhead.Wowhead(Path(tmp), offline=True)
            self.assertEqual(client.url("quest=1"), "https://www.wowhead.com/forever/quest=1")
            self.assertEqual(client.url("quest=1", "classic"), "https://www.wowhead.com/classic/quest=1")
            client._write_cache(client.url("quest=1", "classic"), 404, "")
            self.assertEqual(client.get("quest=1", "classic").status, 404)
            self.assertEqual(client.get("quest=1").status, 0)
            self.assertEqual(client.requests, 0)


if __name__ == "__main__":
    unittest.main()
