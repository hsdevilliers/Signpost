import contextlib
import dataclasses
import io
import json
import re
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import guide_travel
import rebuild_drafts
from guide_travel import Place, World
from signpost_tools import guidefile
from signpost_tools.guidefile import Coord
from tests.guide_fixtures import (
    BORDERS_LUA,
    MAPS,
    NPCS,
    QUESTS,
    TRAVEL,
    TempProject,
    chapter_lua,
    guide_lua,
    write_pack,
)


class GeoTest(unittest.TestCase):
    def setUp(self):
        self.geo = guide_travel.Geo(MAPS)

    def test_world_position_and_back(self):
        # Westland's rectangle: x runs along world y (1000 -> 0), y along world x (1000 -> -1000)
        self.assertEqual(self.geo.world(Coord(10, 50, 50)), (1, 0.0, 500.0))
        self.assertEqual(self.geo.local(10, (1, 0.0, 500.0)), Coord(10, 50.0, 50.0))
        self.assertIsNone(self.geo.local(10, (2, 0.0, 500.0)))  # another world instance

    def test_distance_in_yards(self):
        self.assertAlmostEqual(self.geo.distance(Coord(10, 95, 50), Coord(20, 5, 50)), 100.0)
        self.assertIsNone(self.geo.distance(Coord(10, 50, 50), Coord(40, 50, 50)))  # different continents
        self.assertIsNone(self.geo.distance(Coord(10, 50, 50), Coord(999, 50, 50)))  # unknown map

    def test_zone_of_a_sub_map_and_the_map_tree(self):
        self.assertEqual(self.geo.zone(11), 10)  # a cave map counts as its zone
        self.assertEqual(self.geo.zone(30), 30)  # a city is a zone of its own
        self.assertTrue(self.geo.within(11, 100))
        self.assertFalse(self.geo.within(30, 20))


class PackTest(TempProject):
    def test_reads_tables_and_classes(self):
        write_pack(self.pack_dir, classes={"HUNTER": {"quests": [{"id": "x", "n": "X", "l": 10, "quests": [1, 2]}]}})
        pack = guide_travel.load_pack(self.pack_dir)
        self.assertTrue(pack.present, pack.problems)
        self.assertEqual(pack.table("quests")[101]["n"], "First Steps")
        self.assertEqual(sorted(pack.table("maps")), sorted(MAPS))
        self.assertEqual(pack.table("classes")["HUNTER"]["quests"][0]["quests"], [1, 2])
        self.assertEqual(pack.table("travel")["transports"][0]["kind"], "boat")

    def test_missing_or_other_schema_is_an_empty_pack(self):
        self.assertFalse(guide_travel.load_pack(None).present)
        self.assertFalse(guide_travel.load_pack(self.pack_dir).present)
        write_pack(self.pack_dir)
        text = (self.pack_dir / "_meta.lua").read_text(encoding="utf-8").replace("schema = 1", "schema = 99")
        (self.pack_dir / "_meta.lua").write_text(text, encoding="utf-8")
        pack = guide_travel.load_pack(self.pack_dir)
        self.assertFalse(pack.present)
        self.assertIn("schema 99", pack.problems[0])


def world(faction="Horde", borders=True, travel=TRAVEL, npcs=NPCS):
    pack = guide_travel.Pack(guide_travel.Path("."), {"schema": 1}, {"maps": MAPS, "quests": QUESTS, "npcs": npcs, "travel": travel})
    entries = []
    if borders:
        calls, _ = guidefile.find_register_calls(BORDERS_LUA, "Travel", "RegisterBorders")
        entries = [("Guides/Travel/Borders.lua", 2, entry) for entry in calls[0].args[0]]
    return World(pack, entries, faction)


class FlightNodeTest(unittest.TestCase):
    def test_taxi_pins_land_in_their_zone(self):
        nodes = {node.name: node for node in world().all_nodes}
        self.assertNotIn("zzOLDTowne, Eastland", nodes)  # stale client nodes are dropped
        towne = nodes["Towne, Eastland"]
        self.assertEqual(towne.zone, 30)  # the city whose name the node starts with, not Eastland around it
        self.assertAlmostEqual(towne.coord.x, 50.0)
        self.assertAlmostEqual(towne.coord.y, 50.0)
        self.assertEqual(nodes["Westhold, Westland"].zone, 10)

    def test_faction_and_names(self):
        horde = world("Horde")
        self.assertEqual(sorted(node.name for node in horde.nodes), ["Towne, Eastland", "Westhold, Westland"])
        self.assertEqual(len(horde.nodes_named("allyport", every_faction=True)), 1)
        self.assertTrue(guide_travel.names_match("Towne", "Towne, Eastland"))
        self.assertFalse(guide_travel.names_match("Eastland", "Towne, Eastland"))

    def test_flight_master_records_win(self):
        travel = dict(TRAVEL, flightMasters={9: {"node": "Towne", "p": [30, 40, 60], "side": "Horde"}})
        towne = world(travel=travel).nodes_named("Towne")[0]
        self.assertEqual((towne.coord, towne.exact), (Coord(30, 40.0, 60.0), True))


