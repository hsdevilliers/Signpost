import contextlib
import io
import re
import unittest

import guide_travel
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


def world(faction="Horde", borders=True, travel=TRAVEL):
    pack = guide_travel.Pack(guide_travel.Path("."), {"schema": 1}, {"maps": MAPS, "quests": QUESTS, "npcs": NPCS, "travel": travel})
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
        self.assertTrue(steps[0][0].startswith('.todo "border Westland/Northland pass: no crossing coordinates'))
        self.assertEqual(steps[0][1], ".zone 50 >> Go into Northland")
        lonely = world(borders=False, travel={"transports": []})
        start, goal = Place(10, Coord(10, 50, 50), "start"), Place(40, Coord(40, 50, 50), "goal")
        self.assertIsNone(guide_travel.plan_travel(lonely, start, goal))
        todo = guide_travel.no_route_steps(lonely, 10, 40)
        self.assertEqual(todo[0][1], ".zone 40 >> Go to Isle")

    def test_borders_without_coordinates_chain(self):
        pack = guide_travel.Pack(guide_travel.Path("."), {}, {"maps": MAPS})
        entries = [
            ("Borders.lua", 1, {"name": "Westland/Northland pass", "from": [10], "to": [50]}),
            ("Borders.lua", 2, {"name": "Northland/Towne stair", "from": [50], "to": [30], "side": "Horde"}),
        ]
        start, goal = Place(10, Coord(10, 50, 50), "start"), Place(30, Coord(30, 50, 50), "goal")
        plan = guide_travel.plan_travel(World(pack, entries, "Horde"), start, goal)
        steps = guide_travel.plan_steps(self.world, plan)
        self.assertEqual([lines[-1].split(" >>")[0] for lines in steps], [".zone 50", ".zone 30"])
        self.assertTrue(all(lines[0].startswith('.todo "border ') for lines in steps))
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
