"""signpost_tools.learned: the profession records of the learned layer (what trainers teach and charge, the recipes of
the trade skill windows) that Core/LearnProfessions.lua records. Synthetic records, not real data; the last class reads
the file the Lua specs check the recorder against, so the recorder and the importer agree on the format."""

import contextlib
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import import_savedvars
from signpost_tools import datapack, learned
from signpost_tools.savedvars import load_savedvars

ROOT = Path(__file__).resolve().parents[2]
FIXTURE = ROOT / "tests" / "fixtures" / "profession-recorder"


def svc(**fields):
    """A trainer service as the recorder writes it."""
    return fields


def obs(*pairs):
    return [{"skill": skill, "cat": cat} for skill, cat in pairs]


class ServiceTest(unittest.TestCase):
    def test_keeps_only_the_fields_the_pack_has(self):
        raw = {
            "id": 2018,
            "item": 7,
            "n": "Apprentice Beta",
            "r": "Apprentice",
            "cost": 100,
            "lvl": 5,
            "need": 50,
            "line": 200,
            "known": True,
            "player": "Someone-Realm",
            "text": "a line of chat",
        }
        self.assertEqual(
            learned._service(raw),
            {"id": 2018, "item": 7, "n": "Apprentice Beta", "r": "Apprentice", "cost": 100, "lvl": 5, "need": 50, "line": 200},
        )

    def test_no_level_and_no_skill_are_no_requirement_but_zero_is_a_price(self):
        self.assertEqual(learned._service({"id": 1, "cost": 0, "lvl": 0, "need": 0}), {"id": 1, "cost": 0})

    def test_a_service_needs_a_spell_or_a_name(self):
        self.assertIsNone(learned._service({"cost": 5, "lvl": 3}))
        self.assertIsNone(learned._service("a string"))
        self.assertEqual(learned._service({"n": "Named"}), {"n": "Named"})

    def test_odd_values_are_dropped_not_kept(self):
        raw = {"id": 3, "cost": -1, "lvl": 9999, "need": 2.5, "n": "x" * 101, "r": True, "item": 0, "line": "165"}
        self.assertEqual(learned._service(raw), {"id": 3, "line": 165})
        self.assertEqual(learned._service({"id": 3, "cost": 7.0, "lvl": True}), {"id": 3, "cost": 7})

    def test_the_newest_reading_of_a_service_wins_and_a_filtered_window_loses_nothing(self):
        first = [svc(id=1, n="One", cost=100), svc(id=2, n="Two", cost=200)]
        second = [svc(id=2, n="Two", cost=250), svc(id=3, n="Three", cost=300)]
        self.assertEqual(
            learned.merge_services(first, second),
            [svc(id=1, n="One", cost=100), svc(id=2, n="Two", cost=250), svc(id=3, n="Three", cost=300)],
        )
        # the other way round, the other reading is the newest
        self.assertEqual(learned.merge_services(second, first)[1], svc(id=2, n="Two", cost=200))

    def test_a_service_without_a_spell_is_one_per_name_and_rank(self):
        listed = [svc(n="Same", r="Rank 1", cost=10), svc(n="Same", r="Rank 2", cost=20), svc(n="Same", r="Rank 1", cost=11)]
        self.assertEqual(
            learned.merge_services(listed), [svc(n="Same", r="Rank 1", cost=11), svc(n="Same", r="Rank 2", cost=20)]
        )

    def test_a_list_the_parser_made_a_dict_of_is_read_too(self):
        self.assertEqual(learned.merge_services({1: svc(id=5, n="Five")}, {}, None, "junk"), [svc(id=5, n="Five")])


