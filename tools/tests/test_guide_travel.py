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
from signpost_tools import guidefile, pricing
from signpost_tools.guidefile import Coord
from tests.guide_fixtures import (
    BORDERS_LUA,
    HUNTER_LUA,
    MAPS,
    NPCS,
    QUESTS,
    TRAVEL,
    TempProject,
    chapter_lua,
    guide_lua,
    write_files,
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


# A zone the druids of a guide have their own way to (Classes/DRUID.lua, travelHints; the fixture's map 60 stands for Moonglade): east of
# Eastland, with a cave inside it (61) and a flight master of the travel table's own (the client's taxi map does not list it).
MOON = 60
MOON_MAPS = {
    **MAPS,
    MOON: {"n": "Moonglade", "t": 3, "parent": 100, "world": [1, 1000, -1000, -1000, -2000]},
    61: {"n": "Moonglade Cave", "t": 5, "parent": MOON, "world": [1, 100, -1100, 0, -1200]},
}
MOON_TRAVEL = {**TRAVEL, "flightMasters": {7: {"node": "Moonhaven, Moonglade", "p": [MOON, 50, 50], "side": "Horde"}}}
PASS = {"name": "Eastland/Moonglade pass", "from": [20, 99, 50], "to": [MOON, 1, 50]}  # a border with its points known
PASS_UNPLACED = {"name": "Eastland/Moonglade pass", "from": [20], "to": [MOON]}  # the zones touch; where is not known

HINT_TO = "cast Teleport: Moonglade if you have it (VERIFY(beta): where a druid learns it), else the way is not in the data"
HINT_BACK = "use your hearthstone or a flight path if you have one (VERIFY(beta): the way back is not in the data)"
HINT_UNSAFE = "from Classic memory the road overland runs through Felwood or Winterspring, zones for levels 48 and up"
DRUID_HINT_LUA = """local ADDON_NAME, ns = ...
ns.Classes:Register("DRUID", {
	trainerSpells = {},
	classQuests = {},
	travelHints = {
		[%d] = {
			to = {
				"cast Teleport: Moonglade if you have it (VERIFY(beta): where a druid learns it),",
				"else the way is not in the data",
			},
			back = "use your hearthstone or a flight path if you have one (VERIFY(beta): the way back is not in the data)",
			unsafe = {
				"from Classic memory the road overland runs through Felwood or Winterspring,",
				"zones for levels 48 and up",
			},
		},
	},
})
"""
# The steps the generator writes for a trip to Moonglade and for the way back: the class's way, the warning, and the same `.zone`
# as the plain placeholder (the step is done when the player arrives).
GO_STEP = [
    f'.todo "Go to Moonglade: {HINT_TO}. This step is done when you arrive in Moonglade."',
    f".note Do not walk it: {HINT_UNSAFE}.",
    f".zone {MOON} >> Go to Moonglade",
]
BACK_STEP = [
    f'.todo "Return from Moonglade to Westland: {HINT_BACK}. This step is done when you arrive in Westland."',
    f".note Do not walk it: {HINT_UNSAFE}.",
    ".zone 10 >> Go to Westland",
]


def moon_hints():
    return {MOON: guide_travel.TravelHint(MOON, HINT_TO, HINT_BACK, HINT_UNSAFE)}


def moon_world(extra=(), travel=MOON_TRAVEL, faction="Horde"):
    pack = guide_travel.Pack(
        guide_travel.Path("."), {"schema": 1}, {"maps": MOON_MAPS, "quests": QUESTS, "npcs": NPCS, "travel": travel}
    )
    calls, _ = guidefile.find_register_calls(BORDERS_LUA, "Travel", "RegisterBorders")
    entries = [*calls[0].args[0], *extra]
    return World(pack, [("Borders.lua", number, entry) for number, entry in enumerate(entries, 1)], faction)


class TravelHintTest(unittest.TestCase):
    """A class module's travelHints: the words the generator writes for a trip a class's guide must not walk (a druid's trip to
    and from Moonglade, from Classic memory a road through zones for levels 48 and up) in place of "find your own way"."""

    def trip(self, world, start, goal, known=(), hints=None, bind=None, ready=False):
        plan = guide_travel.plan_travel(world, Place(start, None, "start"), Place(goal, None, "goal"), list(known), bind, ready)
        return plan, guide_travel.steps_for(world, plan, start, goal, hints)

    def test_a_trip_with_no_route_to_or_from_the_zone_says_the_classes_way_and_not_to_walk(self):
        graph = moon_world()
        for start, goal, step in ((10, MOON, GO_STEP), (MOON, 10, BACK_STEP)):
            plan, proposal = self.trip(graph, start, goal, hints=moon_hints())
            self.assertIsNone(plan)  # the graph has no route: that is the case the hint is for
            self.assertEqual(proposal.steps, [step])
            self.assertEqual((proposal.plan, proposal.hint), (None, moon_hints()[MOON]))

    def test_the_step_is_still_done_on_arrival_carries_no_coordinate_and_parses(self):
        _, proposal = self.trip(moon_world(), 10, MOON, hints=moon_hints())
        text = guide_travel.render_steps(proposal.steps)
        self.assertEqual(coordinates_in(text), set())
        self.assertNotIn(".goto", text)  # a `.goto` in the zone would place the step there for the tracks' @zone anchors
        source = guidefile.Source("chapter", "x", "x", text, "x.lua", 1)
        guidefile.parse_source(source, guidefile.registry())
        self.assertEqual(source.problems, [])
        directives = [d for step in source.steps() for d in step.directives]
        self.assertEqual([d.name for d in directives], ["todo", "note", "zone"])
        self.assertTrue(directives[0].args["quoted"])
        self.assertEqual(directives[2].args["map"], MOON)  # what completes the step: the same as the plain placeholder's
        plain = guide_travel.placeholder_lines(moon_world(), 10, MOON)
        self.assertEqual(plain[-1], GO_STEP[-1])
        self.assertEqual(plain[0].split(": ")[0], '.todo "Walk from Westland to Moonglade')  # what it replaces

    def test_without_the_hint_nothing_changes(self):
        graph = moon_world()
        for start, goal in ((10, MOON), (MOON, 10), (10, 20), (10, 40), (20, 30)):
            plan, proposal = self.trip(graph, start, goal)
            _, hinted = self.trip(graph, start, goal, hints={})
            self.assertEqual(proposal.steps, hinted.steps, (start, goal))
            self.assertEqual(
                proposal.steps, guide_travel.no_route_steps(graph, start, goal) if plan is None else guide_travel.plan_steps(graph, plan)
            )
            self.assertIsNone(proposal.hint)
        self.assertIn("find your own way", self.trip(graph, 10, MOON)[1].steps[0][0])

    def test_a_trip_that_has_nothing_to_do_with_the_zone_is_left_alone(self):
        graph = moon_world()
        for start, goal in ((10, 20), (20, 30), (10, 40), (10, 50)):
            _, with_hint = self.trip(graph, start, goal, hints=moon_hints())
            _, without = self.trip(graph, start, goal)
            self.assertEqual(with_hint.steps, without.steps, (start, goal))
            self.assertIsNone(with_hint.hint)

    def test_a_walk_over_the_border_is_never_proposed_even_where_the_data_has_the_points(self):
        for border in (PASS, PASS_UNPLACED):
            graph = moon_world([border])
            plan, _ = self.trip(graph, 10, MOON)
            self.assertIn("cross-todo" if border is PASS_UNPLACED else "cross", [leg.kind for leg in plan.legs])
            walked = guide_travel.plan_steps(graph, plan)
            self.assertTrue(walked, border)  # without the hint the generator proposes the way
            _, proposal = self.trip(graph, 10, MOON, hints=moon_hints())
            self.assertEqual(proposal.steps, [GO_STEP], border)
            _, back = self.trip(graph, MOON, 10, hints=moon_hints())
            self.assertEqual(back.steps, [BACK_STEP], border)
            self.assertNotIn(".path", guide_travel.render_steps(proposal.steps + back.steps))

    @staticmethod
    def leg(kind, a, b, ref=None):
        """A leg of a hand-built plan: the shape is the point here, not what the graph would choose."""
        if kind != "cross":
            return guide_travel.Leg(kind, Place(a, None, "node", "", ref), Place(b, None, "node", "", ref), 60.0, ref)
        crossing = guide_travel.Crossing("test border", Coord(a, 99, 50), Coord(b, 1, 50), a, b, "test")
        return guide_travel.Leg(kind, Place(a, crossing.a, "crossing"), Place(b, crossing.b, "crossing"), 60.0, crossing)

    def test_a_flight_that_ends_in_the_walk_is_replaced_too(self):
        graph = moon_world([PASS_UNPLACED])
        towne = graph.nodes_named("Towne")[0]
        # fly to Towne, then the way over the border into Moonglade on foot (whatever the graph would choose, this is the shape)
        for last in ("cross", "cross-todo"):
            ref = None if last == "cross" else guide_travel.Crossing("test border", None, None, 20, MOON, "test")
            legs = [self.leg("fly", 10, 30, towne), self.leg("cross", 30, 20), self.leg(last, 20, MOON, ref)]
            plan = guide_travel.Plan(legs, 180.0)
            self.assertTrue(guide_travel.overland(plan, MOON))
            proposal = guide_travel.steps_for(graph, plan, 10, MOON, moon_hints())
            self.assertEqual((proposal.steps, proposal.plan), ([GO_STEP], None))
            without = guide_travel.steps_for(graph, plan, 10, MOON)
            self.assertIs(without.plan, plan)  # for a class with no hint, the plan stands
            self.assertIn(".fly Towne", guide_travel.render_steps(without.steps))

    def test_a_flight_into_the_zone_stands_and_so_does_a_flight_out_of_it(self):
        graph = moon_world([PASS])
        known = ["Westhold", "Moonhaven"]
        plan, going = self.trip(graph, 10, MOON, known, moon_hints())
        self.assertEqual([leg.kind for leg in plan.legs if leg.kind != "walk"], ["fly"])
        self.assertIs(going.plan, plan)
        self.assertIsNone(going.hint)
        self.assertEqual(going.steps[0][-1], ".fly Moonhaven")
        self.assertEqual(going.steps, guide_travel.plan_steps(graph, plan))
        _, back = self.trip(graph, MOON, 10, known, moon_hints())
        self.assertEqual(back.steps, [[".goto 60,50.0,50.0 >> Go to the flight master", ".fly Westhold"]])
        self.assertIsNone(back.hint)
        for proposal in (going, back):
            self.assertNotIn("Teleport", guide_travel.render_steps(proposal.steps))
            self.assertNotIn("Do not walk it", guide_travel.render_steps(proposal.steps))

    def test_a_walk_elsewhere_before_the_flight_is_no_reason_to_replace_it(self):
        graph = moon_world([PASS])
        moonhaven = graph.nodes_named("Moonhaven")[0]
        # the Westland/Eastland bridge on foot, then a flight from Eastland into Moonglade: the way in is the flight
        plan = guide_travel.Plan([self.leg("cross", 10, 20), self.leg("fly", 20, MOON, moonhaven)], 120.0)
        self.assertFalse(guide_travel.overland(plan, MOON))
        self.assertTrue(guide_travel.overland(plan, 20))
        proposal = guide_travel.steps_for(graph, plan, 10, MOON, moon_hints())
        self.assertIs(proposal.plan, plan)
        self.assertEqual(proposal.steps, guide_travel.plan_steps(graph, plan))
        self.assertIn(".fly Moonhaven", guide_travel.render_steps(proposal.steps))
        self.assertIsNone(proposal.hint)

    def test_the_hearthstone_into_or_out_of_the_zone_stands(self):
        graph = moon_world([PASS])
        inn = Place(10, Coord(10, 30, 30), "inn", "Westhold Inn")
        _, home = self.trip(graph, MOON, 10, hints=moon_hints(), bind=inn, ready=True)
        self.assertEqual(home.steps, [[".home >> Hearth to Westhold Inn"]])
        self.assertIsNone(home.hint)
        stay = Place(MOON, Coord(MOON, 40, 40), "inn", "Moonglade Inn")
        _, there = self.trip(graph, 10, MOON, hints=moon_hints(), bind=stay, ready=True)
        self.assertEqual(there.steps, [[".home >> Hearth to Moonglade Inn"]])
        # the hearthstone is on cooldown: the way back is the class's words again
        _, cooling = self.trip(graph, MOON, 10, hints=moon_hints(), bind=inn, ready=False)
        self.assertEqual(cooling.steps, [BACK_STEP])

    def test_a_hint_keyed_by_a_map_inside_the_zone_is_for_the_zone(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "Signpost"
            write_files(root, {"Classes/DRUID.lua": DRUID_HINT_LUA % 61})
            project = guidefile.load_project(root)
        hints = guide_travel.class_hints(project, "DRUID", moon_world())
        self.assertEqual(list(hints), [MOON])
        self.assertEqual(hints[MOON].to, HINT_TO)  # the list of lines read as one text
        self.assertEqual(hints[MOON].back, HINT_BACK)
        self.assertEqual(hints[MOON].unsafe, HINT_UNSAFE)
        self.assertEqual(hints[MOON].zone, MOON)

    def test_the_class_decides(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "Signpost"
            write_files(root, {"Classes/DRUID.lua": DRUID_HINT_LUA % MOON, "Classes/HUNTER.lua": HUNTER_LUA})
            project = guidefile.load_project(root)
        graph = moon_world()
        self.assertEqual(list(guide_travel.class_hints(project, "DRUID", graph)), [MOON])
        for cls in ("HUNTER", "SHAMAN", "OTHER", "", None):  # a class with no hints, none at all, or no class module
            self.assertEqual(guide_travel.class_hints(project, cls, graph), {}, cls)
        self.assertIsNone(project.classes["HUNTER"].travel_hints)
        self.assertEqual([p for p in project.problems if p.code == "class-module"], [])

    def test_a_hint_with_a_word_missing_is_a_warning_and_is_left_out(self):
        broken = DRUID_HINT_LUA.replace('\t\t\tback = "use your hearthstone or a flight path if you have one (VERIFY(beta): the way back is not in the data)",\n', "")
        broken = broken.replace("\t\t\tunsafe = {", "\t\t\twhy = \"x\",\n\t\t\tunsafe = {")
        broken = broken.replace("\ttravelHints = {", '\ttravelHints = {\n\t\t["Moonglade"] = { to = "x" },\n\t\t[70] = "words",')
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "Signpost"
            write_files(root, {"Classes/DRUID.lua": broken % MOON})
            project = guidefile.load_project(root)
        messages = [p.message for p in project.problems if p.code == "class-module"]
        self.assertEqual(len(messages), 4, messages)
        self.assertTrue(any("back is missing" in m for m in messages))
        self.assertTrue(any("why is not a known word" in m for m in messages))
        self.assertTrue(any("'Moonglade'" in m for m in messages))
        self.assertTrue(any("travelHints[70]" in m for m in messages))
        self.assertEqual(guide_travel.class_hints(project, "DRUID", moon_world()), {})
        self.assertTrue(all(p.severity == "warning" for p in project.problems if p.code == "class-module"))

    def test_an_empty_or_misplaced_table_is_a_problem_only_when_it_is_wrong(self):
        self.assertEqual(guidefile.travel_hint_problems(None), [])
        self.assertEqual(guidefile.travel_hint_problems({}), [])
        self.assertEqual(len(guidefile.travel_hint_problems([{"to": "x", "back": "y", "unsafe": "z"}])), 1)
        self.assertEqual(guidefile.travel_hint_problems({60: {"to": "a", "back": ["b", "c"], "unsafe": " d "}}), [])
        self.assertEqual(guidefile.wrapped(["a b,", " c ", "", 5, "d"]), "a b, c d")
        self.assertEqual(guidefile.wrapped(None), "")

    def test_the_cost_line_says_no_walk_was_proposed(self):
        graph = moon_world()
        _, proposal = self.trip(graph, 10, MOON, hints=moon_hints())
        self.assertEqual(guide_travel.describe_cost(proposal.plan, proposal.hint), "no walk proposed (the class module's own words stand in)")
        self.assertEqual(guide_travel.describe_cost(None), "no route")

    def test_text_a_class_module_writes_cannot_break_the_step(self):
        hint = guide_travel.TravelHint(MOON, 'say "hi" -- now >> go', "back.", 'a "road" -- of >> doom.')
        lines = guide_travel.hint_lines(moon_world(), hint, 10, MOON)
        self.assertEqual(lines[0], ".todo \"Go to Moonglade: say 'hi' - now > go. This step is done when you arrive in Moonglade.\"")
        self.assertEqual(lines[1], ".note Do not walk it: a 'road' - of > doom.")
        source = guidefile.Source("chapter", "x", "x", guide_travel.render_steps([lines]), "x.lua", 1)
        guidefile.parse_source(source, guidefile.registry())
        self.assertEqual(source.problems, [])


class FlightPathForHintedTripTest(unittest.TestCase):
    """The flight path to learn first: a walk the class's guide must not make is no alternative to a flight."""

    def setUp(self):
        self.graph = moon_world([PASS])
        self.moonhaven = self.graph.nodes_named("Moonhaven")[0]
        self.towne = self.graph.nodes_named("Towne")[0]

    def transition(self, known, start=30):
        fps = [guide_travel.KnownFP(name, 30, 30, None) for name in known]
        return guide_travel.Transition(1, None, None, start, MOON, None, None, fps, None, False)

    def lessons(self, *nodes):
        return [guide_travel.Lesson(node, 0, None) for node in nodes]

    def test_the_walk_is_the_alternative_without_a_hint_and_none_with_one(self):
        transition, lesson = self.transition(["Towne"]), self.lessons(self.moonhaven)
        with mock.patch.object(guide_travel, "LEARN_GAIN", 100000.0):  # a flight must save a day to be worth it...
            self.assertEqual(guide_travel.flights_to_learn(self.graph, transition, lesson, 0), [])
            # ...unless the walk is not an alternative at all
            self.assertEqual(guide_travel.flights_to_learn(self.graph, transition, lesson, 0, moon_hints()), lesson)

    def test_a_flight_that_still_ends_in_the_walk_is_no_lesson(self):
        transition, lesson = self.transition(["Westhold"], start=10), self.lessons(self.towne)
        leg = TravelHintTest.leg
        now = guide_travel.Plan([leg("cross", 10, 20), leg("cross", 20, MOON)], 300.0)
        # Towne's flight path would save the walk to Towne, and then the way into Moonglade is on foot (the graph here is too small
        # to choose it, so the two plans are given)
        better = guide_travel.Plan([leg("fly", 10, 30, self.towne), leg("cross", 30, 20), leg("cross", 20, MOON)], 200.0)
        with mock.patch.object(guide_travel, "LEARN_GAIN", 0.0):
            with mock.patch.object(guide_travel, "plan_travel", side_effect=[now, better]):
                self.assertEqual(guide_travel.flights_to_learn(self.graph, transition, lesson, 0), lesson)
            with mock.patch.object(guide_travel, "plan_travel", side_effect=[now, better]):
                self.assertEqual(guide_travel.flights_to_learn(self.graph, transition, lesson, 0, moon_hints()), [])

    def test_a_trip_that_is_not_the_hinted_ones_is_priced_as_before(self):
        fps = [guide_travel.KnownFP("Westhold", 10, 10, None)]
        transition = guide_travel.Transition(1, None, None, 10, 20, None, None, fps, None, False)
        lesson = self.lessons(self.towne)
        with mock.patch.object(guide_travel, "LEARN_GAIN", 0.0):
            self.assertEqual(
                guide_travel.flights_to_learn(self.graph, transition, lesson, 0, moon_hints()),
                guide_travel.flights_to_learn(self.graph, transition, lesson, 0),
            )


class TravelHintProjectTest(TempProject):
    """A druid's guide and a hunter's guide walk the same route to Moonglade and back: only the druid's gets the class's words."""

    ROUTE = "#chapter 1-5 Moon\nstep\n  .goto 10,50,50\nstep\n  .goto 60,50,50\nstep\n  .goto 10,40,40\n"

    def setUp(self):
        super().setUp()
        self.files(
            {
                "Guides/Druid.lua": guide_lua("#include moon-1-5\n", gid="druid-guide", classes=("DRUID",)),
                "Guides/Hunter.lua": guide_lua("#include moon-1-5\n", gid="hunter-guide", classes=("HUNTER",)),
                "Guides/Chapters/moon-1-5.lua": chapter_lua("moon-1-5", self.ROUTE),
                "Guides/Travel/Borders.lua": BORDERS_LUA,
                "Classes/DRUID.lua": DRUID_HINT_LUA % MOON,
                "Classes/HUNTER.lua": HUNTER_LUA,
            }
        )
        write_pack(self.pack_dir, tables={"maps": MOON_MAPS, "quests": QUESTS, "npcs": NPCS, "travel": MOON_TRAVEL})

    def run_main(self, *args):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            guide_travel.main(["--root", str(self.root), "--pack", str(self.pack_dir), *args])
        return out.getvalue()

    def blocks(self, out):
        return [text.rstrip("\n") for _, _, text in rebuild_drafts.PROPOSAL.findall(out)]

    def test_the_druids_guide_gets_the_classes_words_and_the_hunters_does_not(self):
        druid = self.run_main("--guide", "druid-guide")
        self.assertIn("2 uncovered zone change(s)", druid)
        self.assertEqual(druid.count("no walk proposed"), 2)
        self.assertEqual(self.blocks(druid), [guide_travel.render_steps([GO_STEP]), guide_travel.render_steps([BACK_STEP])])
        hunter = self.run_main("--guide", "hunter-guide")
        self.assertIn("2 uncovered zone change(s)", hunter)
        self.assertNotIn("Teleport", hunter)
        self.assertNotIn("Do not walk it", hunter)
        self.assertNotIn("no walk proposed", hunter)
        self.assertIn("Walk from Westland to Moonglade: the guide has no waypoints for this yet", hunter)
        self.assertIn("Walk from Moonglade to Westland: the guide has no waypoints for this yet", hunter)

    def test_the_steps_go_in_cover_the_zone_changes_and_nothing_is_proposed_again(self):
        for _ in range(4):
            found = rebuild_drafts.PROPOSAL.findall(self.run_main("--guide", "druid-guide"))
            if not found:
                break
            rebuild_drafts.insert_proposals([(name, int(after), text) for name, after, text in found], self.root)
        text = (self.root / "Guides/Chapters/moon-1-5.lua").read_text(encoding="utf-8")
        self.assertEqual(text.count("Do not walk it"), 2)
        self.assertIn(f"  .zone {MOON} >> Go to Moonglade", text)
        self.assertIn("  .zone 10 >> Go to Westland", text)
        self.assertIn("0 uncovered zone change(s)", self.run_main("--guide", "druid-guide"))
        project = guidefile.load_project(self.root)
        self.assertEqual([p for p in project.problems if p.severity == "error"], [])

    def test_a_flight_the_route_has_learned_is_used_instead_of_the_words(self):
        self.files(
            {
                "Guides/Chapters/moon-1-5.lua": chapter_lua(
                    "moon-1-5",
                    "#chapter 1-5 Moon\nstep\n  .goto 10,50,50\n  .fp 10,Westhold\n"
                    f"step\n  .goto {MOON},50,50\n  .fp {MOON},Moonhaven\n"
                    "step\n  .goto 10,40,40\nstep\n  .fly Moonhaven\nstep\n  .goto 60,55,55\n",
                ),
            }
        )
        out = self.run_main("--guide", "druid-guide")
        self.assertEqual(out.count("no walk proposed"), 1)  # the first trip into Moonglade: no flight path yet
        first, back = self.blocks(out)
        self.assertEqual(first, guide_travel.render_steps([GO_STEP]))
        self.assertIn(".fly Westhold", back)  # the way back flies, now that both flight paths are known: no words, no warning
        self.assertNotIn("Do not walk it", back)

    def test_the_cli_takes_the_class_for_one_trip(self):
        trip = ["--from", "10,50,50", "--to", f"{MOON},50,50", "--faction", "Horde"]
        druid = self.run_main(*trip, "--class", "DRUID")
        self.assertIn(f"-- Westland (10) -> Moonglade ({MOON}): no walk proposed", druid)
        self.assertIn(guide_travel.render_steps([GO_STEP]), druid)
        for args in (trip, [*trip, "--class", "HUNTER"]):
            plain = self.run_main(*args)
            self.assertIn("find your own way", plain)
            self.assertNotIn("Teleport", plain)


class RepoTravelHintTest(unittest.TestCase):
    """The repository's own class modules: the druid's words for Moonglade, and nothing for the hunter."""

    @classmethod
    def setUpClass(cls):
        cls.project = guidefile.load_project(guide_travel.REPO_ROOT)

    def test_the_druid_has_words_for_moonglade_and_the_hunter_has_none(self):
        hints = self.project.classes["DRUID"].travel_hints
        self.assertEqual(list(hints), [1450])  # Moonglade's uiMapID in the pack's maps
        to, back, unsafe = (guidefile.wrapped(hints[1450][word]) for word in guidefile.TRAVEL_HINT_WORDS)
        self.assertIn("cast Teleport: Moonglade if you have it", to)  # the old wording of the drafted chapters...
        self.assertIn("VERIFY(beta): where a druid learns it", to)
        self.assertIn("else the way is not in the data", to)
        self.assertIn("hearthstone or a flight path", back)  # ...and the way back
        self.assertIn("the way back is not in the data", back)
        self.assertIn("Classic memory", unsafe)  # and that the road is not safe, as far as Classic remembers it
        self.assertIn("Felwood or Winterspring", unsafe)
        self.assertIn("not safe at your level", unsafe)
        self.assertEqual([p for p in self.project.problems if p.code == "class-module"], [])
        for token, module in self.project.classes.items():
            if token != "DRUID":
                self.assertIsNone(module.travel_hints, token)

    def test_the_manifest_no_longer_rewrites_the_generators_moonglade_words(self):
        # the words are the generator's now (Classes/DRUID.lua travelHints): two places would drift
        manifest = json.loads((guide_travel.REPO_ROOT / "tools" / "drafts.json").read_text(encoding="utf-8"))
        for entry in manifest["guides"]:
            for rewrite in entry.get("rewrites", []):
                self.assertNotIn("Moonglade", rewrite["match"] + rewrite["with"], entry["guide"])

    def test_the_trolls_hunter_guide_gets_none_of_it(self):
        guide = self.project.guides["horde-troll-hunter"]
        variants = guidefile.variants(self.project, guide)
        self.assertEqual({variant.cls for variant in variants}, {"HUNTER"})
        pack_dir = guide_travel.default_pack_dir(guide_travel.REPO_ROOT)
        pack = guide_travel.load_pack(pack_dir) if pack_dir else guide_travel.Pack()
        graph = World(pack, self.project.borders, "Horde")
        for variant in variants:
            self.assertEqual(guide_travel.class_hints(self.project, variant.cls, graph), {})
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            args = ["--guide", "horde-troll-hunter"] + (["--pack", str(pack_dir)] if pack_dir else ["--no-pack"])
            guide_travel.main(args)
        for word in ("Teleport", "Do not walk it", "no walk proposed", "Moonglade"):
            self.assertNotIn(word, out.getvalue())
        chapters = "".join(
            path.read_text(encoding="utf-8") for path in (guide_travel.REPO_ROOT / "Guides" / "Chapters").glob("troll-hunter-*.lua")
        )
        for word in ("Teleport", "Do not walk it", "Moonglade"):
            self.assertNotIn(word, chapters)

    def test_moonglade_is_map_1450_in_the_data_pack(self):
        pack_dir = guide_travel.default_pack_dir(guide_travel.REPO_ROOT)
        if pack_dir is None:
            self.skipTest("no data pack: the map IDs are the pack's")
        graph = World(guide_travel.load_pack(pack_dir), self.project.borders, "Horde")
        self.assertEqual((graph.geo.name(1450), graph.geo.kind(1450), graph.zone(1450)), ("Moonglade", 3, 1450))
        hints = guide_travel.class_hints(self.project, "DRUID", graph)
        self.assertEqual(list(hints), [1450])
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            for cls in ("DRUID", "HUNTER"):
                guide_travel.main(
                    ["--pack", str(pack_dir), "--from", "1456,50,50", "--to", "1450,50,50", "--faction", "Horde", "--class", cls]
                )
        druid, hunter = out.getvalue().split("-- Thunder Bluff", 2)[1:]
        self.assertIn("Go to Moonglade: cast Teleport: Moonglade if you have it", druid)
        self.assertIn(".zone 1450 >> Go to Moonglade", druid)
        self.assertIn("Walk from Thunder Bluff to Moonglade: the guide has no waypoints", hunter)
        self.assertNotIn("Teleport", hunter)


# A ride as Guides/Travel/Borders.lua writes it: the zones only (the island Isle, map 40, is another world than Westland, 10).
RIDE = {
    "name": "Isle/Westland airship",
    "from": [40],
    "to": [10],
    "side": "Horde",
    "oneWay": True,
    "ride": {
        "kind": "zeppelin",
        "label": "airship",
        "wait": 450,
        "waitText": "7 to 8 minutes",
        "fromText": "the west dock",
        "toText": "the plateau beside Towne",
        "verify": ["the dock", "the airship's name", "whether it runs early"],
    },
}
RIDE_STEP = [
    ".zone 10 >> Take the airship from the west dock (Isle) to the plateau beside Towne (Westland)",
    ".note Expect to wait about 7 to 8 minutes for it.",
    '.todo "Not verified in the game: the dock, the airship\'s name and whether it runs early. '
    'This step is done when you arrive in Westland."',
]
RIDE_LUA = """local ADDON_NAME, ns = ...
ns.Travel:RegisterBorders({
	{
		name = "Isle/Westland airship",
		from = { 40 },
		to = { 10 },
		side = "Horde",
		oneWay = true,
		ride = {
			kind = "zeppelin",
			label = "airship",
			wait = 450,
			waitText = "7 to 8 minutes",
			fromText = "the west dock",
			toText = "the plateau beside Towne",
			verify = { "the dock", "the airship's name", "whether it runs early" },
		},
	},
})
"""


class RideTest(unittest.TestCase):
    """A ride in Guides/Travel/Borders.lua: a boat, zeppelin or airship between two zones whose docks nobody has recorded."""

    def world(self, faction="Horde", travel=TRAVEL, entries=None):
        pack = guide_travel.Pack(
            guide_travel.Path("."), {"schema": 1}, {"maps": MAPS, "quests": QUESTS, "npcs": NPCS, "travel": travel}
        )
        listed = [RIDE] if entries is None else entries
        return World(pack, [("Borders.lua", number, entry) for number, entry in enumerate(listed, 1)], faction)

    @staticmethod
    def trip(world, start, goal):
        plan = guide_travel.plan_travel(world, Place(start, None, "start"), Place(goal, None, "goal"))
        return plan, guide_travel.plan_steps(world, plan) if plan else guide_travel.no_route_steps(world, start, goal)

    def test_a_ride_without_docks_is_one_real_step_with_the_wait_and_what_is_unverified(self):
        plan, steps = self.trip(self.world(), 40, 10)
        self.assertEqual([leg.kind for leg in plan.legs if leg.kind != "walk"], ["ride-todo"])
        self.assertEqual(steps, [RIDE_STEP])
        self.assertEqual(guide_travel.describe_cost(plan), "time unknown (a ride whose docks are not recorded)")
        text = guide_travel.render_steps(steps)
        self.assertEqual(coordinates_in(text), set())  # no dock position is made up
        self.assertNotIn(".goto", text)
        source = guidefile.Source("chapter", "x", "x", text, "x.lua", 1)
        guidefile.parse_source(source, guidefile.registry())
        self.assertEqual(source.problems, [])
        todo = [d for step in source.steps() for d in step.directives if d.name == "todo"]
        self.assertTrue(todo and todo[0].args["quoted"])

    def test_the_guides_wait_is_priced_and_an_unrecorded_dock_costs_extra(self):
        plan, _ = self.trip(self.world(), 40, 10)
        walks = 2 * guide_travel.UNKNOWN_WALK  # to the dock and from it: neither position is known
        self.assertEqual(plan.seconds, walks + 450 + guide_travel.TRANSPORT_ACROSS + guide_travel.TODO_PENALTY)
        slow = {**RIDE, "ride": {**RIDE["ride"], "wait": 900}}
        self.assertEqual(self.trip(self.world(entries=[slow]), 40, 10)[0].seconds - plan.seconds, 450)

    def test_it_is_for_one_faction_and_one_way(self):
        for world, start, goal in ((self.world("Alliance"), 40, 10), (self.world(), 10, 40)):
            plan, steps = self.trip(world, start, goal)
            self.assertIsNone(plan)
            self.assertIn("different continents", steps[0][0])  # the generic placeholder, as before
        self.assertEqual([t for t in self.world("Alliance").transports if not t.placed], [])  # the pack's boat is for both
        self.assertEqual([t.zone_a for t in self.world().transports if not t.placed], [40])

    def test_a_ride_someone_recorded_replaces_it_and_keeps_its_name_wait_and_direction(self):
        recorded = {"kind": "zeppelin", "from": [40, 10, 10], "to": [10, 90, 50], "side": "Horde"}
        world = self.world(travel=dict(TRAVEL, transports=[*TRAVEL["transports"], recorded]))
        self.assertEqual(len(world.transports), 2)  # the fixture's boat and the one ride
        plan, steps = self.trip(world, 40, 10)
        self.assertEqual(steps, [[".zeppelin 40,10.0,10.0 > 10,90.0,50.0 >> Take the airship to Westland"]])
        ride = next(t for t in world.transports if t.placed and t.zone_a == 40)
        self.assertEqual((ride.wait, ride.oneway, ride.label), (450.0, True, "airship"))
        self.assertIsNone(self.trip(world, 10, 40)[0])  # still one way: the recorded ride does not run back
        # the fixture's boat is not touched
        self.assertEqual(self.trip(world, 20, 40)[1], [[".boat 20,90.0,90.0 > 40,10.0,10.0 >> Take the boat to Isle"]])

    def test_a_ride_that_runs_both_ways_says_where_it_leaves_and_lands_for_each_direction(self):
        both = {key: value for key, value in RIDE.items() if key != "oneWay"}
        world = self.world(entries=[both])
        back = self.trip(world, 10, 40)[1][0][0]
        self.assertEqual(back, ".zone 40 >> Take the airship from the plateau beside Towne (Westland) to the west dock (Isle)")
        self.assertEqual(self.trip(world, 40, 10)[1], [RIDE_STEP])

    def test_a_ride_with_no_words_still_says_what_to_take_and_what_is_missing(self):
        bare = {**RIDE, "ride": {"kind": "boat"}}
        lines = self.trip(self.world(entries=[bare]), 40, 10)[1][0]
        self.assertEqual(lines[0], ".zone 10 >> Take the boat from Isle to Westland")
        self.assertEqual(len(lines), 2)  # no wait is known, so no note
        self.assertEqual(
            lines[1], '.todo "Not verified in the game: where the dock is. This step is done when you arrive in Westland."'
        )
        self.assertEqual(self.world(entries=[bare]).transports[-1].wait, guide_travel.TRANSPORT_WAIT)

    def test_a_ride_with_docks_in_the_data_is_a_placed_transport(self):
        placed = {**RIDE, "from": [40, 10, 10], "to": [10, 90, 50]}
        world = self.world(entries=[placed])
        self.assertTrue(world.transports[0].placed)
        self.assertEqual(self.trip(world, 40, 10)[1], [[".zeppelin 40,10.0,10.0 > 10,90.0,50.0 >> Take the airship to Westland"]])

    def test_a_ride_that_is_not_a_boat_or_zeppelin_is_left_out_and_is_never_a_crossing(self):
        for ride in ({"kind": "carpet"}, {"label": "airship"}, "zeppelin"):
            world = self.world(entries=[{**RIDE, "ride": ride}])
            self.assertEqual(world.transports, self.world(entries=[]).transports, ride)  # only the pack's own boat
            self.assertEqual(len(world.crossings), 0, ride)

    def test_nothing_else_changes(self):
        with_ride, without = self.world(), self.world(entries=[])
        self.assertEqual(with_ride.crossings, without.crossings)
        self.assertEqual(with_ride.nodes, without.nodes)
        self.assertEqual(with_ride.inns, without.inns)
        self.assertEqual(with_ride.transports[:-1], without.transports)
        self.assertEqual([t.zone_a for t in with_ride.transports[-1:]], [40])
        for start, goal in ((10, 20), (10, 40), (20, 40), (40, 20), (20, 30)):  # none of these trips leaves the island by the ride
            a, b = self.trip(with_ride, start, goal), self.trip(without, start, goal)
            self.assertEqual(b[1], a[1], (start, goal))

    def test_the_tool_proposes_it_where_a_route_leaves_the_island(self):
        with tempfile.TemporaryDirectory() as tmp:
            root, pack = Path(tmp) / "Signpost", Path(tmp) / "pack"
            files = {
                "Guides/Test.lua": guide_lua("#include isle-1-5\n"),
                "Guides/Chapters/isle-1-5.lua": chapter_lua(
                    "isle-1-5", "#chapter 1-5 Isle\nstep\n  .goto 40,50,50\nstep\n  .goto 10,60,50\n"
                ),
                "Guides/Travel/Borders.lua": RIDE_LUA,
            }
            write_files(root, files)
            write_pack(pack)
            out = io.StringIO()
            with contextlib.redirect_stdout(out):
                guide_travel.main(["--root", str(root), "--pack", str(pack)])
        self.assertIn("1 uncovered zone change(s)", out.getvalue())
        self.assertIn("time unknown (a ride whose docks are not recorded)", out.getvalue())
        found = rebuild_drafts.PROPOSAL.findall(out.getvalue())  # the form tools/rebuild_drafts.py and the planner insert
        self.assertEqual([lines.rstrip("\n") for _, _, lines in found], [guide_travel.render_steps([RIDE_STEP])])

    def test_the_repos_ride_has_the_zones_and_no_dock_position(self):
        project = guidefile.load_project(guide_travel.REPO_ROOT)
        rides = [entry for _, _, entry in project.borders if isinstance(entry, dict) and "ride" in entry]
        self.assertEqual([entry["name"] for entry in rides], ["Zephras Isle/Mulgore airship"])
        ride = rides[0]
        # VERIFY(beta): from fan guides, nothing seen in the game; map IDs only until a ride is recorded
        self.assertEqual((ride["from"], ride["to"], ride["side"], ride["oneWay"]), ([2521], [1412], "Horde", True))
        self.assertEqual((ride["ride"]["kind"], ride["ride"]["wait"]), ("zeppelin", 450))
        self.assertEqual(ride["ride"]["waitText"], "7 to 8 minutes")
        pack_dir = guide_travel.default_pack_dir(guide_travel.REPO_ROOT)
        if pack_dir is None:
            self.skipTest("no data pack: the Skyborne's islands are in the pack's maps")
        pack = guide_travel.load_pack(pack_dir)
        horde = World(pack, project.borders, "Horde")
        plain = World(pack, [b for b in project.borders if not (isinstance(b[2], dict) and "ride" in b[2])], "Horde")
        self.assertEqual(horde.crossings, plain.crossings)  # the ride is no crossing
        self.assertEqual([(t.zone_a, t.zone_b) for t in horde.transports], [(2521, 1412)])
        self.assertEqual(plain.transports, [])
        self.assertEqual(World(pack, project.borders, "Alliance").transports, [])


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

    # Westland (10,50,50) and Eastland (20,50,50) are 1000 yards apart (GeoTest); the Isle (40) is another continent.
    NO_ROUTE = 'step\n  .todo "travel from there to here: the travel graph has no route yet"\n  .zone {zone}\n'

    def hop(self, zone, goto, prices=None, first="10,50,50"):
        route = self.route(f"step\n  .goto {first}\n" + self.NO_ROUTE.format(zone=zone) + f"step\n  .goto {goto}\n")
        return guide_travel.simulate(route, world(), prices)

    def test_a_zone_change_with_no_route_costs_the_walk_between_the_places(self):
        # it used to cost nothing: the `.zone` step leaves the player nowhere in particular, and the walk to the next place was never measured
        sim = self.hop(20, "20,50,50")
        self.assertEqual([step.seconds for step in sim.steps], [0.0, 0.0, pricing.PRICES.walk(1000.0)])
        self.assertAlmostEqual(sim.steps[2].seconds, 1000 / 7)
        self.assertEqual(sim.steps[2].clock, 3 * guide_travel.STEP_SECONDS + sim.steps[2].seconds)  # the hearthstone clock moves on too

    def test_a_change_of_continent_with_no_route_costs_the_trip_between_continents(self):
        sim = self.hop(40, "40,50,50")
        self.assertEqual(sim.steps[2].seconds, pricing.PRICES.continent)
        # a change of continent with no travel step at all is no cheaper (the lint reports it; the simulation prices it like the planner does)
        bare = guide_travel.simulate(self.route("step\n  .goto 10,50,50\nstep\n  .goto 40,50,50\n"), world())
        self.assertEqual(bare.steps[1].seconds, pricing.PRICES.continent)
        self.assertEqual(len(bare.transitions), 1)

    def test_the_walk_after_a_crossing_starts_at_the_crossing(self):
        route = self.route("step\n  .goto 10,50,50\nstep\n  .path 10,95,50 ; 20,5,50\n  .zone 20\nstep\n  .goto 20,50,50\n")
        sim = guide_travel.simulate(route, world())
        self.assertAlmostEqual(sim.steps[1].seconds, (450 + 100) / 7)  # to the border and over it
        self.assertAlmostEqual(sim.steps[2].seconds, 450 / 7)  # from the border to the next place: this was never priced

    def test_a_flight_to_a_place_the_data_does_not_give_leaves_no_old_point_to_walk_from(self):
        # the client's taxi pins here have no position: the flight lands in a zone, but nowhere the walk can measure from
        taxi = [{"id": 1, "n": "Towne, Eastland", "faction": 1}, {"id": 2, "n": "Westhold, Westland", "faction": 1}]
        maps = {**MAPS, 100: {**MAPS[100], "taxi": taxi}}
        pack = guide_travel.Pack(guide_travel.Path("."), {"schema": 1}, {"maps": maps, "quests": QUESTS, "npcs": NPCS, "travel": TRAVEL})
        route = self.route("step\n  .goto 10,50,50\n  .fp 10,Westhold\nstep\n  .goto 30,50,50\n  .fp 30,Towne\nstep\n  .fly Westhold\nstep\n  .goto 10,40,40\n")
        sim = guide_travel.simulate(route, World(pack, [], "Horde"))
        self.assertEqual((sim.steps[2].zone_out, sim.steps[2].coord_out), (10, None))
        self.assertEqual(sim.steps[2].seconds, pricing.PRICES.unknown_flight)
        self.assertEqual(sim.steps[3].seconds, 0.0)  # not a walk from Towne, where the player no longer is

    def test_prices_can_be_given_and_travel_seconds_add_up(self):
        slow = dataclasses.replace(pricing.PRICES, walk_speed=3.5, detour=1.0)
        fast = dataclasses.replace(pricing.PRICES, walk_speed=14.0)
        self.assertAlmostEqual(self.hop(20, "20,50,50", slow).steps[2].seconds, 2 * 1000 / 7)
        self.assertAlmostEqual(self.hop(20, "20,50,50", fast).steps[2].seconds, 1000 / 14)
        sim = self.hop(20, "20,50,50")
        self.assertAlmostEqual(sim.steps[-1].clock, sum(step.seconds for step in sim.steps) + len(sim.steps) * guide_travel.STEP_SECONDS)

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
