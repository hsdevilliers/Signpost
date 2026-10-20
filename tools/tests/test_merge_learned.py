import contextlib
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import import_savedvars
from signpost_tools import datapack, learned, luawriter

GORNEK = "Creature-0-1465-1-47-3143-00004F2B3C"
POSTER = "GameObject-0-1465-1-47-1617-00004F2B41"
PLAYER = "Player-1465-0A1B2C3D"
PET = "Pet-0-1465-1-47-3100-01004F2B42"
MAPS = {1411: {"n": "Durotar", "t": 3}, 1413: {"n": "The Barrens", "t": 3}, 1414: {"n": "Kalimdor", "t": 2}}


def pos(map_id, x, y, t=100.0, wx=1000.0, wy=2000.0, **extra):
    """A position as Core/Util.lua's PlayerPosition records it."""
    return {"map": map_id, "x": x, "y": y, "t": t, "wx": wx, "wy": wy, "instance": 1, "instanceType": "none", **extra}


def seen(event, guid, name, position, when=1790000000):
    """An event log entry as Core/Debug.lua writes it at an NPC window."""
    npc = {"id": 1, "name": name, "guid": guid, "pos": position}
    return {"e": event, "t": 100.0, "time": when, "a": {"n": 0}, "s": {"npc": npc}}


def zone_change(prev, now, when=1790000000):
    return {"e": "ZONE_CHANGED_NEW_AREA", "t": 100.0, "time": when, "a": {"n": 0}, "s": {"pos": now, "prev": prev}}


DUROTAR_EDGE = pos(1411, 1.2, 40.0, t=100.0, wx=1000.0)
BARRENS_EDGE = pos(1413, 98.76, 40.0, t=101.0, wx=1007.0)


class EntityTest(unittest.TestCase):
    def test_reads_npcs_and_objects_only(self):
        self.assertEqual(learned.entity(GORNEK), ("npcs", 3143))
        self.assertEqual(learned.entity("Vehicle-0-1465-1-47-3144-00004F2B3C"), ("npcs", 3144))
        self.assertEqual(learned.entity(POSTER), ("objects", 1617))
        for guid in (PLAYER, PET, "Item-1465-0-4000000001", "", None, 42):
            self.assertIsNone(learned.entity(guid), guid)

    def test_clusters_sightings_into_at_most_three_spots(self):
        points = [(1411, 10.0, 10.0, 2), (1411, 10.5, 10.0, 2), (1411, 30.0, 30.0, 1), (1411, 50.0, 50.0, 1)]
        points += [(1413, 10.0, 10.0, 1)]
        spots = learned.cluster(points)
        self.assertEqual(spots[0], [1411, 10.25, 10.0])
        self.assertEqual(len(spots), 3)