class ObservationTest(unittest.TestCase):
    def test_one_entry_per_skill_then_the_lowest_and_highest_of_each_difficulty(self):
        pairs = [(40, "optimal"), (45, "optimal"), (50, "optimal"), (55, "medium"), (58, "medium"), (70, "easy")]
        self.assertEqual(
            learned.compact_observations(pairs),
            obs((40, "optimal"), (50, "optimal"), (55, "medium"), (58, "medium"), (70, "easy")),
        )
        # the last reading at a skill wins
        self.assertEqual(learned.compact_observations([(50, "optimal"), (50, "medium")]), obs((50, "medium")))

    def test_holds_at_most_eight_entries_however_many_readings(self):
        pairs = [(skill, "optimal" if skill < 100 else "medium" if skill < 150 else "easy" if skill < 200 else "trivial")
                 for skill in range(1, 301)]
        self.assertEqual([entry["skill"] for entry in learned.compact_observations(pairs)], [1, 99, 100, 149, 150, 199, 200, 300])

    def test_bounds_of_where_each_colour_starts(self):
        seen = obs((1, "optimal"), (20, "optimal"), (35, "medium"), (50, "easy"), (70, "trivial"))
        self.assertEqual(
            learned.skill_bounds(seen),
            {"orange": (None, 1), "yellow": (21, 35), "green": (36, 50), "grey": (51, 70)},
        )

    def test_bounds_with_little_known(self):
        self.assertEqual(
            learned.skill_bounds(obs((40, "easy"))),
            {"orange": (None, 40), "yellow": (None, 40), "green": (None, 40), "grey": (41, None)},
        )
        self.assertEqual(learned.skill_bounds(None), {colour: (None, None) for colour in learned.COLOURS})
        # a colour is exact when the last skill of one difficulty and the first of the next are one apart
        exact = learned.skill_bounds(obs((34, "optimal"), (35, "medium")))["yellow"]
        self.assertEqual(exact, (35, 35))

    def test_whatever_is_not_a_skill_with_a_difficulty_is_ignored(self):
        junk = [{"skill": 0, "cat": "optimal"}, {"skill": 5, "cat": "orange"}, {"skill": "x", "cat": "easy"}, "junk"]
        self.assertEqual(learned.compact_observations(learned._observations(junk)), [])