# The pack's own NPC records carry the service flags (flight master 8, innkeeper 128; the QuestieDB layer's Classic
# baseline): the travel table is empty in the real pack, and these NPCs are what the generator knows of flight masters
# and inns. Fixture coordinates: Westland (50, 50) is the Westhold taxi pin; one map percent there is 10 yards.
SERVICE_NPCS = {
    **NPCS,
    2001: {"n": "Westhold Windmaster", "p": [[10, 51, 50]], "side": "Horde", "flags": 8, "sub": "Wind Rider Master"},
    2002: {"n": "Far Windmaster", "p": [[50, 50, 50]], "side": "Horde", "flags": 8},  # no taxi pin within 100 yd
    2003: {"n": "Allyport Griffon Master", "p": [[10, 20.4, 50]], "side": "Alliance", "flags": 8},
    2006: {"n": "A Horde flight master at Allyport", "p": [[10, 20, 50]], "side": "Horde", "flags": 8},  # no Horde node there
    2004: {"n": "Towne Windmaster, nearer", "p": [[30, 50.5, 50]], "side": "Horde", "flags": 8},
    2005: {"n": "Towne Windmaster", "p": [[30, 52, 49]], "side": "Horde", "flags": 8},
    2101: {"n": "Innkeeper Eastern", "p": [[20, 60, 60]], "side": "Horde", "flags": 132, "sub": "Innkeeper"},
    2102: {"n": "Innkeeper Allied", "p": [[10, 30, 30]], "side": "Alliance", "flags": 128},
    2103: {"n": "Innkeeper Noplace", "side": "Horde", "flags": 128},  # inside an instance: no position
    2104: {"n": "Mere Vendor", "p": [[20, 55, 55]], "side": "Horde", "flags": 4},
}


class ServiceNpcTest(unittest.TestCase):
    def nodes(self, **kwargs):
        return {node.name: node for node in world(npcs=SERVICE_NPCS, **kwargs).nodes}

    def test_flight_master_npcs_position_the_client_nodes_they_stand_at(self):
        westhold = self.nodes()["Westhold, Westland"]
        self.assertEqual((westhold.coord, westhold.exact), (Coord(10, 51.0, 50.0), True))
        self.assertIn("flight master 2001", westhold.origin)
        self.assertIn("NPC record", westhold.origin)
        self.assertEqual(westhold.node_id, 2)  # the client's node ID stays

    def test_the_nearest_npc_of_a_node_wins_and_a_far_one_is_left_out(self):
        towne = self.nodes()["Towne, Eastland"]
        self.assertEqual(towne.coord, Coord(30, 50.5, 50.0))  # 2004 stands closer to the pin than 2005, which has the higher ID
        self.assertIn("flight master 2004", towne.origin)
        for node in world(npcs=SERVICE_NPCS).all_nodes:
            self.assertNotEqual(node.coord, Coord(50, 50.0, 50.0))  # 2002 has no node within NODE_MATCH_YARDS

    def test_an_npc_serves_only_nodes_of_its_side(self):
        alliance = world("Alliance", npcs=SERVICE_NPCS)
        allyport = {node.name: node for node in alliance.nodes}["Allyport, Westland"]
        self.assertEqual((allyport.exact, allyport.coord), (True, Coord(10, 20.4, 50.0)))
        self.assertIn("flight master 2003", allyport.origin)  # 2006 stands nearer, but it is a Horde NPC
        # nodes do not depend on the faction asked for: each keeps the flight master of its own side
        westhold = {node.name: node for node in alliance.all_nodes}["Westhold, Westland"]
        self.assertIn("flight master 2001", westhold.origin)

    def test_a_travel_record_for_the_npc_wins(self):
        travel = dict(TRAVEL, flightMasters={2001: {"node": "Westhold", "p": [10, 60, 50], "side": "Horde"}})
        westhold = self.nodes(travel=travel)["Westhold, Westland"]
        self.assertEqual(westhold.coord, Coord(10, 60.0, 50.0))
        self.assertNotIn("NPC record", westhold.origin)

    def test_a_pack_without_flags_changes_nothing(self):
        plain = world().nodes
        self.assertFalse(any(node.exact for node in plain))

    def test_innkeepers_come_from_their_flag_and_the_travel_table_wins(self):
        inns = {inn.npc: inn for inn in world(npcs=SERVICE_NPCS).inns}
        self.assertEqual(sorted(inns), [2101])  # the vendor, the Alliance inn and the inn without a position are out
        self.assertEqual(inns[2101].coord, Coord(20, 60.0, 60.0))
        self.assertEqual(world(npcs=SERVICE_NPCS).inn_in(20), Coord(20, 60.0, 60.0))
        listed = dict(TRAVEL, inns={2101: {"p": [20, 70, 70], "side": "both"}})
        self.assertEqual([inn.coord for inn in world(npcs=SERVICE_NPCS, travel=listed).inns], [Coord(20, 70.0, 70.0)])
        self.assertEqual([inn.npc for inn in world("Alliance", npcs=SERVICE_NPCS).inns], [2102])