class LearnedLayerTest(unittest.TestCase):
    def test_npc_and_object_positions_from_learn_and_the_event_log(self):
        db = {
            "learned": {"npcs": {3143: {"n": "Gornek", "map": 1411, "x": 42.1, "y": 68.3, "t": 5, "c": 3}}},
            "eventLog": [
                seen("GOSSIP_SHOW", GORNEK, "Gornek", pos(1411, 42.5, 68.3)),
                seen("QUEST_DETAIL", GORNEK, "Gornek", pos(1411, 55.0, 70.0)),
                seen("QUEST_DETAIL", POSTER, "Wanted Poster", pos(1411, 44.0, 70.0)),
                seen("QUEST_DETAIL", GORNEK, "Gornek", {"map": 1411}),  # no position (an instance)
                {"e": "QUEST_ACCEPTED", "t": 1, "time": 1, "a": {"n": 1, 1: 4641}},  # no snapshot
            ],
        }
        tables, problems, stats = learned.learned_layer([db], {"maps": MAPS})
        # three visits at 42.1 and one sighting at 42.5 average to 42.2; the far sighting is a second spot
        self.assertEqual(tables["npcs"], {3143: {"n": "Gornek", "p": [[1411, 42.2, 68.3], [1411, 55.0, 70.0]]}})
        self.assertEqual(tables["objects"], {1617: {"n": "Wanted Poster", "p": [[1411, 44.0, 70.0]]}})
        self.assertEqual((problems, stats["npcs"], stats["objects"]), ([], 1, 1))

    def test_players_and_pets_are_never_read(self):
        db = {
            "eventLog": [
                seen("QUEST_DETAIL", PLAYER, "Someplayer", pos(1411, 40.0, 40.0)),
                seen("GOSSIP_SHOW", PET, "Fluffy", pos(1411, 41.0, 41.0)),
            ]
        }
        tables, _, _ = learned.learned_layer([db], {})
        text = json.dumps(tables)
        self.assertNotIn("Someplayer", text)
        self.assertNotIn("Fluffy", text)
        self.assertEqual((tables["npcs"], tables["objects"]), ({}, {}))

    def test_only_walked_zone_changes_from_the_event_log_become_crossings(self):
        log = [
            zone_change(DUROTAR_EDGE, BARRENS_EDGE),
            zone_change(DUROTAR_EDGE, pos(1413, 50.0, 50.0, t=101.0, wx=1600.0)),  # teleport
            zone_change(DUROTAR_EDGE, pos(1413, 98.7, 40.0, t=101.0, wx=1007.0, taxi=True)),  # flight
            zone_change(DUROTAR_EDGE, pos(1413, 98.7, 40.0, t=109.0, wx=1007.0)),  # stale previous position
            zone_change(DUROTAR_EDGE, pos(1413, 98.7, 40.0, t=101.0, wx=1007.0, instance=0)),  # another world
            zone_change(DUROTAR_EDGE, pos(1413, 98.7, 40.0, t=101.0, wx=1007.0, instanceType="party")),
            zone_change(DUROTAR_EDGE, pos(1414, 30.0, 40.0, t=101.0, wx=1007.0)),  # a continent map
            zone_change(DUROTAR_EDGE, pos(1411, 2.0, 40.0, t=101.0, wx=1007.0)),  # same map
            zone_change(None, BARRENS_EDGE),
        ]
        tables, _, _ = learned.learned_layer([{"eventLog": log}], {"maps": MAPS})
        self.assertEqual(
            tables["travel"]["crossings"],
            [{"from": [1411, 1.2, 40.0], "to": [1413, 98.76, 40.0], "src": "learned", "name": "Durotar/The Barrens"}],
        )

    def test_crossings_both_ways_over_one_spot_are_one_crossing(self):
        db = {
            "learned": {
                "crossings": [
                    {"from": {"map": 1413, "x": 98.8, "y": 40.0}, "to": {"map": 1411, "x": 1.24, "y": 40.0}, "c": 1},
                    {"from": {"map": 1413, "x": 50.0, "y": 90.0}, "to": {"map": 1411, "x": 50.0, "y": 1.0}, "c": 2},
                ]
            },
            "eventLog": [zone_change(DUROTAR_EDGE, BARRENS_EDGE)],
        }
        crossings = learned.learned_layer([db], {})[0]["travel"]["crossings"]
        self.assertEqual(
            crossings,
            [
                {"from": [1411, 1.22, 40.0], "to": [1413, 98.78, 40.0], "src": "learned"},
                {"from": [1411, 50.0, 1.0], "to": [1413, 50.0, 90.0], "src": "learned"},
            ],
        )

    def test_quest_links_join_what_the_other_layers_know(self):
        db = {
            "learned": {
                "quests": {
                    4641: {"start": {"npc": 3143}, "finish": {"npc": 3287}, "t": 1},
                    790: {"start": {"obj": 1617}, "t": 1},
                    5: {"t": 1},
                }
            }
        }
        base = {"quests": {4641: {"n": "Quest One", "s": {"npc": [9999, 3143], "item": [123]}, "e": {"npc": [3143]}}}}
        quests = learned.learned_layer([db], base)[0]["quests"]
        self.assertEqual(quests[4641], {"s": {"npc": [3143, 9999], "item": [123]}, "e": {"npc": [3287, 3143]}})
        self.assertEqual(quests[790], {"s": {"obj": [1617]}})
        self.assertNotIn(5, quests)

    def test_vendors_only_for_the_items_the_route_touches(self):
        with tempfile.TemporaryDirectory() as tmp:
            guides = Path(tmp)
            (guides / "Chapters").mkdir()
            (guides / "Chapters" / "zone.lua").write_text(
                'ns.Chapters:Register("zone", [[\nstep\n  .buy 2516,200\n  .sticky .collect 4540,5\n]])\n',
                encoding="utf-8",
            )
            db = {"learned": {"vendors": {3158: {"items": [117, 159, 2320, 2516, 4540], "t": 1}}}}
            base = {
                "items": {159: {"n": "Item One", "vendors": [3159]}},
                "professions": {165: {"recipes": {"2149": {"item": 1, "reagents": {"2320": 1, "2318": 2}}}}},
            }
            tables, _, stats = learned.learned_layer([db], base, [guides])
        self.assertEqual(
            tables["items"],
            {
                159: {"vendors": [3158, 3159]},  # known to another layer
                2320: {"vendors": [3158]},  # a profession reagent
                2516: {"vendors": [3158]},  # a guide step buys it
                4540: {"vendors": [3158]},  # a guide step collects it
            },
        )
        self.assertEqual(stats["vendorItemsOutsideRoute"], 1)

    def test_trainers_join_their_profession(self):
        db = {
            "learned": {
                "trainers": {
                    3154: {"spells": [1, 2], "skill": 165, "t": 1},  # skill line read at the trainer
                    3155: {"spells": [2149], "t": 1},  # teaches a known recipe
                    3156: {"spells": [75], "t": 1},  # a class trainer
                }
            }
        }
        base = {"professions": {165: {"trainers": [3007], "recipes": {"2149": {"item": 1}}}}}
        tables, problems, _ = learned.learned_layer([db], base)
        self.assertEqual(tables["professions"], {165: {"trainers": [3154, 3155, 3007]}})
        self.assertEqual(len(problems), 1)
        self.assertIn("learned trainer 3156", problems[0])

    def test_flight_masters_from_learned_flight_nodes(self):
        taxi = {
            "Razor Hill": {"map": 1411, "x": 53.53, "y": 43.65, "npc": 3310, "id": 25, "faction": 1, "t": 5, "c": 2},
            "Old Name": {"map": 1411, "x": 53.5, "y": 43.6, "npc": 3310, "t": 1, "c": 1},
            "Nowhere": {"map": 1411, "x": 1.0, "y": 1.0, "t": 1, "c": 1},
        }
        tables, problems, _ = learned.learned_layer([{"learned": {"taxi": taxi}}], {})
        self.assertEqual(
            tables["travel"]["flightMasters"], {3310: {"node": "Razor Hill", "p": [1411, 53.53, 43.65], "side": "Horde"}}
        )
        self.assertEqual(problems, ["flight node 'Nowhere': learned without its flight master's NPC ID"])

    def test_several_sources_are_combined(self):
        first = {"learned": {"npcs": {3143: {"n": "Gornek", "map": 1411, "x": 42.0, "y": 68.0, "t": 5, "c": 1}}}}
        second = {"learned": {"npcs": {3143: {"n": "Gornek", "map": 1411, "x": 42.4, "y": 68.0, "t": 9, "c": 1}}}}
        tables, _, _ = learned.learned_layer([first, second], {})
        self.assertEqual(tables["npcs"][3143]["p"], [[1411, 42.2, 68.0]])

    def test_tolerates_odd_saved_variables(self):
        db = {
            "learned": {"npcs": [{"map": 1411, "x": 1.0, "y": 2.0}], "crossings": {}, "taxi": [], "quests": "x"},
            "eventLog": {},
        }
        tables, problems, _ = learned.learned_layer([db, {}, {"learned": 7}], {})
        self.assertEqual(tables["npcs"], {1: {"p": [[1411, 1.0, 2.0]]}})
        self.assertEqual((tables["travel"]["crossings"], problems), ([], []))


