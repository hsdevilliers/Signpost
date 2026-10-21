"""One price for travel (backlog: the planner and the simulator price travel differently).

Everything that puts a time on getting from one place to another takes its numbers from here: the Route Planner's search
(tools/planner.py), the travel graph that proposes a guide's travel steps (tools/guide_travel.py `plan_travel`) and the walk of a
written route (`guide_travel.simulate`, which tools/guide_sim.py and the Route Planner's report run). Before this module the planner
priced a change of zone by distance while the simulation of the written route priced it at nothing (the step that says `.zone`
leaves the player nowhere in particular, and the walk to the next place was never measured), so a planned route simulated 13 to 24
percent under the planner's estimate. Now both use the numbers below, and `tools/sim_params.json` can override any of them in a
`"travel"` object (`{"travel": {"detour": 1.2}}`), as it does the other simulator numbers.

Every number is an assumption for WoW: Forever (CLAUDE.md, "Forever is not Classic"); none is measured, and `python tools/guide_sim.py
--pace` is the way to calibrate the model against the time played once play data exists. The reasoning is next to each one.
"""

from __future__ import annotations

import json
from dataclasses import dataclass, fields
from pathlib import Path

PARAMS_FILE = Path(__file__).resolve().parent.parent / "sim_params.json"
SECTION = "travel"


@dataclass(frozen=True)
class Prices:
    """Seconds, yards and yards per second. Immutable: a what-if makes another one (`dataclasses.replace`)."""

    # Walking. A character runs at 7 yards a second (Classic's run speed; no mount before level 40 there, and Version 1 stops at 30).
    walk_speed: float = 7.0
    # The path a player takes is longer than the straight line the map data gives (roads wind, hills and water force a way round).
    # 1.0 prices the straight line, which is what both tools always did; no play data says what the real factor is (SignpostCharDB.pace
    # is empty), so it stays 1.0 rather than a guess. A change here moves the planner and the simulation together, which is the point.
    detour: float = 1.0
    # A walk between two places whose positions are not known: a few seconds more than nothing.
    unknown_walk: float = 90.0

    # A flight path: the flight master and the loading screens, then the flight along the straight line (taxi routes wind, so the
    # speed is the average over the route).
    flight_overhead: float = 30.0
    flight_speed: float = 25.0
    unknown_flight: float = 180.0  # a flight whose end is not known

    # A boat or zeppelin: the wait for it (assumed half the time between two departures), then the ride, and for a ride between two
    # world instances (continents), whose distance cannot be measured, an assumed ride of about four minutes. 180 + 240 is the seven
    # minutes the planner's `--ferry` always was ("waiting included"; the walks to and from the docks are extra). VERIFY(beta):
    # time a zeppelin and a boat in play.
    transport_wait: float = 180.0
    transport_speed: float = 20.0  # yards a second when the distance is known
    transport_across: float = 240.0

    # The hearthstone: the cast and the loading screen (its cooldown is a game rule, guide_travel.HEARTH_COOLDOWN).
    hearth: float = 30.0

    # A trip between continents whose route the data does not know (the pack has no zeppelin or boat yet): the walk to the docks of
    # the capital, the boat, and the walk from the capital on the other side. 240 s (about 1700 yards) each way keeps the quarter of
    # an hour (2 x 240 + 420 = 900 s) that the planner always charged when it had no capital to route through. Where the planner does
    # know the capitals it measures the walks, and on the three shipped guides they came to about five minutes a side (the hubs of
    # the quest zones are a long way from the docks), so this is the kind side of it.
    dock_walk: float = 240.0

    # Not play time: what `plan_travel` charges a crossing whose coordinates are not known, so that a known route wins over an
    # unknown one when it chooses how to propose the travel. (The simulation prices such a crossing by distance, like any walk.)
    unknown_crossing: float = 600.0
    crossing_penalty: float = 120.0

    def walk(self, yards: float | None) -> float:
        """Seconds to walk the straight-line distance `yards` (None: the distance is not known)."""
        return self.unknown_walk if yards is None else yards * self.detour / self.walk_speed

    def flight(self, yards: float | None) -> float:
        return self.unknown_flight if yards is None else self.flight_overhead + yards / self.flight_speed

    def transport(self, yards: float | None) -> float:
        """Seconds for a boat or zeppelin: the wait and the ride (an unmeasurable ride is `transport_across`)."""
        return self.transport_wait + (self.transport_across if yards is None else yards / self.transport_speed)

    @property
    def ferry(self) -> float:
        """The boat or zeppelin between continents, waiting included; the walks to and from the docks are extra."""
        return self.transport_wait + self.transport_across

    @property
    def continent(self) -> float:
        """A trip between continents when the route is not known: the walks to and from the docks and the boat."""
        return self.ferry + 2 * self.dock_walk


def load(path: Path | str | None = None) -> Prices:
    """The prices, with the overrides in the `"travel"` object of the parameters file (tools/sim_params.json; none: the defaults).
    A name that is not a price, or a value that is not a usable number, is an error: a typo must not quietly leave the default."""
    file = Path(path) if path is not None else PARAMS_FILE
    try:
        section = json.loads(file.read_text(encoding="utf-8")).get(SECTION) or {}
    except FileNotFoundError:
        return Prices()
    if not isinstance(section, dict):
        raise ValueError(f"{file}: {SECTION} must be an object of prices")
    known = {field.name for field in fields(Prices)}
    values: dict[str, float] = {}
    for name, value in section.items():
        if name.startswith("_"):
            continue  # a note
        if name not in known:
            raise ValueError(f"{file}: {SECTION}.{name} is not a travel price ({', '.join(sorted(known))})")
        if isinstance(value, bool) or not isinstance(value, (int, float)) or value < 0 or (name.endswith("_speed") and value == 0):
            raise ValueError(f"{file}: {SECTION}.{name} must be a number (more than 0 for a speed, else at least 0), not {value!r}")
        values[name] = float(value)
    return Prices(**values)


# The prices every tool uses (read once, when the first tool imports this module).
PRICES = load()
