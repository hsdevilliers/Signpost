import json
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import rebuild_drafts
import route_install

GUIDE = """local ADDON_NAME, ns = ...

ns.Guides:Register({
	id = "%s",
	name = "%s",
	faction = "Horde",
	races = { "Troll" },
	classes = { "HUNTER" },
	levels = { 1, 20 },
	text = [[
#guide %s
#include %s
]],
})
"""
CHAPTER = 'local ADDON_NAME, ns = ...\n\nns.Chapters:Register("%s", [[\n#chapter 1-5 Somewhere\nstep\n  .goto 1,1,1\n]])\n'
BASELINE = "-- Built on a baseline."
TOC = "## Interface: 16001\n## Title: Signpost\nGuides\\Travel\\Borders.lua\nGuides\\Chapters\\old-a.lua\nGuides\\Chapters\\shared.lua\nGuides\\HordeTrollHunter.lua\n"


class InstallCase(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.addCleanup(self.dir.cleanup)
        base = Path(self.dir.name)
        self.root, self.built = base / "repo", base / "built"
        (self.root / "Guides" / "Chapters").mkdir(parents=True)
        (self.root / "tools").mkdir()
        (self.root / "Guides" / "HordeTrollHunter.lua").write_text(
            GUIDE % ("horde-troll-hunter", "Troll Hunter", "Troll Hunter", "old-a\n#include shared"), encoding="utf-8"
        )
        (self.root / "Guides" / "Other.lua").write_text(GUIDE % ("horde-other", "Other", "Other", "shared"), encoding="utf-8")
        for cid in ("old-a", "shared"):
            (self.root / "Guides" / "Chapters" / f"{cid}.lua").write_text(CHAPTER % cid, encoding="utf-8")
        for toc in route_install.TOCS:
            (self.root / toc).write_text(TOC if toc == "Signpost.toc" else TOC.replace("## Title: Signpost\n", "## Title: Signpost\n## X-Flavor-TOC: x\n"), encoding="utf-8")
        (self.root / "tools" / "drafts.json").write_text(
            json.dumps({"about": "x", "guides": [{"guide": "horde-troll-hunter", "hardcore": False, "chapters": [{"id": "old-a"}]}]}, indent=2) + "\n",
            encoding="utf-8",
        )
        (self.built / "Guides" / "Chapters").mkdir(parents=True)
        plan_text = "#guide Troll Hunter\n#skipquest 5 >> alternative to quest 6, which is routed\n#include plan-beam-01-durotar\n#include plan-beam-02-the-barrens\n"
        plan_guide = (GUIDE % ("horde-troll-hunter", "Troll Hunter", "x", "x")).replace("#guide x\n#include x\n", plan_text)
        (self.built / "Guides" / "Plan.lua").write_text(plan_guide, encoding="utf-8")
        for cid in ("plan-beam-01-durotar", "plan-beam-02-the-barrens"):
            (self.built / "Guides" / "Chapters" / f"{cid}.lua").write_text(CHAPTER % cid, encoding="utf-8")
        patch = mock.patch.object(route_install, "find_stylua", lambda root: None)
        patch.start()
        self.addCleanup(patch.stop)

    def install(self, cap=30):
        return route_install.install(self.root, self.built, "horde-troll-hunter", "Horde", "the beam route", cap, BASELINE)


class InstallTest(InstallCase):
    def test_the_chapters_come_in_under_stable_names_with_their_text(self):
        result = self.install()
        self.assertEqual(result.chapters, ["troll-hunter-01-durotar", "troll-hunter-02-the-barrens"])
        text = (self.root / "Guides" / "Chapters" / "troll-hunter-01-durotar.lua").read_text(encoding="utf-8")
        self.assertIn("-- PLANNED: the beam route", text)
        self.assertIn(BASELINE, text)
        self.assertIn('ns.Chapters:Register("troll-hunter-01-durotar", [[\n#chapter 1-5 Somewhere\nstep\n  .goto 1,1,1\n]])', text)

    def test_the_guide_file_points_at_them_with_its_levels_and_skips(self):
        self.install(cap=30)
        text = (self.root / "Guides" / "HordeTrollHunter.lua").read_text(encoding="utf-8")
        self.assertIn("levels = { 1, 30 }", text)
        self.assertIn("#include troll-hunter-01-durotar\n#include troll-hunter-02-the-barrens\n", text)
        self.assertIn("#skipquest 5 >> alternative to quest 6, which is routed", text)
        self.assertNotIn("old-a", text)
        self.assertIn('id = "horde-troll-hunter"', text)

    def test_the_chapters_the_guide_used_are_replaced_unless_another_guide_includes_them(self):
        result = self.install()
        self.assertEqual(result.removed, ["old-a"])
        self.assertFalse((self.root / "Guides" / "Chapters" / "old-a.lua").exists())
        self.assertTrue((self.root / "Guides" / "Chapters" / "shared.lua").exists())

    def test_both_tocs_change_alike(self):
        self.install()
        first = (self.root / "Signpost.toc").read_text(encoding="utf-8")
        second = (self.root / "Signpost_Camelot.toc").read_text(encoding="utf-8")
        for text in (first, second):
            self.assertNotIn("old-a", text)
            self.assertIn("Guides\\Chapters\\shared.lua\nGuides\\Chapters\\troll-hunter-01-durotar.lua\nGuides\\Chapters\\troll-hunter-02-the-barrens.lua\nGuides\\HordeTrollHunter.lua", text)
        self.assertEqual([l for l in first.split("\n")], [l for l in second.split("\n") if not l.startswith("## X-Flavor")])

    def test_the_manifest_marks_the_guide_as_planned_so_nothing_drafts_over_it(self):
        self.install()
        data = json.loads((self.root / "tools" / "drafts.json").read_text(encoding="utf-8"))
        entry = data["guides"][0]
        self.assertEqual(entry["chapters"], [])
        self.assertIn("the beam route", entry["planned"])
        self.assertIs(entry["hardcore"], False)
        self.assertEqual(data["about"], "x")
        self.assertTrue(rebuild_drafts.rebuild(entry, Path(".")))  # skipped, not drafted

    def test_installing_again_replaces_what_the_last_install_wrote(self):
        self.install()
        (self.built / "Guides" / "Chapters" / "plan-beam-03-silverpine-forest.lua").write_text(CHAPTER % "plan-beam-03-silverpine-forest", encoding="utf-8")
        plan = (self.built / "Guides" / "Plan.lua").read_text(encoding="utf-8").replace("#include plan-beam-02-the-barrens\n", "#include plan-beam-03-silverpine-forest\n")
        (self.built / "Guides" / "Plan.lua").write_text(plan, encoding="utf-8")
        again = self.install()
        self.assertEqual(again.chapters, ["troll-hunter-01-durotar", "troll-hunter-03-silverpine-forest"])
        self.assertIn("troll-hunter-02-the-barrens", again.removed)  # no longer included: its file goes
        self.assertFalse((self.root / "Guides" / "Chapters" / "troll-hunter-02-the-barrens.lua").exists())

    def test_what_cannot_be_installed_is_an_error(self):
        with self.assertRaises(ValueError):
            route_install.install(self.root, self.built, "horde-nobody", "Horde", "x", 30, BASELINE)
        empty = (GUIDE % ("horde-troll-hunter", "x", "x", "x")).replace("#include x\n", "")
        (self.built / "Guides" / "Plan.lua").write_text(empty, encoding="utf-8")
        with self.assertRaises(ValueError):
            self.install()


class HelperTest(unittest.TestCase):
    def test_short_ids_drop_the_faction(self):
        self.assertEqual(route_install.short_id("horde-troll-hunter", "Horde"), "troll-hunter")
        self.assertEqual(route_install.short_id("troll-hunter", "Horde"), "troll-hunter")

    def test_a_toc_loses_the_dropped_chapters_and_gains_the_new_ones_once(self):
        out = route_install.toc_with(TOC, {"old-a"}, ["new-1", "new-1", "new-2"])
        self.assertNotIn("old-a", out)
        self.assertEqual(out.count("Guides\\Chapters\\new-1.lua"), 1)
        self.assertTrue(out.endswith("\n"))
        with self.assertRaises(ValueError):
            route_install.toc_with("## Interface: 1\n", set(), ["x"])


if __name__ == "__main__":
    unittest.main()