class BuildTest(unittest.TestCase):
    def test_learned_positions_override_and_links_add_up(self):
        with tempfile.TemporaryDirectory() as tmp:
            pack = Path(tmp)
            datapack.init_stub(pack)
            datapack.write_layer(pack, "client", {"maps": MAPS}, "client dumpmaps")
            datapack.write_layer(
                pack,
                "questie",
                {"npcs": {3143: {"n": "Gornek", "p": [[1411, 40.0, 60.0]]}}, "quests": {4641: {"s": {"npc": [9999]}}}},
                "QuestieDB",
            )
            db = {
                "learned": {
                    "npcs": {3143: {"n": "Gornek", "map": 1411, "x": 42.1, "y": 68.3, "t": 5, "c": 1}},
                    "quests": {4641: {"start": {"npc": 3143}, "t": 5}},
                },
                "eventLog": [zone_change(DUROTAR_EDGE, BARRENS_EDGE)],
            }
            stats = learned.merge_learned(pack, [db], "test")
            datapack.build(pack, "test")
            npc = datapack.read_table(pack, "npcs")[3143]
            quest = datapack.read_table(pack, "quests")[4641]
            travel = datapack.read_table(pack, "travel")
            meta = datapack.read_meta(pack)
        self.assertEqual((npc["p"], npc["src"]), ([[1411, 42.1, 68.3]], "questie,learned"))
        self.assertEqual(quest["s"], {"npc": [3143, 9999]})
        self.assertEqual(travel["crossings"][0]["src"], "learned")
        self.assertEqual(sorted(meta["layers"]), ["client", "learned", "questie"])
        self.assertEqual((stats["npcs"], stats["quests"], stats["crossings"]), (1, 1, 1))