class LayerTest(unittest.TestCase):
    @staticmethod
    def layer(dbs, base=None):
        tables, problems, stats = learned.learned_layer(dbs, base or {})
        return tables["professions"], problems, stats

    def test_services_are_filed_under_the_profession_of_the_service_or_else_of_the_trainer(self):
        db = {
            "learned": {
                "trainers": {
                    3154: {
                        "skill": 165,
                        "t": 5,
                        "services": [
                            svc(id=2018, n="Own line", cost=100, lvl=5, line=165),
                            svc(id=2019, n="Trainer's line", cost=200),
                        ],
                    }
                }
            }
        }
        professions, problems, stats = self.layer([db])
        self.assertEqual(
            professions,
            {
                165: {
                    "trainers": [3154],
                    "services": {
                        3154: [svc(id=2018, n="Own line", cost=100, lvl=5), svc(id=2019, n="Trainer's line", cost=200)]
                    },
                }
            },
        )
        self.assertEqual((problems, stats["trainerServices"]), ([], 2))

    def test_a_trainer_teaching_two_professions_files_only_the_services_that_name_theirs(self):
        db = {
            "learned": {
                "trainers": {
                    9: {"t": 1, "services": [svc(id=1, n="A", line=165), svc(id=2, n="B", line=171), svc(id=3, n="No line")]}
                }
            }
        }
        professions, _, stats = self.layer([db])
        self.assertEqual(sorted(professions), [165, 171])
        self.assertEqual(professions[165]["services"], {9: [svc(id=1, n="A")]})
        self.assertEqual(professions[171]["services"], {9: [svc(id=2, n="B")]})
        self.assertEqual(stats["trainerServices"], 2)

    def test_a_class_trainer_is_reported_and_its_services_are_not_filed(self):
        db = {"learned": {"trainers": {3156: {"t": 1, "services": [svc(id=75, n="A class spell", cost=10, lvl=4)]}}}}
        professions, problems, stats = self.layer([db])
        self.assertEqual(professions, {})
        self.assertEqual(len(problems), 1)
        self.assertIn("learned trainer 3156", problems[0])
        self.assertEqual(stats["trainerServices"], 0)

    def test_services_join_what_another_layer_knows_and_the_learned_reading_wins(self):
        db = {"learned": {"trainers": {3154: {"skill": 165, "t": 5, "services": [svc(id=2, n="Two", cost=250)]}}}}
        base = {
            "professions": {
                165: {
                    "trainers": [3007],
                    "services": {3154: [svc(id=1, n="One", cost=100), svc(id=2, n="Two", cost=200)], 3007: [svc(id=9, n="Nine")]},
                }
            }
        }
        professions, _, _ = self.layer([db], base)
        self.assertEqual(
            professions[165]["services"],
            {3154: [svc(id=1, n="One", cost=100), svc(id=2, n="Two", cost=250)], 3007: [svc(id=9, n="Nine")]},
        )
        self.assertEqual(professions[165]["trainers"], [3154, 3007])

    def test_the_newest_record_of_a_trainer_wins_across_sources(self):
        old = {"learned": {"trainers": {1: {"skill": 165, "t": 10, "services": [svc(id=5, n="Five", cost=100)]}}}}
        new = {"learned": {"trainers": {1: {"skill": 165, "t": 20, "services": [svc(id=5, n="Five", cost=150)]}}}}
        for dbs in ([old, new], [new, old]):
            self.assertEqual(self.layer(dbs)[0][165]["services"], {1: [svc(id=5, n="Five", cost=150)]})

    def test_a_trainer_is_found_by_the_recipes_its_services_teach_when_nothing_names_its_profession(self):
        db = {
            "learned": {
                "trainers": {3155: {"t": 1, "services": [svc(id=2149, n="Boots", cost=50)]}},
                "recipes": {2149: {"n": "Boots", "line": 165, "t": 1}},
            }
        }
        professions, problems, _ = self.layer([db])
        self.assertEqual(problems, [])
        self.assertEqual(professions[165]["trainers"], [3155])
        self.assertEqual(professions[165]["services"], {3155: [svc(id=2149, n="Boots", cost=50)]})

    def test_recipes_are_filed_under_their_skill_line_over_what_another_layer_knows(self):
        db = {
            "learned": {
                "recipes": {
                    2149: {
                        "n": "Boots",
                        "line": 165,
                        "item": 2302,
                        "reagents": {2318: 2, 2320: 1},
                        "obs": obs((40, "optimal"), (50, "optimal"), (55, "medium")),
                        "t": 5,
                    }
                }
            }
        }
        base = {
            "professions": {
                165: {
                    "n": "Test Craft",
                    "recipes": {
                        2149: {"item": 1, "skill": [1, 30, 45, 60], "reagents": {2318: 9}, "src": "trainer", "obs": obs((20, "optimal"))},
                        2152: {"item": 2304, "skill": [1, 20, 30, 40]},
                    },
                }
            }
        }
        professions, problems, stats = self.layer([db], base)
        self.assertEqual(problems, [])
        self.assertEqual(
            professions[165]["recipes"],
            {
                2149: {
                    "n": "Boots",
                    "item": 2302,  # the client's word over the other layer's
                    "skill": [1, 30, 45, 60],  # what the learned layer does not say stays
                    "src": "trainer",
                    "reagents": {2318: 2, 2320: 1},
                    "obs": obs((20, "optimal"), (50, "optimal"), (55, "medium")),  # the observations of both
                },
                2152: {"item": 2304, "skill": [1, 20, 30, 40]},  # another recipe of the profession is kept as it is
            },
        )
        self.assertEqual(stats["recipes"], 1)

    def test_a_recipe_without_a_skill_line_is_filed_where_the_pack_has_it_or_reported(self):
        db = {"learned": {"recipes": {2149: {"n": "Boots", "t": 1}, 777: {"n": "Nowhere", "t": 1}}}}
        base = {"professions": {165: {"recipes": {2149: {"item": 2302}}}}}
        professions, problems, stats = self.layer([db], base)
        self.assertEqual(professions[165]["recipes"][2149], {"item": 2302, "n": "Boots"})
        self.assertEqual(len(problems), 1)
        self.assertIn("learned recipe 777: no skill line", problems[0])
        self.assertEqual(stats["recipes"], 1)

    def test_several_sources_the_newest_reading_per_field_and_the_observations_of_all(self):
        first = {"learned": {"recipes": {5: {"n": "Old name", "line": 165, "item": 50, "obs": obs((10, "optimal")), "t": 10}}}}
        second = {
            "learned": {
                "recipes": {5: {"n": "New name", "line": 165, "reagents": {7: 1}, "obs": obs((30, "medium")), "t": 20}}
            }
        }
        for dbs in ([first, second], [second, first]):
            record = self.layer(dbs)[0][165]["recipes"][5]
            self.assertEqual(record, {"n": "New name", "item": 50, "reagents": {7: 1}, "obs": obs((10, "optimal"), (30, "medium"))})

    def test_the_reagents_of_learned_recipes_are_route_items_so_their_vendors_are_kept(self):
        db = {
            "learned": {
                "recipes": {2149: {"n": "Boots", "line": 165, "reagents": {2318: 2, 2320: 1}, "t": 1}},
                "vendors": {3158: {"items": [2318, 4540], "t": 1}},
            }
        }
        tables, _, stats = learned.learned_layer([db], {})
        self.assertEqual(tables["items"], {2318: {"vendors": [3158]}})
        self.assertEqual(stats["vendorItemsOutsideRoute"], 1)

    def test_nothing_but_the_fields_of_the_schema_reaches_the_layer(self):
        db = {
            "learned": {
                "trainers": {
                    1: {
                        "skill": 165,
                        "t": 1,
                        "services": [svc(id=1, n="One", player="Someplayer-Realm", cost=5, known=True)],
                        "owner": "Someplayer-Realm",
                    }
                },
                "recipes": {7: {"n": "Seven", "line": 165, "chat": "Someplayer says hi", "reagents": {3: 1, "Someplayer": 2}, "t": 1}},
            }
        }
        tables, _, _ = learned.learned_layer([db], {})
        text = json.dumps(tables["professions"])
        for forbidden in ("Someplayer", "chat", "owner", "known", "says hi"):
            self.assertNotIn(forbidden, text)
        self.assertEqual(tables["professions"][165]["recipes"][7], {"n": "Seven", "reagents": {3: 1}})

    def test_tolerates_odd_saved_variables(self):
        db = {
            "learned": {
                "trainers": {1: {"services": "x"}, 2: {"skill": 165, "services": {}}, "x": {"services": []}},
                "recipes": [{"n": "First"}, "junk", {"line": 3}],
            }
        }
        professions, problems, stats = self.layer([db, {}, {"learned": 7}, {"learned": {"recipes": "x"}}])
        self.assertEqual(professions, {165: {"trainers": [2]}})
        self.assertEqual((stats["recipes"], stats["trainerServices"]), (0, 0))
        self.assertEqual(len(problems), 2)  # trainer 1 (no profession) and recipe 1 (no skill line)


