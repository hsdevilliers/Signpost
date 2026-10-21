import tempfile
import unittest
from pathlib import Path

import check_repo
import package

TOC = "## Interface: 16001\n## Title: Signpost\n## X-Flavor-TOC: {flavor}\n\nCore\\Init.lua\n"


class TocTest(unittest.TestCase):
    def test_tocs_may_differ_only_in_the_flavor_line(self):
        texts = {"a.toc": TOC.format(flavor="generic"), "b.toc": TOC.format(flavor="Camelot")}
        self.assertEqual(check_repo.compare_tocs(texts), [])

    def test_other_differences_are_reported(self):
        texts = {"a.toc": TOC.format(flavor="x"), "b.toc": TOC.format(flavor="x") + "Core\\Extra.lua\n"}
        self.assertEqual(len(check_repo.compare_tocs(texts)), 1)

    def test_interface_must_come_first_without_bom(self):
        problems = check_repo.compare_tocs({"a.toc": "﻿" + TOC.format(flavor="x")})
        self.assertEqual(len(problems), 1)
        problems = check_repo.compare_tocs({"a.toc": "# comment\n" + TOC.format(flavor="x")})
        self.assertEqual(len(problems), 1)

    def test_toc_entries(self):
        self.assertEqual(check_repo.toc_entries(TOC.format(flavor="x")), ["Core/Init.lua"])


class SeamTest(unittest.TestCase):
    def test_flags_class_race_and_faction_tokens(self):
        text = 'local a = "HUNTER"\nlocal b = "Troll"\n-- horde only\nlocal ok = ns.Player.classFile\n'
        self.assertEqual([p.split(":")[1] for p in check_repo.seam_violations("Core/X.lua", text)], ["1", "2", "3"])

    def test_flags_profession_names_and_keys(self):
        text = '-- Skinning first\nlocal key = "leatherworking"\nlocal plan = ns.char.professions\nlocal x = "firstaid"\n'
        self.assertEqual([p.split(":")[1] for p in check_repo.seam_violations("Engine/X.lua", text)], ["1", "2", "4"])

    def test_a_toc_may_list_class_and_guide_files_by_name(self):
        toc = "Core\\Init.lua\nClasses\\DRUID.lua\nGuides\\HordeTaurenDruid.lua\n## Notes: DRUID\n"
        self.assertEqual([p.split(":")[1] for p in check_repo.seam_violations("Signpost.toc", toc)], ["4"])
        self.assertEqual([p.split(":")[1] for p in check_repo.seam_violations("Signpost.toc", "Core\\DRUID.lua\n")], ["1"])

    def test_ignores_longer_words(self):
        self.assertEqual(
            check_repo.seam_violations("Core/X.lua", "HUNTERS Trolls human-readable Hordes determining Professions\n"), []
        )

    def test_forbidden_paths(self):
        files = ["tools/cache/q.json", "Data/Quests.generated.lua", "tools/dev.local.json", "tools/bin/x.exe", "ok.lua"]
        self.assertEqual(len(check_repo.check_forbidden(files)), 4)


class BindingsTest(unittest.TestCase):
    XML = (
        '<Bindings>\n<Binding name="X_ONE" header="X">Run("one")</Binding>\n'
        '<Binding name="X_TWO" header="X">Run("two")</Binding>\n</Bindings>\n'
    )
    LUA = 'BINDING_HEADER_X = "X"\nBINDING_NAME_X_ONE = "One"\nBINDING_NAME_X_TWO = "Two"\n'

    def problems(self, xml=XML, lua=LUA, toc=TOC.format(flavor="x"), extra=None):
        """check_bindings on a scratch checkout: Bindings.xml, UI/Labels.lua and one TOC; `extra` adds files."""
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            written = {"Bindings.xml": xml, "UI/Labels.lua": lua, "Signpost.toc": toc, **(extra or {})}
            for name, text in written.items():
                (root / name).parent.mkdir(parents=True, exist_ok=True)
                (root / name).write_text(text, encoding="utf-8")
            return check_repo.check_bindings(root, sorted(written))

    def test_a_complete_set_of_bindings_passes(self):
        self.assertEqual(self.problems(), [])

    def test_no_bindings_file_is_fine(self):
        with tempfile.TemporaryDirectory() as directory:
            self.assertEqual(check_repo.check_bindings(Path(directory), ["UI/Labels.lua"]), [])

    def test_a_binding_without_a_label_is_reported(self):
        problems = self.problems(lua='BINDING_HEADER_X = "X"\nBINDING_NAME_X_ONE = "One"\n')
        self.assertEqual(len(problems), 1)
        self.assertIn("BINDING_NAME_X_TWO", problems[0])

    def test_a_header_without_a_label_is_reported(self):
        problems = self.problems(lua='BINDING_NAME_X_ONE = "One"\nBINDING_NAME_X_TWO = "Two"\n')
        self.assertEqual(len(problems), 1)
        self.assertIn("BINDING_HEADER_X", problems[0])

    def test_a_label_that_is_only_a_comment_or_a_longer_name_does_not_count(self):
        lua = '-- BINDING_NAME_X_ONE = "One"\nBINDING_NAME_X_TWO_MORE = "Two"\nBINDING_HEADER_X = "X"\n'
        problems = self.problems(lua=lua)
        self.assertEqual(len(problems), 2)

    def test_a_label_set_outside_the_addon_folders_does_not_count(self):
        problems = self.problems(lua="", extra={"tests/labels.lua": self.LUA})
        self.assertEqual(len(problems), 3)

    def test_a_toc_must_not_list_the_file(self):
        problems = self.problems(toc=TOC.format(flavor="x") + "Bindings.xml\n")
        self.assertEqual(len(problems), 1)
        self.assertIn("Signpost.toc", problems[0])

    def test_a_binding_needs_a_name(self):
        problems = self.problems(xml='<Bindings><Binding header="X">Run()</Binding></Bindings>')
        self.assertEqual(len(problems), 1)
        self.assertIn("without a name", problems[0])

    def test_malformed_xml_is_reported(self):
        problems = self.problems(xml='<Bindings><Binding name="X_ONE">Run(1 < 2)</Binding></Bindings>')
        self.assertEqual(len(problems), 1)
        self.assertIn("not well-formed", problems[0])

    def test_the_real_bindings_pass(self):
        files = check_repo.tracked_files(check_repo.ROOT)
        self.assertEqual(check_repo.check_bindings(check_repo.ROOT, files), [])


class PackageTest(unittest.TestCase):
    PKGMETA = "package-as: Signpost\n\nembedded-libraries:\n  - libstub\n\nignore:\n  - docs\n  - tools/\n  - CLAUDE.md\n"

    def test_reads_the_ignore_list(self):
        self.assertEqual(package.pkgmeta_ignores(self.PKGMETA), ["docs", "tools", "CLAUDE.md"])

    def test_ships_addon_files_only(self):
        files = ["Signpost.toc", "Core/Init.lua", "docs/PLAN.md", "tools/x.py", ".gitignore", "Media/.gitkeep", "CLAUDE.md"]
        self.assertEqual(package.shipped_files(files, ["docs", "tools", "CLAUDE.md"]), ["Core/Init.lua", "Signpost.toc"])


if __name__ == "__main__":
    unittest.main()
