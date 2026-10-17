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


if __name__ == "__main__":
    unittest.main()