class AccumulationTest(unittest.TestCase):
    """The learned layer is built from everything a source ever recorded, not from the last read alone."""

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.pack = Path(self._tmp.name)
        datapack.init_stub(self.pack)

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def layer(self) -> dict:
        return json.loads(datapack.layer_path(self.pack, "learned").read_text(encoding="utf-8"))["tables"]

    @staticmethod
    def npc(name, x, count=1, when=5):
        return {"n": name, "map": 1411, "x": x, "y": 50.0, "t": when, "c": count}

    def test_records_evicted_from_saved_variables_survive_the_next_import(self):
        learned.merge_learned(self.pack, [{"learned": {"npcs": {3143: self.npc("Gornek", 42.1)}}}], "test")
        learned.merge_learned(self.pack, [{"learned": {"npcs": {3144: self.npc("Other", 20.0)}}}], "test")
        self.assertEqual(sorted(self.layer()["npcs"]), ["3143", "3144"])

    def test_importing_fewer_sources_drops_nothing(self):
        dev = {"learned": {"npcs": {3143: self.npc("Gornek", 42.1)}}}
        play = {"eventLog": [seen("GOSSIP_SHOW", POSTER, "Wanted Poster", pos(1411, 44.0, 70.0))]}
        learned.merge_learned(self.pack, [dev, play], "test", labels=["local", "also-play"])
        both = self.layer()
        learned.merge_learned(self.pack, [dev], "test", labels=["local"])
        self.assertEqual(self.layer(), both)
        self.assertIn("1617", both["objects"])

    def test_importing_the_same_file_again_changes_nothing(self):
        db = {
            "learned": {"npcs": {3143: self.npc("Gornek", 42.1, count=4)}, "vendors": {3143: {"items": [159, 4540]}}},
            "eventLog": [zone_change(DUROTAR_EDGE, BARRENS_EDGE), seen("GOSSIP_SHOW", GORNEK, "Gornek", pos(1411, 42.5, 50.0))],
        }
        learned.merge_learned(self.pack, [db], "test")
        archive = (self.pack / "layers" / learned.ARCHIVE_NAME).read_text(encoding="utf-8")
        layer = self.layer()
        learned.merge_learned(self.pack, [db], "test")
        self.assertEqual((self.pack / "layers" / learned.ARCHIVE_NAME).read_text(encoding="utf-8"), archive)
        self.assertEqual(self.layer(), layer)

    def test_the_fuller_record_of_a_source_wins_and_vendor_items_add_up(self):
        first = {"learned": {"npcs": {3143: self.npc("Gornek", 42.0, count=1)}, "vendors": {9: {"items": [1, 2]}}}}
        second = {"learned": {"npcs": {3143: self.npc("Gornek", 45.0, count=3)}, "vendors": {9: {"items": [2, 3]}}}}
        learned.merge_learned(self.pack, [first], "test")
        learned.merge_learned(self.pack, [second], "test")
        archived = json.loads((self.pack / "layers" / learned.ARCHIVE_NAME).read_text(encoding="utf-8"))["source-1"]
        self.assertEqual(archived["learned"]["npcs"]["3143"]["x"], 45.0)
        self.assertEqual(archived["learned"]["vendors"]["9"]["items"], [1, 2, 3])
        # a restarted SavedVariables (counts back at 1) does not replace the fuller record
        learned.merge_learned(self.pack, [first], "test")
        archived = json.loads((self.pack / "layers" / learned.ARCHIVE_NAME).read_text(encoding="utf-8"))["source-1"]
        self.assertEqual(archived["learned"]["npcs"]["3143"]["x"], 45.0)

    def test_the_archive_keeps_only_what_the_layer_reads_of_the_event_log(self):
        entry = seen("GOSSIP_SHOW", GORNEK, "Gornek", pos(1411, 42.5, 50.0))
        entry["s"]["player"] = "Someone-Realm"
        entry["a"] = {"text": "chat words"}
        chatter = {"e": "CHAT_MSG_SAY", "time": 1790000001, "s": {"text": "hello"}}
        learned.merge_learned(self.pack, [{"eventLog": [entry, chatter]}], "test")
        text = (self.pack / "layers" / learned.ARCHIVE_NAME).read_text(encoding="utf-8")
        for forbidden in ("Someone-Realm", "chat words", "hello", "CHAT_MSG_SAY"):
            self.assertNotIn(forbidden, text)
        self.assertIn("Creature-0-1465-1-47-3143", text)