def coordinates_in(text):
    return {match for match in re.findall(r"\b\d+,\d+(?:\.\d+)?,\d+(?:\.\d+)?", text)}


class PlanTest(unittest.TestCase):
    def setUp(self):
        self.world = world()

    def plan(self, start, goal, known=(), bind=None, ready=False):
        start = Place(self.world.zone(start.map), start, "start")
        goal = Place(self.world.zone(goal.map), goal, "goal")
        return guide_travel.plan_travel(self.world, start, goal, list(known), bind, ready)

    def test_walks_over_a_border_crossing(self):
        plan = self.plan(Coord(10, 50, 50), Coord(20, 60, 50))
        self.assertEqual(
            guide_travel.plan_steps(self.world, plan),
            [[".path 10,95.0,50.0 ; 20,5.0,50.0", ".zone 20 >> Cross into Eastland (Westland/Eastland bridge)"]],
        )

    def test_flies_when_both_flight_paths_are_known(self):
        plan = self.plan(Coord(10, 50, 50), Coord(30, 50, 40), known=["Westhold", "Towne"])
        steps = guide_travel.plan_steps(self.world, plan)
        self.assertEqual(steps[-1][-1], ".fly Towne")
        self.assertTrue(steps[-1][0].startswith(".goto 10,50.0,50.0 >> Go to the flight master"))
        # without the flight paths it walks: two crossings, two steps
        walked = guide_travel.plan_steps(self.world, self.plan(Coord(10, 50, 50), Coord(30, 50, 40)))
        self.assertEqual([lines[-1].split(" >>")[0] for lines in walked], [".zone 20", ".zone 30"])

    def test_boat_and_hearth(self):
        plan = self.plan(Coord(20, 50, 50), Coord(40, 50, 50))
        self.assertEqual(
            guide_travel.plan_steps(self.world, plan), [[".boat 20,90.0,90.0 > 40,10.0,10.0 >> Take the boat to Isle"]]
        )
        inn = Place(30, Coord(30, 50, 50), "inn", "Towne")
        back = self.plan(Coord(40, 50, 50), Coord(30, 60, 60), bind=inn, ready=True)
        self.assertEqual(guide_travel.plan_steps(self.world, back), [[".home >> Hearth to Towne"]])
        on_cooldown = self.plan(Coord(40, 50, 50), Coord(30, 60, 60), bind=inn, ready=False)
        kinds = [leg.kind for leg in on_cooldown.legs]
        self.assertIn("boat", kinds)
        self.assertNotIn("hearth", kinds)

    def test_unplaced_crossing_and_no_route_become_todo(self):
        steps = guide_travel.plan_steps(self.world, self.plan(Coord(10, 50, 50), Coord(50, 50, 50)))
        self.assertEqual(len(steps), 1)
        self.assertEqual(
            steps[0][0],
            '.todo "Walk from Westland to Northland: the guide has no waypoints for this yet, so find your own way. '
            'This step is done when you arrive in Northland."',
        )
        self.assertEqual(steps[0][1], ".zone 50 >> Go to Northland")
        lonely = world(borders=False, travel={"transports": []})
        start, goal = Place(10, Coord(10, 50, 50), "start"), Place(40, Coord(40, 50, 50), "goal")
        self.assertIsNone(guide_travel.plan_travel(lonely, start, goal))
        todo = guide_travel.no_route_steps(lonely, 10, 40)
        self.assertEqual(todo[0][1], ".zone 40 >> Go to Isle")
        self.assertIn("different continents", todo[0][0])  # Westland and the Isle are in different worlds: no walking
        self.assertIn("boat, a zeppelin or another ride", todo[0][0])
        self.assertTrue(todo[0][0].endswith('This step is done when you arrive in Isle."'))

    def test_borders_without_coordinates_chain(self):
        pack = guide_travel.Pack(guide_travel.Path("."), {}, {"maps": MAPS})
        entries = [
            ("Borders.lua", 1, {"name": "Westland/Northland pass", "from": [10], "to": [50]}),
            ("Borders.lua", 2, {"name": "Northland/Towne stair", "from": [50], "to": [30], "side": "Horde"}),
        ]
        start, goal = Place(10, Coord(10, 50, 50), "start"), Place(30, Coord(30, 50, 50), "goal")
        plan = guide_travel.plan_travel(World(pack, entries, "Horde"), start, goal)
        steps = guide_travel.plan_steps(self.world, plan)
        # two borders without points are one walk: one step (it never names the zone in between: the guide's list of
        # borders is not the world's, and the step completes on arrival wherever the player went)
        self.assertEqual(len(steps), 1)
        self.assertTrue(steps[0][0].startswith('.todo "Walk from Westland to Towne: the guide has no waypoints'), steps[0][0])
        self.assertEqual(steps[0][1], ".zone 30 >> Go to Towne")
        self.assertEqual(guide_travel.describe_cost(plan), "time unknown (a border without coordinates)")
        # the stair is Horde-only
        self.assertIsNone(guide_travel.plan_travel(World(pack, entries, "Alliance"), start, goal))

    def test_proposals_parse_and_only_copy_known_coordinates(self):
        known = {Coord(10, 95, 50).dsl(), Coord(20, 5, 50).dsl(), Coord(20, 50, 51).dsl(), Coord(30, 50, 99).dsl()}
        known |= {Coord(20, 90, 90).dsl(), Coord(40, 10, 10).dsl(), Coord(10, 50, 50).dsl(), Coord(30, 50, 50).dsl()}
        specs = guidefile.registry()
        for start, goal, fps in (
            (Coord(10, 50, 50), Coord(30, 50, 40), []),
            (Coord(10, 50, 50), Coord(30, 50, 40), ["Westhold", "Towne"]),
            (Coord(10, 50, 50), Coord(40, 50, 50), []),
            (Coord(10, 50, 50), Coord(50, 50, 50), []),
        ):
            text = guide_travel.render_steps(guide_travel.plan_steps(self.world, self.plan(start, goal, fps)))
            self.assertLessEqual(coordinates_in(text), known, text)
            source = guidefile.Source("chapter", "x", "x", text, "x.lua", 1)
            guidefile.parse_source(source, specs)
            self.assertEqual(source.problems, [], text)