class ArchiveTest(unittest.TestCase):
    """What a source has ever recorded accumulates across imports, like the other learned tables."""

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.pack = Path(self._tmp.name)
        datapack.init_stub(self.pack)

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def archive(self) -> dict:
        return json.loads((self.pack / "layers" / learned.ARCHIVE_NAME).read_text(encoding="utf-8"))

    def layer(self) -> dict:
        return datapack.read_layer(self.pack, "learned")["tables"]

    def test_services_and_recipes_add_up_across_imports_and_the_newer_reading_wins(self):
        first = {
            "learned": {
                "trainers": {1: {"skill": 165, "t": 10, "services": [svc(id=1, n="One", cost=100), svc(id=2, n="Two", cost=200)]}},
                "recipes": {5: {"n": "Five", "line": 165, "item": 50, "obs": obs((10, "optimal")), "t": 10}},
            }
        }
        second = {
            "learned": {
                "trainers": {1: {"skill": 165, "t": 20, "services": [svc(id=2, n="Two", cost=250)]}},
                "recipes": {5: {"n": "Five", "line": 165, "obs": obs((40, "easy")), "t": 20}},
            }
        }
        learned.merge_learned(self.pack, [first], "test")
        learned.merge_learned(self.pack, [second], "test")
        professions = self.layer()["professions"]
        self.assertEqual(
            professions[165]["services"], {1: [svc(id=1, n="One", cost=100), svc(id=2, n="Two", cost=250)]}
        )
        self.assertEqual(
            professions[165]["recipes"][5], {"n": "Five", "item": 50, "obs": obs((10, "optimal"), (40, "easy"))}
        )
        # a restarted SavedVariables (an older reading again) does not take back what a later one said
        learned.merge_learned(self.pack, [first], "test")
        self.assertEqual(self.layer()["professions"][165]["services"][1][1], svc(id=2, n="Two", cost=250))

    def test_importing_the_same_file_again_changes_nothing(self):
        db = {
            "learned": {
                "trainers": {1: {"skill": 165, "t": 10, "services": [svc(id=1, n="One", cost=100, lvl=3, line=165)]}},
                "recipes": {
                    5: {
                        "n": "Five",
                        "line": 165,
                        "item": 50,
                        "reagents": {7: 2},
                        "obs": obs((1, "optimal"), (9, "optimal"), (20, "medium")),
                        "t": 10,
                    }
                },
            }
        }
        learned.merge_learned(self.pack, [db], "test")
        archive = (self.pack / "layers" / learned.ARCHIVE_NAME).read_text(encoding="utf-8")
        layer = self.layer()
        learned.merge_learned(self.pack, [db], "test")
        self.assertEqual((self.pack / "layers" / learned.ARCHIVE_NAME).read_text(encoding="utf-8"), archive)
        self.assertEqual(self.layer(), layer)

    def test_the_archive_keeps_nothing_but_the_fields_the_layer_reads(self):
        db = {
            "learned": {
                "trainers": {1: {"skill": 165, "t": 1, "services": [svc(id=1, n="One", player="Someplayer-Realm", known=True)]}},
                "recipes": {7: {"n": "Seven", "line": 165, "t": 1, "chat": "Someplayer says hi"}},
            }
        }
        learned.merge_learned(self.pack, [db], "test")
        text = (self.pack / "layers" / learned.ARCHIVE_NAME).read_text(encoding="utf-8")
        for forbidden in ("Someplayer", "says hi", "known", "chat"):
            self.assertNotIn(forbidden, text)
        self.assertIn('"Seven"', text)

    def test_a_trainer_whose_services_are_junk_keeps_no_services(self):
        db = {"learned": {"trainers": {1: {"skill": 165, "t": 1, "spells": [4], "services": "junk"}}}}
        learned.merge_learned(self.pack, [db], "test")
        archived = self.archive()["source-1"]["learned"]["trainers"]["1"]
        self.assertNotIn("services", archived)
        self.assertEqual(archived["spells"], [4])


