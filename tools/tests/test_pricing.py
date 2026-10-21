"""signpost_tools/pricing.py: one price for travel, read from one place by the planner, the travel simulation and the guide simulator."""

import dataclasses
import json
import tempfile
import unittest
from pathlib import Path

import guide_travel
import planner as engine
from signpost_tools import pricing
from signpost_tools.pricing import Prices


class PricesTest(unittest.TestCase):
    def test_walking_flying_and_riding(self):
        p = Prices()
        self.assertEqual(p.walk(700.0), 100.0)  # 7 yards a second, the straight line
        self.assertEqual(p.walk(0.0), 0.0)
        self.assertEqual(p.walk(None), p.unknown_walk)
        self.assertEqual(p.flight(2500.0), p.flight_overhead + 100.0)
        self.assertEqual(p.flight(None), p.unknown_flight)
        self.assertEqual(p.transport(400.0), p.transport_wait + 20.0)
        self.assertEqual(p.transport(None), p.transport_wait + p.transport_across)  # a ride between continents is not measured

    def test_the_detour_lengthens_every_walk_and_nothing_else(self):
        far = dataclasses.replace(Prices(), detour=1.25)
        self.assertEqual(far.walk(700.0), 125.0)
        self.assertEqual(far.flight(2500.0), Prices().flight(2500.0))
        self.assertEqual(far.ferry, Prices().ferry)

    def test_the_ferry_and_the_trip_between_continents(self):
        p = Prices()
        self.assertEqual(p.ferry, p.transport_wait + p.transport_across)
        self.assertEqual(p.ferry, 420.0)  # the seven minutes the planner's --ferry always was
        self.assertEqual(p.continent, 900.0)  # and the quarter of an hour it charged when it had no capital to route through
        self.assertEqual(dataclasses.replace(p, dock_walk=0.0).continent, p.ferry)

    def test_prices_are_immutable(self):
        with self.assertRaises(dataclasses.FrozenInstanceError):
            Prices().detour = 2.0  # type: ignore[misc]


class LoadTest(unittest.TestCase):
    def load(self, text):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "sim_params.json"
            path.write_text(text, encoding="utf-8")
            return pricing.load(path)

    def test_the_parameters_file_overrides_by_name_and_notes_are_ignored(self):
        p = self.load('{"kill_seconds": 12, "travel": {"_note": "x", "detour": 1.25, "dock_walk": 120}}')
        self.assertEqual((p.detour, p.dock_walk), (1.25, 120.0))
        self.assertEqual(p.walk_speed, Prices().walk_speed)  # what is not named keeps its default
        self.assertEqual(p.continent, 180.0 + 240.0 + 240.0)

    def test_no_section_or_no_file_is_the_defaults(self):
        self.assertEqual(self.load('{"kill_seconds": 12}'), Prices())
        self.assertEqual(self.load('{"travel": {}}'), Prices())
        self.assertEqual(pricing.load(Path(tempfile.gettempdir()) / "no-such-dir" / "sim_params.json"), Prices())

    def test_a_typo_or_a_bad_value_is_an_error_not_a_silent_default(self):
        for text in (
            '{"travel": {"walk_spedd": 8}}',
            '{"travel": {"detour": "1.2"}}',
            '{"travel": {"detour": -1}}',
            '{"travel": {"walk_speed": 0}}',
            '{"travel": {"flight_speed": 0}}',
            '{"travel": {"detour": true}}',
            '{"travel": [1, 2]}',
        ):
            with self.assertRaises(ValueError, msg=text):
                self.load(text)

    def test_the_prices_in_use_are_the_ones_the_repositorys_parameters_file_gives(self):
        self.assertEqual(pricing.PRICES, pricing.load())
        raw = json.loads(pricing.PARAMS_FILE.read_text(encoding="utf-8"))
        self.assertIn("travel", raw)  # the hook is there (and says so) even when nothing is overridden


class OnePlaceTest(unittest.TestCase):
    """The planner, the travel graph and the simulation read the same numbers: none of them keeps a copy."""

    def test_guide_travel_names_are_the_shared_prices(self):
        p = pricing.PRICES
        self.assertEqual(
            (
                guide_travel.WALK_SPEED,
                guide_travel.UNKNOWN_WALK,
                guide_travel.FLIGHT_OVERHEAD,
                guide_travel.FLIGHT_SPEED,
                guide_travel.UNKNOWN_FLIGHT,
                guide_travel.TRANSPORT_WAIT,
                guide_travel.TRANSPORT_SPEED,
                guide_travel.TRANSPORT_ACROSS,
                guide_travel.HEARTH_SECONDS,
                guide_travel.UNKNOWN_CROSS,
                guide_travel.TODO_PENALTY,
            ),
            (
                p.walk_speed,
                p.unknown_walk,
                p.flight_overhead,
                p.flight_speed,
                p.unknown_flight,
                p.transport_wait,
                p.transport_speed,
                p.transport_across,
                p.hearth,
                p.unknown_crossing,
                p.crossing_penalty,
            ),
        )

    def test_the_planners_defaults_are_the_shared_prices(self):
        settings = engine.Settings()
        self.assertEqual(settings.detour, pricing.PRICES.detour)
        self.assertEqual(settings.ferry_seconds, pricing.PRICES.ferry)


if __name__ == "__main__":
    unittest.main()