class PlaceholderTest(unittest.TestCase):
    """The steps for a change of zone the data cannot place yet say in plain words what the player does."""

    ENTRIES = [
        ("Borders.lua", 1, {"name": "Westland/Northland pass", "from": [10], "to": [50]}),
        ("Borders.lua", 2, {"name": "Northland/Eastland road", "from": [50, 50, 10], "to": [20, 50, 90]}),
        ("Borders.lua", 3, {"name": "Eastland/Towne gate", "from": [20], "to": [30]}),
    ]

    def steps(self, start, goal, entries=None):
        pack = guide_travel.Pack(guide_travel.Path("."), {}, {"maps": MAPS})
        graph = World(pack, self.ENTRIES if entries is None else entries, "Horde")
        plan = guide_travel.plan_travel(graph, Place(graph.zone(start.map), start, "start"), Place(graph.zone(goal.map), goal, "goal"))
        return guide_travel.plan_steps(graph, plan)

    def test_a_placed_crossing_between_two_unplaced_ones_splits_the_walk(self):
        steps = self.steps(Coord(10, 50, 50), Coord(30, 50, 50))
        self.assertEqual([lines[-1].split(" >>")[0] for lines in steps], [".zone 50", ".zone 20", ".zone 30"])
        self.assertTrue(steps[0][0].startswith('.todo "Walk from Westland to Northland: '))
        self.assertEqual(steps[1][0], ".path 50,50.0,10.0 ; 20,50.0,90.0")
        self.assertTrue(steps[2][0].startswith('.todo "Walk from Eastland to Towne: '))

    def test_the_text_never_places_the_step(self):
        # no coordinate, and no `.goto`: a step with a `.goto` in the destination would count as a step of that zone for
        # the `@zone` anchors of the profession tracks
        for steps in (self.steps(Coord(10, 50, 50), Coord(30, 50, 50)), guide_travel.no_route_steps(World(), 10, 40)):
            text = guide_travel.render_steps(steps)
            if ".path" not in text:
                self.assertEqual(coordinates_in(text), set(), text)
            self.assertNotIn(".goto", text)

    def test_the_lines_parse_and_survive_the_comment_and_text_rules(self):
        specs = guidefile.registry()
        for steps in (self.steps(Coord(10, 50, 50), Coord(30, 50, 50)), guide_travel.no_route_steps(World(), 10, 40)):
            source = guidefile.Source("chapter", "x", "x", guide_travel.render_steps(steps), "x.lua", 1)
            guidefile.parse_source(source, specs)
            self.assertEqual(source.problems, [])
            found = [d for step in source.steps() for d in step.directives if d.name == "todo"]
            self.assertTrue(found and all(d.args["quoted"] and d.args["reason"].endswith(".") for d in found))

    def test_plain_text_drops_what_the_parser_would_read(self):
        self.assertEqual(guide_travel._plain('A "B" -- C >> D'), "A 'B' - C > D")

    def test_without_map_data_it_only_says_there_is_no_route(self):
        text = guide_travel.no_route_steps(World(), 10, 40)[0][0]
        self.assertIn("Get from map 10 to map 40: the guide has no route for this yet.", text)

    def test_a_route_of_the_hearth_or_a_ride_is_not_a_placeholder(self):
        graph = world()
        plan = guide_travel.plan_travel(graph, Place(20, Coord(20, 50, 50), "start"), Place(40, Coord(40, 50, 50), "goal"))
        self.assertEqual(guide_travel.plan_steps(graph, plan), [[".boat 20,90.0,90.0 > 40,10.0,10.0 >> Take the boat to Isle"]])