class FixtureTest(unittest.TestCase):
    """tests/fixtures/profession-recorder/Signpost.lua is the SavedVariables file the recorder writes in
    tests/learn_professions_spec.lua's scenario (that spec fails when the recorder stops writing exactly this)."""

    def run_main(self, *args):
        out = io.StringIO()
        with mock.patch.object(sys, "argv", ["import_savedvars.py", *args]), contextlib.redirect_stdout(out):
            import_savedvars.main()
        return out.getvalue()

    def import_fixture(self, pack: Path) -> str:
        guides = pack.parent / "no-guides"
        guides.mkdir(exist_ok=True)
        args = ("--merge-learned", "--from", str(FIXTURE), "--pack", str(pack), "--guides", str(guides))
        return self.run_main(*args)

    def test_the_fixture_is_there_and_has_what_the_spec_records(self):
        db = load_savedvars(FIXTURE / "Signpost.lua")["SignpostDB"]
        self.assertGreater(len(db["learned"]["trainers"]), 0)
        self.assertGreater(len(db["learned"]["recipes"]), 0)

    def test_the_import_files_the_services_and_recipes_under_their_professions(self):
        with tempfile.TemporaryDirectory() as tmp:
            pack = Path(tmp) / "pack"
            datapack.init_stub(pack)
            printed = self.import_fixture(pack)
            professions = datapack.read_table(pack, "professions")
            first = json.loads(datapack.layer_path(pack, "learned").read_text(encoding="utf-8"))
            self.import_fixture(pack)
            second = json.loads(datapack.layer_path(pack, "learned").read_text(encoding="utf-8"))
        self.assertIn("recipes", printed)
        self.assertIn("trainerServices", printed)
        self.assertEqual(first["tables"], second["tables"])
        # the profession the recorder's scenario calls Beta: skill line 200 (a trainer), Alpha: 100 (recipes)
        self.assertEqual(sorted(professions), [100, 200])
        self.assertEqual(professions[200]["src"], "learned")
        self.assertEqual(professions[200]["trainers"], [3154])
        services = professions[200]["services"][3154]
        self.assertEqual([service["id"] for service in services], [2018, 2153, 3100])
        self.assertEqual(services[0], {"id": 2018, "n": "Apprentice Beta", "r": "Apprentice", "cost": 100, "lvl": 5})
        self.assertEqual(
            services[2], {"id": 3100, "n": "Journeyman Beta", "r": "Journeyman", "cost": 1500, "lvl": 10, "need": 50}
        )
        recipes = professions[100]["recipes"]
        self.assertEqual(sorted(recipes), [2149, 2152, 9999])
        self.assertEqual(
            recipes[2149],
            {
                "n": "Handstitched Boots",
                "item": 2302,
                "reagents": {2318: 2, 2320: 1},
                "obs": obs((40, "optimal"), (55, "medium")),
            },
        )
        self.assertNotIn("obs", recipes[9999])  # a recipe the character does not know has no difficulty
        # the thresholds of the recipe, as far as two visits tell
        self.assertEqual(
            learned.skill_bounds(recipes[2149]["obs"]),
            {"orange": (None, 40), "yellow": (41, 55), "green": (56, None), "grey": (56, None)},
        )


if __name__ == "__main__":
    unittest.main()