class CommandLineTest(unittest.TestCase):
    def run_main(self, *args):
        out = io.StringIO()
        with mock.patch.object(sys, "argv", ["import_savedvars.py", *args]), contextlib.redirect_stdout(out):
            import_savedvars.main()
        return out.getvalue()

    def test_merge_learned_from_two_machines_is_idempotent(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            pack, guides, dev, play = root / "pack", root / "Guides", root / "dev", root / "play"
            for folder in (guides, dev, play):
                folder.mkdir()
            datapack.init_stub(pack)
            npc = {"n": "Gornek", "map": 1411, "x": 42.1, "y": 68.3, "t": 5, "c": 1}
            luawriter.write_lua(dev / "Signpost.lua", [], [("SignpostDB", {"learned": {"npcs": {3143: npc}}})])
            log = [seen("GOSSIP_SHOW", POSTER, "Wanted Poster", pos(1411, 44.0, 70.0))]
            luawriter.write_lua(play / "Signpost.lua", [], [("SignpostDB", {"eventLog": log})])
            args = ("--merge-learned", "--from", str(dev), "--also", str(play), "--pack", str(pack), "--guides", str(guides))
            printed = self.run_main(*args)
            first = json.loads(datapack.layer_path(pack, "learned").read_text(encoding="utf-8"))
            self.run_main(*args)
            second = json.loads(datapack.layer_path(pack, "learned").read_text(encoding="utf-8"))
            objects = datapack.read_table(pack, "objects")
        self.assertIn("learned layer: 1 npcs, 1 objects", printed)
        self.assertIn("data pack rebuilt", printed)
        self.assertEqual(first["tables"], second["tables"])
        self.assertNotIn(str(root), first["origin"])
        self.assertEqual(objects[1617]["p"], [[1411, 44.0, 70.0]])

    def test_also_needs_merge_learned(self):
        with self.assertRaises(SystemExit), contextlib.redirect_stderr(io.StringIO()):
            self.run_main("--json", "--also", "somewhere")
        with self.assertRaises(SystemExit), contextlib.redirect_stderr(io.StringIO()):
            self.run_main("--json", "--contributions", "somewhere")

    def test_contributions_fold_each_contributors_files_without_double_counting(self):
        def npc(name, x, count):
            return {"n": name, "map": 1411, "x": x, "y": 50.0, "t": 5, "c": count}

        def save(path, db):
            path.parent.mkdir(parents=True, exist_ok=True)
            luawriter.write_lua(path, [], [("SignpostDB", db)])

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            pack, guides, dev, shared = root / "pack", root / "Guides", root / "dev", root / "shared"
            for folder in (guides, dev):
                folder.mkdir()
            datapack.init_stub(pack)
            save(dev / "Signpost.lua", {})
            mine = shared / "ab12cd34"
            save(mine / "Signpost-classic_beta-20261020-100000.lua", {"learned": {"npcs": {3143: npc("Gornek", 42.0, 1)}}})
            save(
                mine / "Signpost-classic_beta-20261021-100000.lua",
                {"learned": {"npcs": {3143: npc("Gornek", 45.0, 3), 3144: npc("Other", 20.0, 1)}}},
            )
            other = shared / "ff00ee11"
            log = [seen("GOSSIP_SHOW", POSTER, "Wanted Poster", pos(1411, 44.0, 70.0))]
            save(other / "Signpost-classic_beta-20261020-120000.lua", {"eventLog": log})
            args = ("--merge-learned", "--from", str(dev), "--contributions", str(shared), "--pack", str(pack))
            args += ("--guides", str(guides))
            printed = self.run_main(*args)
            path = datapack.layer_path(pack, "learned")
            first = json.loads(path.read_text(encoding="utf-8"))["tables"]
            archive = json.loads((pack / "layers" / learned.ARCHIVE_NAME).read_text(encoding="utf-8"))
            self.run_main(*args)
            second = json.loads(path.read_text(encoding="utf-8"))["tables"]
        self.assertIn("learned layer: 2 npcs, 1 objects", printed)
        self.assertEqual(first["npcs"]["3143"]["p"], [[1411, 45.0, 50.0]])  # the later, fuller copy wins
        self.assertEqual(sorted(archive), ["contrib-ab12cd34-classic_beta", "contrib-ff00ee11-classic_beta", "local"])
        self.assertEqual(first, second)


if __name__ == "__main__":
    unittest.main()