class DefaultPackTest(unittest.TestCase):
    """The data pack is found next to the checkout, or next to the main checkout from inside a git worktree."""

    @staticmethod
    def git(cwd, *args):
        subprocess.run(
            ["git", "-c", "user.name=test", "-c", "user.email=test@example.com", *args], cwd=cwd, check=True, capture_output=True
        )

    def test_a_worktree_finds_the_pack_next_to_the_main_checkout(self):
        if shutil.which("git") is None:
            self.skipTest("git is not installed")
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp).resolve()
            main, pack = base / "Signpost", base / "Signpost_Data"
            main.mkdir()
            pack.mkdir()
            (pack / "_meta.lua").write_text("", encoding="utf-8")
            self.git(main, "init", "-q")
            self.git(main, "commit", "-q", "--allow-empty", "-m", "start")
            nested = base / ".claude" / "worktrees" / "feature"
            self.git(main, "worktree", "add", "-q", str(nested), "-b", "feature")
            self.assertEqual(guide_travel.default_pack_dir(main), pack)
            self.assertEqual(guide_travel.default_pack_dir(nested), pack)  # not the worktrees folder's sibling
            (pack / "_meta.lua").unlink()
            self.assertIsNone(guide_travel.default_pack_dir(nested))  # a folder without _meta.lua is no pack

    def test_the_importer_uses_the_same_default(self):
        import import_savedvars

        expected = guide_travel.default_pack_dir(import_savedvars.devconfig.REPO_ROOT)
        self.assertEqual(import_savedvars.DEFAULT_PACK, expected or import_savedvars.devconfig.REPO_ROOT.parent / "Signpost_Data")


class MoongladeRewriteTest(unittest.TestCase):
    """tools/drafts.json turns the generator's placeholders for the trips to and from Moonglade into text that says how a
    druid goes (tools/rebuild_drafts.py applies it to a drafted guide). It has to match the generator's own words."""

    MAPS = {**MAPS, 60: {"n": "Moonglade", "t": 3, "parent": 100, "world": [1, 100, 100, 0, 0]}}

    @staticmethod
    def rewrites():
        manifest = json.loads((guide_travel.REPO_ROOT / "tools" / "drafts.json").read_text(encoding="utf-8"))
        return {entry["guide"]: entry["rewrites"] for entry in manifest["guides"] if entry.get("rewrites")}

    def placeholder(self, here, there):
        pack = guide_travel.Pack(guide_travel.Path("."), {}, {"maps": self.MAPS})
        return guide_travel.placeholder_lines(World(pack, [], "Horde"), here, there)[0]

    @staticmethod
    def apply(text, rules):
        for rule in rules:
            text = re.sub(rule["match"], rule["with"], text)
        return text

    def test_the_generators_trips_to_and_from_moonglade_are_rewritten(self):
        rules = self.rewrites()
        self.assertEqual(sorted(rules), ["horde-tauren-druid", "horde-windshaper-druid"])
        for guide, guide_rules in rules.items():
            for here, name in ((10, "Westland"), (40, "Isle")):  # the same continent: walk; another one: get
                trip = self.placeholder(here, 60)
                self.assertRegex(trip, r'^\.todo "(Walk|Get) from ' + name + " to Moonglade: ")
                self.assertTrue(
                    self.apply(trip, guide_rules).startswith('.todo "Go to Moonglade: cast Teleport: Moonglade'), guide
                )
                back = self.apply(self.placeholder(60, here), guide_rules)
                self.assertTrue(back.startswith(f'.todo "Return from Moonglade to {name} (VERIFY(beta): hearthstone'), back)
            other = self.placeholder(10, 20)  # a trip that has nothing to do with Moonglade is left alone
            self.assertEqual(self.apply(other, guide_rules), other)

    def test_chapters_written_with_the_old_wording_are_still_rewritten(self):
        old_to = '.todo "travel from Thunder Bluff to Moonglade: the travel graph has no route yet"'
        old_back = '.todo "travel from Moonglade to Thunder Bluff: the travel graph has no route yet"'
        for guide, guide_rules in self.rewrites().items():
            self.assertTrue(self.apply(old_to, guide_rules).startswith('.todo "Go to Moonglade:'), guide)
            self.assertTrue(
                self.apply(old_back, guide_rules).startswith('.todo "Return from Moonglade to Thunder Bluff (VERIFY'), guide
            )


