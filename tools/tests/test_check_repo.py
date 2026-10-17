import unittest

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

    def test_ignores_longer_words(self):
        self.assertEqual(
            check_repo.seam_violations("Core/X.lua", "HUNTERS Trolls human-readable Hordes determining Professions\n"), []
        )

    def test_forbidden_paths(self):
        files = ["tools/cache/q.json", "Data/Quests.generated.lua", "tools/dev.local.json", "tools/bin/x.exe", "ok.lua"]
        self.assertEqual(len(check_repo.check_forbidden(files)), 4)


class PackageTest(unittest.TestCase):
    PKGMETA = "package-as: Signpost\n\nembedded-libraries:\n  - libstub\n\nignore:\n  - docs\n  - tools/\n  - CLAUDE.md\n"

    def test_reads_the_ignore_list(self):
        self.assertEqual(package.pkgmeta_ignores(self.PKGMETA), ["docs", "tools", "CLAUDE.md"])

    def test_ships_addon_files_only(self):
        files = ["Signpost.toc", "Core/Init.lua", "docs/PLAN.md", "tools/x.py", ".gitignore", "Media/.gitkeep", "CLAUDE.md"]
        self.assertEqual(package.shipped_files(files, ["docs", "tools", "CLAUDE.md"]), ["Core/Init.lua", "Signpost.toc"])


if __name__ == "__main__":
    unittest.main()