class SimulateTest(TempProject):
    def route(self, text, chapters=None, faction="Horde"):
        files = {"Guides/Test.lua": guide_lua(text, faction=faction)}
        for chapter_id, body in (chapters or {}).items():
            files[f"Guides/Chapters/{chapter_id}.lua"] = chapter_lua(chapter_id, body)
        self.files(files)
        project = guidefile.load_project(self.root)
        guide = project.guides["test-guide"]
        variant = guidefile.variants(project, guide)[0]
        return guidefile.build_route(project, guide, variant)

    def test_uncovered_and_covered_zone_changes(self):
        route = self.route("step\n  .goto 10,50,50\nstep\n  .goto 20,60,50\n")
        sim = guide_travel.simulate(route, world())
        found = [(t.from_zone, t.to_zone, t.before.id, t.after.id) for t in sim.transitions]
        self.assertEqual(found, [(10, 20, "test-guide:1", "test-guide:2")])
        covered = self.route(
            "step\n  .goto 10,50,50\nstep\n  .path 10,95,50 ; 20,5,50\n  .zone 20\nstep\n  .goto 20,60,50\n"
            "step\n  .goto 20,40,40\n  .zone 30\n  .goto 30,50,50\n"
        )
        self.assertEqual(guide_travel.simulate(covered, world()).transitions, [])

    def test_without_a_pack_the_maps_are_the_zones(self):
        route = self.route("step\n  .goto 11,50,50\nstep\n  .goto 10,60,50\n")
        self.assertEqual(len(guide_travel.simulate(route, World()).transitions), 1)  # 11 and 10 differ without the tree
        self.assertEqual(guide_travel.simulate(route, world()).transitions, [])  # the cave is inside Westland

    def test_flight_paths_and_hearth(self):
        route = self.route(
            "step\n  .goto 10,50,50\n  .fp 10,Westhold\n  .hs Westhold\n"
            "step\n  .fly Towne\n"
            "step\n  .goto 30,50,50\n  .fp 30,Towne\n"
            "step\n  .fly Westhold\n"
            "step\n  .goto 10,40,40\n"
            "step\n  .home\n"
            "step\n  .goto 10,45,45\n"
        )
        sim = guide_travel.simulate(route, world())
        self.assertEqual([issue.code for issue in sim.issues], ["fly-without-fp"])  # Towne was not known yet
        self.assertEqual(sim.transitions, [])
        self.assertEqual([state.zone_out for state in sim.steps], [10, 30, 30, 10, 10, 10, 10])
        self.assertEqual(sim.steps[-1].fps, ["Westhold", "Towne"])
        self.assertEqual(sim.steps[-1].bind, "Westhold")

    def test_fly_lands_where_the_guides_fp_says_without_a_pack(self):
        route = self.route(
            "step\n  .goto 30,50,50\n  .fp 30,Towne\n"
            "step\n  .goto 10,50,50\n  .fp 10,Westhold\n  .fly Towne\n"
            "step\n  .goto 30,40,40\n"
        )
        sim = guide_travel.simulate(route, World())
        self.assertEqual(len(sim.transitions), 1)  # 30 -> 10 between the first two steps
        self.assertEqual(sim.steps[-1].zone_out, 30)

    def test_quest_givers_place_steps_without_coordinates(self):
        route = self.route("step\n  .goto 20,50,50\nstep\n  .accept 101\nstep\n  .turnin 101\n")
        sim = guide_travel.simulate(route, world())
        self.assertEqual([(t.from_zone, t.to_zone) for t in sim.transitions], [(20, 10)])

    def test_home_before_hs_and_hearth_cooldown(self):
        route = self.route("step\n  .goto 10,50,50\n  .home\nstep\n  .goto 10,50,50\n  .hs Westhold\nstep\n  .home\n")
        codes = [issue.code for issue in guide_travel.simulate(route, world()).issues]
        self.assertEqual(codes, ["home-without-hs", "hearth-cooldown"])


class FlightPathLessonTest(TempProject):
    """A flight path is proposed where the route passes the flight master and a later zone change would fly from it."""

    ROUTE = (
        "#chapter 1-5 West\n"
        "step\n  .goto 10,50,50\n"  # Westland, beside the Westhold flight master
        "step\n  .goto 30,50,50\n"  # Towne
        "step\n  .goto 30,52,52\n"  # beside the Towne flight master
        "step\n  .goto 10,5,50\n"  # far into Westland again
    )

    def setUp(self):
        super().setUp()
        self.files(
            {
                "Guides/Test.lua": guide_lua("#include west-1-5\n"),
                "Guides/Chapters/west-1-5.lua": chapter_lua("west-1-5", self.ROUTE),
                "Guides/Travel/Borders.lua": BORDERS_LUA,
            }
        )
        write_pack(self.pack_dir, tables={"maps": MAPS, "quests": QUESTS, "npcs": SERVICE_NPCS, "travel": TRAVEL})

    def run_main(self, *args):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            guide_travel.main(["--root", str(self.root), "--pack", str(self.pack_dir), *args])
        return out.getvalue()

    def apply(self, out):
        """What tools/rebuild_drafts.py does with a pass: the first step of each block goes in after its line."""
        found = rebuild_drafts.PROPOSAL.findall(out)
        rebuild_drafts.insert_proposals([(name, int(after), text) for name, after, text in found], self.root)
        return len(found)

    def settle(self, passes=8):
        """Passes until nothing is proposed, as the planner and rebuild_drafts repeat them."""
        for _ in range(passes):
            if not self.apply(self.run_main()):
                return
        self.fail("the generator keeps proposing steps")

    def test_a_flight_that_saves_little_is_not_worth_a_flight_path(self):
        # the flight would save 87 s here and LEARN_GAIN is 90: both zone changes simply walk
        out = self.run_main()
        self.assertNotIn(".fp", out)
        self.assertEqual(out.count("-- insert after"), 2)

    def test_the_flight_paths_go_in_first_and_the_zone_change_flies_in_the_next_pass(self):
        with mock.patch.object(guide_travel, "LEARN_GAIN", 60.0):
            first = self.run_main()
            # zone change 2 waits; zone change 1 leaves from the step the Westhold flight path goes in after, so it waits too
            self.assertIn("waits for the flight path(s) to learn first: Towne, Eastland, Westhold, Westland", first)
            self.assertIn("waits: a flight path step goes in right after west-1-5:1 first", first)
            self.assertEqual(first.count("-- insert after"), 2)
            self.assertIn(
                "-- insert after Guides/Chapters/west-1-5.lua:5; flight path to learn on the way\nstep\n"
                "  .goto 10,51.0,50.0 >> Go to the flight master\n  .fp 10,Westhold\n",
                first,
            )
            self.assertEqual(self.apply(first), 2)
            second = self.run_main()
            # the Westhold flight path is in: zone change 1 now goes in after it, over the border on foot
            self.assertIn("step\n  .path 10,95.0,50.0 ; 20,5.0,50.0", second)
            self.assertNotIn("waits: a flight path step", second)
            self.settle()
            text = (self.root / "Guides/Chapters/west-1-5.lua").read_text(encoding="utf-8")
            self.assertLess(text.index(".fp 10,Westhold"), text.index(".path 10,95.0,50.0"))  # learned before it is left
            self.assertLess(text.index(".fp 30,Towne"), text.index(".fly Westhold"))
            self.assertEqual(text.count(".fp "), 2)  # once each, however many passes
            self.assertIn(".fly Westhold", text)

    def test_the_finished_route_has_no_uncovered_change_and_no_fly_without_fp(self):
        with mock.patch.object(guide_travel, "LEARN_GAIN", 60.0):
            self.settle()
        project = guidefile.load_project(self.root)
        guide = project.guides["test-guide"]
        route = guidefile.build_route(project, guide, guidefile.variants(project, guide)[0])
        graph = World(guide_travel.load_pack(self.pack_dir), project.borders, "Horde")
        sim = guide_travel.simulate(route, graph)
        self.assertEqual(sim.transitions, [])
        self.assertEqual([issue for issue in sim.issues if issue.severity == "error"], [])
        self.assertEqual(sim.steps[-1].fps, ["Westhold", "Towne"])

    def test_it_can_be_switched_off(self):
        with mock.patch.object(guide_travel, "LEARN_GAIN", 60.0):
            self.assertIn("flight path to learn on the way", self.run_main())
            out = self.run_main("--no-learn-flight-paths")
        self.assertNotIn(".fp", out)
        self.assertEqual(out.count("-- insert after"), 2)

    def test_a_route_that_teaches_the_flight_path_itself_is_left_alone(self):
        self.files(
            {
                "Guides/Chapters/west-1-5.lua": chapter_lua(
                    "west-1-5",
                    "#chapter 1-5 West\nstep\n  .goto 10,50,50\n  .fp 10,Westhold\nstep\n  .goto 30,50,50\n  .fp 30,Towne\n"
                    "step\n  .goto 30,52,52\nstep\n  .goto 10,5,50\n",
                )
            }
        )
        with mock.patch.object(guide_travel, "LEARN_GAIN", 60.0):
            out = self.run_main()
        self.assertNotIn("flight path to learn on the way", out)
        self.assertIn("step\n  .goto 30,50.5,50.0 >> Go to the flight master\n  .fly Westhold", out)

    def test_two_zone_changes_that_want_the_same_flight_paths_ask_for_each_once(self):
        self.files(
            {
                "Guides/Chapters/west-1-5.lua": chapter_lua(
                    "west-1-5",
                    self.ROUTE + "step\n  .goto 30,52,52\nstep\n  .goto 10,5,50\n",  # Towne again, then Westland again
                )
            }
        )
        with mock.patch.object(guide_travel, "LEARN_GAIN", 60.0):
            first = self.run_main()
            self.assertIn("zone change(s) 2, 3, 4 fly from or to it", first)  # 1 walks: Towne's is not known yet
            self.assertEqual(first.count("flight path to learn on the way"), 2)  # Towne's and Westhold's, once each
            self.settle()
        text = (self.root / "Guides/Chapters/west-1-5.lua").read_text(encoding="utf-8")
        self.assertEqual(text.count(".fp "), 2)
        self.assertEqual(text.count(".fly "), 3)

    def test_a_zone_change_with_no_route_gets_its_flight_paths_however_little_they_save(self):
        # no borders and no travel table: walking has no route, so the zone change is a placeholder step today
        graph = World(guide_travel.Pack(guide_travel.Path("."), {}, {"maps": MAPS, "npcs": SERVICE_NPCS}), [], "Horde")
        lessons = [
            guide_travel.Lesson(graph.nodes_named(name)[0], 0, None) for name in ("Westhold", "Towne")  # type: ignore[arg-type]
        ]
        hop = guide_travel.Transition(1, None, None, 30, 10, Coord(30, 52, 52), Coord(10, 5, 50), [], None, False)  # type: ignore[arg-type]
        self.assertIsNone(guide_travel.plan_travel(graph, *guide_travel._places(graph, hop)[:2]))
        found = guide_travel.flights_to_learn(graph, hop, lessons, before=3)
        self.assertEqual(sorted(lesson.node.name for lesson in found), ["Towne, Eastland", "Westhold, Westland"])
        # flight paths the route passes only after the zone change cannot help it
        self.assertEqual(guide_travel.flights_to_learn(graph, hop, lessons, before=-1), [])

    def test_a_flight_path_the_route_teaches_later_is_not_asked_for_earlier(self):
        self.files(
            {
                "Guides/Chapters/west-1-5.lua": chapter_lua("west-1-5", self.ROUTE + "step\n  .fp 30,Towne\n"),
            }
        )
        with mock.patch.object(guide_travel, "LEARN_GAIN", 60.0):
            out = self.run_main()
        self.assertNotIn("flight path to learn on the way", out)  # no flight without Towne, and Towne is taught at the end

    def test_a_step_of_a_profession_track_never_takes_a_flight_path_step(self):
        project = guidefile.load_project(self.root)
        guide = project.guides["test-guide"]
        route = guidefile.build_route(project, guide, guidefile.variants(project, guide)[0])
        graph = World(guide_travel.load_pack(self.pack_dir), project.borders, "Horde")
        route.steps[0] = dataclasses.replace(route.steps[0], track="skinning")  # the step beside Westhold's flight master
        found = guide_travel.learnable_flight_paths(route, graph, guide_travel.simulate(route, graph))
        self.assertEqual([lesson.node.name for lesson in found], ["Towne, Eastland"])

    def test_flight_masters_far_from_the_route_are_not_asked_for(self):
        project = guidefile.load_project(self.root)
        guide = project.guides["test-guide"]
        route = guidefile.build_route(project, guide, guidefile.variants(project, guide)[0])
        graph = World(guide_travel.load_pack(self.pack_dir), project.borders, "Horde")
        sim = guide_travel.simulate(route, graph)
        found = {lesson.node.name: lesson.index for lesson in guide_travel.learnable_flight_paths(route, graph, sim)}
        self.assertEqual(found, {"Westhold, Westland": 0, "Towne, Eastland": 1})
        # with a radius of 5 yards the Towne flight master (1 yd from the second step) is still passed, Westhold's (10 yd) not
        near = guide_travel.learnable_flight_paths(route, graph, sim, radius=5.0)
        self.assertEqual([lesson.node.name for lesson in near], ["Towne, Eastland"])


class CommandLineTest(TempProject):
    def run_main(self, *args):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = guide_travel.main(["--root", str(self.root), *args])
        return code, out.getvalue()

    def test_proposes_steps_for_an_uncovered_change(self):
        self.files(
            {
                "Guides/Test.lua": guide_lua("#include west-1-5\n"),
                "Guides/Chapters/west-1-5.lua": chapter_lua("west-1-5", "#chapter 1-5 West\nstep\n  .goto 10,50,50\nstep\n  .goto 20,60,50\n"),
                "Guides/Travel/Borders.lua": BORDERS_LUA,
            }
        )
        write_pack(self.pack_dir)
        code, out = self.run_main("--pack", str(self.pack_dir), "--simulate")
        self.assertEqual(code, 0)
        self.assertIn("1 uncovered zone change(s)", out)
        self.assertIn("insert after Guides/Chapters/west-1-5.lua:5", out)
        self.assertIn("step\n  .path 10,95.0,50.0 ; 20,5.0,50.0\n  .zone 20 >> Cross into Eastland", out)

    def test_ad_hoc_trip_and_no_guides(self):
        self.files({"Guides/Travel/Borders.lua": BORDERS_LUA})
        write_pack(self.pack_dir)
        code, out = self.run_main("--pack", str(self.pack_dir), "--from", "10,50,50", "--to", "20,60,50", "--faction", "Horde")
        self.assertEqual(code, 0)
        self.assertIn(".zone 20 >> Cross into Eastland", out)
        code, out = self.run_main("--no-pack")
        self.assertEqual(code, 0)
        self.assertIn("no guides", out)


if __name__ == "__main__":
    unittest.main()
