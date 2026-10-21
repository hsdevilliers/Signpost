"""The route planner's engine: a state graph over a character's progress, searched for the fastest legal route (docs/PLANNER.md).

A node is a situation: where the character is (a hub), its level and experience, the quests done and in the log, the clock.
An edge is an action: *visit a hub* (go there and do everything worthwhile there: turn in, accept, kill and collect) or, when
nothing can be done, *grind to a level*. An edge costs the simulator's time and yields its experience. A route is a path from
level 1 to the cap; the planner looks for the cheapest, with the availability rules (tools/signpost_tools/availability.py) as
the legality of every edge: a quest is accepted only where the game would offer it. Four searches walk the graph (presets):

  greedy     the nearest hub with something to do, a zone finished before the next (what the guides are drafted with)
  lookahead  greedy, but each choice is tried by playing the rest out greedily for a while and the best is kept
  beam       keeps the best few partial routes for each part of a level, comparing only routes that have got equally far
  thorough   the beam at several grains of progress; tools/route_planner.py then polishes and checks the finalists under uncertain assumptions

Every number is the simulator's (tools/guide_sim.py, tools/sim_params.json): this is the best route under those assumptions.
"""

from __future__ import annotations

import re
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable, NamedTuple

sys.path.insert(0, str(Path(__file__).resolve().parent))

import guide_draft  # noqa: E402
import guide_sim  # noqa: E402
import guide_travel  # noqa: E402
from signpost_tools import availability, pricing, steps  # noqa: E402
from signpost_tools.guidefile import Coord  # noqa: E402

GRIND = "grind"
TERRITORY_MIN = 4  # quests for the character's own faction a zone needs before it counts as theirs
# The `.note` a guide step carries for a quest the game completes by a script (the pack's `scripted` flag, no objective listed): by
# what it is (Model.scripted_work) and whether the route is HARDCORE. The time it costs is sim_params.json's escort_seconds / event_seconds.
SCRIPTED_NOTES = {
    ("escort", False): "escort: stay with the NPC and let it finish; the data does not say where it goes or what attacks it",
    ("escort", True): "HARDCORE escort: mobs attack the NPC and you on the way; be healed and buffed, stay close, and leave it if unsure",
    ("event", False): "event: the quest finishes when something happens here (an ambush, a ritual); read the quest log",
    ("event", True): "HARDCORE event: enemies may come at you here; be healed and buffed first, and come back later if unsure",
}


@dataclass(frozen=True)
class Settings:
    cap: int = 30  # the level the route ends at (Version 1: 30)
    hardcore: bool = False  # HARDCORE: no elite or boss, no quest more than `hardcore_over` levels above the character
    hardcore_over: int = 1  # HARDCORE: a quest this many levels above the character is the most it accepts or works on
    accept_over: int = 5  # a normal guide accepts quests up to this many levels above the character...
    work_over: int = 3  # ...and works on their objectives up to this many
    hub_radius: float = 150.0  # yards: quest givers and objective areas this close are one hub
    zone_friction: float = 180.0  # seconds charged against a route for each change of zone (not added to its clock)
    skip_unprofitable: bool = True  # leave out quests slower than grinding (never class quests or what a kept quest needs)
    profit_threshold: float = 1.0  # a quest must give this many times the experience per second of grinding
    detour: float = pricing.PRICES.detour  # walking distance over straight-line distance (the simulation of the written route uses the same)
    local_walk: float = 8.0  # seconds between two NPCs of one hub
    ferry_seconds: float = pricing.PRICES.ferry  # the boat or zeppelin between continents, waiting included (the walks to and from it extra)
    gateways: tuple = (1454, 1458)  # the capitals whose hubs a trip between continents leaves and arrives by (Horde)
    branch: int = 8  # hubs tried from each node
    width: int = 30  # partial routes kept per bucket of progress by the beam
    parts: tuple = (2,)  # buckets of progress to a level, one beam run for each entry (a different grain finds different routes)
    horizon: int = 12  # visits a lookahead plays out
    prune: float = 1.05  # a partial route estimated this much slower than the best finished one is dropped
    alternatives: int = 5  # other finished routes the beam keeps for the thorough preset to compare
    max_depth: int = 900  # visits in a route, a guard against a search that does not end
    class_push: float = 1200.0  # seconds charged for each class quest still undone, for each level past the one it opens at
    class_grace: int = 0  # levels past the one it opens at before the charge starts
    class_levels: int = 6  # levels past that the charge keeps growing for: a quest this late is not worth bending the route for
    group_yards: float = steps.GROUP_YARDS  # neighbouring steps of one kind this near each other are written as one
    unknown_work: float = 300.0  # seconds given to a class quest whose objectives the pack does not have (taming, an escort...)
    instant_quests: bool = False  # keep quests with no objective that are handed in at the NPC that gave them: the pack probably lacks them


@dataclass
class PObjective:
    index: int
    kind: str
    ident: int
    spots: list
    hubs: tuple = ()
    elsewhere: bool = False  # the pack has positions for it, but none where this route goes


@dataclass
class PQuest:
    id: int
    name: str
    level: int
    req: int
    start_places: list
    end_places: list
    objectives: list
    pre_all: tuple = ()
    pre_any: tuple = ()
    excl: tuple = ()
    parents: tuple = ()  # quests whose `next` it is: the game hands it over when one of them is turned in
    parent: int | None = None
    class_mask: int | None = None
    optional: bool = False  # a group (elite) quest in a normal guide
    mandatory: bool = False  # a class quest: routed, or #skipquest-ed with a reason
    kept: bool = True
    start_hubs: tuple = ()
    end_hubs: tuple = ()
    rate: float = 0.0  # experience per second at its nominal level (travel to its objectives included)
    why: str = ""  # why it is not kept
    needed: bool = False  # a kept quest has it as a prerequisite: never left out for being slow
    unknown_xp: bool = False  # the data has no experience for it (a quest new to Forever): never left out for being slow
    end_unknown: bool = False  # a class quest whose ender has no position in the pack: handed in at its start, and the step says so
    unknown_work: bool = False  # a class quest with no objective in the pack, accepted and handed in at one NPC: what it asks is not known
    scripted: str = ""  # "escort" or "event": the game completes it by a script and the pack lists no objective, so one stands for the work


@dataclass
class Hub:
    id: int
    map: int
    zone: int
    x: float
    y: float
    members: list = field(default_factory=list)
    label: str = ""

    @property
    def center(self) -> Coord:
        return Coord(self.map, self.x, self.y)


class Action(NamedTuple):
    kind: str  # accept, turnin, complete, grind
    quest: int | None
    index: int | None  # the objective (complete), or the level reached (grind)
    place: Coord | None


@dataclass
class Visit:
    hub: int | None  # None: a grind
    actions: list
    seconds: float
    xp: float
    zone_change: bool = False
    level: int = 1  # after the visit
    objective_seconds: float = 0.0
    interact_seconds: float = 0.0
    travel_seconds: float = 0.0
    wait_seconds: float = 0.0
    grind_seconds: float = 0.0


class PState:
    """A situation. States are shared along a path through `parent` and never changed once made."""

    __slots__ = ("hub", "zone", "level", "xp", "clock", "penalty", "late", "gated", "done", "active", "gone", "parent", "visit", "depth", "ground")

    def __init__(self) -> None:
        self.hub: int | None = None
        self.zone: int | None = None
        self.level = 1
        self.xp = 0.0
        self.clock = 0.0
        self.penalty = 0.0  # what zone changes cost the planner besides the play time
        self.late = 0.0  # what class quests turned in after the level they open at cost it (Settings.class_push)
        self.gated = 0
        self.done: frozenset = frozenset()
        self.active: dict = {}
        self.gone: frozenset = frozenset()
        self.parent: PState | None = None
        self.visit: Visit | None = None
        self.depth = 0
        self.ground = 0.0

    @property
    def total(self) -> float:
        """The play time and everything the planner charges on top: what the search ranks routes by."""
        return self.clock + self.penalty + self.late

    def key(self) -> tuple:
        return (self.hub, self.done, tuple(sorted((q, tuple(sorted(o))) for q, o in self.active.items())))


@dataclass
class Plan:
    """A finished route: the visits in order, the final state and what the search did to find it."""

    preset: str = ""
    visits: list = field(default_factory=list)
    final: PState | None = None
    seconds: float = 0.0
    penalty: float = 0.0
    late: float = 0.0
    complete: bool = False  # reached the cap with every class quest done or accounted for
    stats: dict = field(default_factory=dict)
    trace: list = field(default_factory=list)  # (level reached, routes kept, best estimated total seconds) for each bucket of progress
    alternatives: list = field(default_factory=list)  # other finished routes with a different order of zones, best first
    decisions: list = field(default_factory=list)  # at each change of zone: what the search chose and what else it held

    @property
    def total(self) -> float:
        """The play time plus everything the planner charged on top (zone changes, class quests done late)."""
        return self.seconds + self.penalty + self.late

    def levels_done(self) -> dict[int, int]:
        """The level the character had after the visit that turned each quest in."""
        found: dict[int, int] = {}
        for v in self.visits:
            for a in v.actions:
                if a.kind == "turnin":
                    found[a.quest] = v.level
        return found


@dataclass
class BeamRun:
    """What one run of the beam found."""

    parts: int  # buckets to a level
    finals: int = 0  # routes it finished
    finished: list = field(default_factory=list)
    pruned: int = 0
    trace: list = field(default_factory=list)  # (level, routes kept, best estimated total seconds) for each bucket worked
    log: dict = field(default_factory=dict)  # bucket -> the best routes held in it: (estimate, zone, level, clock)


class Planner:
    """Everything the searches need about one character: its quests, hubs and the cost of every edge."""

    def __init__(self, pack, world, model, rules, settings: Settings) -> None:
        self.pack, self.world, self.model, self.rules, self.s = pack, world, model, rules, settings
        self.quests: dict[int, PQuest] = {}
        self.dropped: dict[str, list] = {}
        self.hubs: list[Hub] = []
        self.hub_of: dict[tuple, int] = {}
        self.starts_by_place: dict[tuple, list] = {}
        self.ends_by_place: dict[tuple, list] = {}
        self.objs_by_place: dict[tuple, list] = {}
        self.places_at: dict[int, list] = {}
        self.window: list[PQuest] = []  # kept quests by required level
        self.mandatory: set[int] = set()
        self.notes: dict[int, str] = {}
        self.skip_reasons: dict[int, str] = {}
        self.gateways: dict[int, int] = {}  # continent (world instance) -> the hub its boats and zeppelins leave from
        self.rate_curve: dict[int, float] = {}  # experience per second by level, from a greedy walk (the cost-to-go)
        self._travel: dict[tuple, float] = {}
        self._objective: dict[tuple, tuple] = {}
        self._reward: dict[tuple, float] = {}
        self._rates: dict[tuple, bool] = {}
        self._order: dict[tuple, list] = {}
        self.nodes_made = 0
        self.skip_zones: dict[int, str] = {}  # map -> why no quest of it is routed (a battleground)
        self._giver_index: dict[int, list] = {}  # start NPC -> (quest, name, class mask) of every quest of the pack
        self._required: set[int] = set()  # quests that another quest needs first
        self.home: Coord | None = None  # where the character begins
        self.core: set[int] = set()  # the class quests and the quests they need: all that is done once the cap is reached
        self.forbidden: set[int] = set()  # quests a tidied route no longer accepts (it never turned them in)
        self.accept_over = settings.hardcore_over if settings.hardcore else settings.accept_over
        self.work_over = settings.hardcore_over if settings.hardcore else settings.work_over

    # build -----------------------------------------------------------------------------------------------------------

    @classmethod
    def build(
        cls,
        pack,
        world,
        character: availability.Character,
        settings: Settings,
        params: dict | None = None,
        *,
        exclude: dict | None = None,
        notes: dict | None = None,
        mandatory: tuple = (),
        chains: tuple = (),
        home: Coord | None = None,
        skip_zones: dict | None = None,
        log: Callable[[str], None] | None = None,
    ) -> "Planner":
        say = log or (lambda text: None)
        model = guide_sim.make_model(pack, params)
        quests = pack.table("quests")
        planner = cls(pack, world, model, availability.Rules(quests, character), settings)
        planner.notes = dict(notes or {})
        planner.skip_reasons = dict(exclude or {})
        planner.mandatory = set(mandatory)
        planner.home = home
        planner.skip_zones = dict(skip_zones or {})
        planner._giver_index = planner._index_givers(quests)
        planner._required = {
            p for record in quests.values() if isinstance(record, dict)
            for p in guide_draft._ids(record.get("preGroup")) + guide_draft._ids(record.get("preSingle"))
        }
        started = time.perf_counter()
        for qid, record in sorted(quests.items()):
            if isinstance(record, dict):
                planner._consider(qid, record)
        for chain in chains:  # quests of a chain the data does not link: each waits for the one before it
            for earlier, later in zip(chain, chain[1:]):
                if earlier in planner.quests and later in planner.quests and earlier not in planner.quests[later].pre_all:
                    planner.quests[later].pre_all += (earlier,)
        say(f"{len(planner.quests)} of {len(quests)} quests can be routed for this character")
        planner._prune_territory(character.faction)
        planner._prune_unreachable()
        planner._make_hubs()
        say(f"{len(planner.hubs)} hubs of about {settings.hub_radius:.0f} yards")
        planner._profit()
        planner._index()
        kept = sum(1 for q in planner.quests.values() if q.kept)
        say(f"{kept} quests kept, {len(planner.quests) - kept} left out as not worth their time; built in {time.perf_counter() - started:.1f} s")
        return planner

    def _drop(self, reason: str, qid: int) -> None:
        self.dropped.setdefault(reason, []).append(qid)

    def _index_givers(self, quests: dict) -> dict[int, list]:
        found: dict[int, list] = {}
        for qid, record in quests.items():
            if isinstance(record, dict):
                mask = self.rules.class_mask(record)
                for npc in guide_draft._ids((record.get("s") or {}).get("npc")):
                    found.setdefault(npc, []).append((qid, str(record.get("n") or ""), mask))
        return found

    def _inferred_class(self, qid: int, record: dict) -> int | None:
        """The class a quest with no class mask probably belongs to: the mask of a quest of the same name from the same giver (the
        Forever copy of a class quest), else the one class all of that giver's other quests are limited to (a class trainer's NPC)."""
        name = str(record.get("n") or "")
        for npc in guide_draft._ids((record.get("s") or {}).get("npc")):
            others = [(n, m) for q, n, m in self._giver_index.get(npc, ()) if q != qid]
            same = [m for n, m in others if m and n == name]
            if same:
                return same[0]
            masks = [m for n, m in others]
            if len(masks) >= 3 and all(masks) and len(set(masks)) == 1:
                return masks[0]
        return None

    def _consider(self, qid: int, record: dict) -> None:
        s, world, pack = self.s, self.world, self.pack
        block = self.rules.mask_block(qid)
        if block:
            return self._drop(f"other {block.code}", qid)
        if record.get("repeatable"):
            return self._drop("repeatable", qid)
        if record.get("sort") in availability.EVENT_SORTS:
            return self._drop("seasonal or event", qid)
        if record.get("skill"):
            return self._drop("needs a profession skill", qid)
        if (record.get("r") or 0) > s.cap:
            return self._drop("above the level cap", qid)
        if self.rules.never(qid):
            return self._drop("a prerequisite is closed to this character", qid)
        if qid in self.skip_reasons:
            return self._drop("excluded", qid)
        if record.get("zone") in self.skip_zones:
            return self._drop(self.skip_zones[record["zone"]], qid)
        mine = self.rules.me.class_bit
        if self.rules.class_mask(record) is None and mine:
            inferred = self._inferred_class(qid, record)
            if inferred and not inferred & mine:
                return self._drop("probably another class's quest (the quests of its giver are)", qid)
        starts = _unique(world.quest_coords(qid, "s"))
        if not starts:
            return self._drop("no start position in the data", qid)
        ends = _unique(world.quest_coords(qid, "e"))
        end_unknown = not ends
        if end_unknown:
            if qid not in self.mandatory:
                return self._drop("no turn-in position in the data", qid)
            ends = list(starts)  # a class quest is routed all the same, and its step says that the turn-in has no position
        objectives: list[PObjective] = []
        elite = False
        for number, objective in enumerate(record.get("o") or [], 1):
            if not isinstance(objective, dict):
                continue
            kind = str(objective.get("k"))
            if isinstance(objective.get("id"), int):
                spots = guide_draft._objective_spots(pack, world, None, kind, objective["id"])
                objectives.append(PObjective(number, kind, objective["id"], spots))
                elite = elite or guide_draft._elite_objective(pack, kind, objective["id"])
            elif kind == "explore":  # an area to reach: positions of its own, no creature or object
                objectives.append(PObjective(number, kind, 0, _unique(guide_travel.coords_of(objective.get("p")))))
        one_npc = bool(
            set(guide_draft._ids((record.get("s") or {}).get("npc"))) & set(guide_draft._ids((record.get("e") or {}).get("npc")))
        )
        # an escort or an event (the pack's `scripted` flag) is not free experience whatever its NPCs: it costs the time sim_params.json
        # gives it, written as a `.complete` with a note; a class quest keeps unknown_work's 5 minutes and `.todo` instead
        scripted = "" if qid in self.mandatory else (self.model.scripted_work(qid) or "")
        unknown_work = not objectives and one_npc and not scripted
        if unknown_work and not s.instant_quests and qid not in self.mandatory and qid not in self._required and not record.get("next"):
            return self._drop("no objective in the data (accepted and handed in at one NPC)", qid)
        if scripted:  # the one objective that stands for the work: done where the quest starts, which is where the escort sets off
            objectives.append(PObjective(1, "scripted", 0, list(starts)))
        if s.hardcore and elite:
            return self._drop("HARDCORE: needs an elite or boss kill", qid)
        if (record.get("l") or 0) > s.cap + 5:
            return self._drop("far above the level cap", qid)
        classes = record.get("classes")
        if not isinstance(classes, int) and record.get("sort") in availability.CLASS_SORTS:
            classes = availability.CLASS_BITS[availability.CLASS_SORTS[record["sort"]]]
        self.quests[qid] = PQuest(
            qid,
            str(record.get("n") or f"quest {qid}"),
            record.get("l") or record.get("r") or 1,
            max(1, record.get("r") or 1),
            starts,
            ends,
            objectives,
            pre_all=tuple(guide_draft._ids(record.get("preGroup"))),
            pre_any=tuple(guide_draft._ids(record.get("preSingle"))),
            excl=tuple(guide_draft._ids(record.get("exclusive"))),
            parent=record.get("parent") if isinstance(record.get("parent"), int) else None,
            class_mask=classes if isinstance(classes, int) else None,
            optional=elite and not s.hardcore,
            mandatory=qid in self.mandatory,
            end_unknown=end_unknown,
            unknown_work=unknown_work and qid in self.mandatory,
            scripted=scripted,
        )

    def _prune_territory(self, faction: str) -> None:
        """Zones where the character's faction has hardly any quest givers are the other side's: a Horde character does not
        quest in Loch Modan because a neutral NPC there offers something."""
        own: dict[int, int] = {}
        records = self.pack.table("quests")
        zone_of = self.world.geo.zone
        for q in self.quests.values():
            if (records.get(q.id) or {}).get("side") == faction:
                zone = zone_of(q.start_places[0].map)
                own[zone] = own.get(zone, 0) + 1
        friendly = {zone for zone, count in own.items() if count >= TERRITORY_MIN}
        for qid in [qid for qid, q in self.quests.items() if zone_of(q.start_places[0].map) not in friendly and not q.mandatory]:
            del self.quests[qid]
            self._drop("the other side's territory", qid)
        # a continent or island with no boat or zeppelin from a capital (another race's start island) cannot be reached,
        # unless it is where the character begins
        geo = self.world.geo
        reachable = {geo.instance(m) for m in self.s.gateways} - {None}
        if self.home is not None and geo.instance(self.home.map) is not None:
            reachable.add(geo.instance(self.home.map))
        if reachable:
            for qid in [qid for qid, q in self.quests.items() if geo.instance(q.start_places[0].map) not in reachable and not q.mandatory]:
                del self.quests[qid]
                self._drop("on an island with no boat or zeppelin", qid)
        # an objective is worked where the character can go: friendly zones, on the continent the quest starts on
        for q in self.quests.values():
            home = geo.instance(q.start_places[0].map)
            for o in q.objectives:
                spots = [c for c in o.spots if zone_of(c.map) in friendly]
                near = [c for c in spots if geo.instance(c.map) == home]
                o.elsewhere = bool(o.spots) and not (near or spots)
                o.spots = near or spots
        # a quest whose objective exists only where the route does not go cannot be done by it (a class quest stays, with a .todo)
        for qid in [qid for qid, q in self.quests.items() if not q.mandatory and any(o.elsewhere for o in q.objectives)]:
            del self.quests[qid]
            self._drop("an objective only where the route does not go", qid)

    def _prune_unreachable(self) -> None:
        """A quest whose prerequisites the planner cannot route (data missing, a HARDCORE exclusion) is out with them."""
        reachable: set[int] = set()
        changed = True
        while changed:
            changed = False
            for q in self.quests.values():
                if q.id in reachable:
                    continue
                if all(p in reachable for p in q.pre_all) and (not q.pre_any or any(p in reachable for p in q.pre_any)):
                    if q.parent is None or q.parent in self.quests:
                        reachable.add(q.id)
                        changed = True
        for qid in [qid for qid in self.quests if qid not in reachable]:
            del self.quests[qid]
            self._drop("a prerequisite cannot be routed", qid)
        for q in self.quests.values():
            q.pre_any = tuple(p for p in q.pre_any if p in self.quests)
            q.excl = tuple(x for x in q.excl if x in self.quests)
        records = self.pack.table("quests")
        for q in self.quests.values():
            nxt = (records.get(q.id) or {}).get("next")
            if isinstance(nxt, int) and nxt in self.quests:
                self.quests[nxt].parents += (q.id,)

    def _make_hubs(self) -> None:
        """Quest givers, enders and objective areas, grouped per map into hubs of the configured radius."""
        by_map: dict[int, list] = {}
        seen: set = set()
        for q in self.quests.values():
            for c in list(q.start_places) + list(q.end_places) + [c for o in q.objectives for c in o.spots]:
                if (c.map, c.x, c.y) not in seen:
                    seen.add((c.map, c.x, c.y))
                    by_map.setdefault(c.map, []).append(c)
        zone_of = self.world.geo.zone
        for map_id, coords in sorted(by_map.items()):
            hubs: list[Hub] = []
            for c in sorted(coords, key=lambda c: (c.x, c.y)):
                home = next((h for h in hubs if self._yards(h.center, c) <= self.s.hub_radius), None)
                if home is None:
                    home = Hub(len(self.hubs) + len(hubs), map_id, zone_of(map_id), c.x, c.y)
                    hubs.append(home)
                home.members.append(c)
                self.hub_of[(c.map, c.x, c.y)] = home.id
            for h in hubs:
                h.x = sum(m.x for m in h.members) / len(h.members)
                h.y = sum(m.y for m in h.members) / len(h.members)
            self.hubs.extend(hubs)
        for map_id in self.s.gateways:
            instance = self.world.geo.instance(map_id)
            found = [h for h in self.hubs if h.map == map_id]
            if instance is not None and found:
                self.gateways[instance] = max(found, key=lambda h: len(h.members)).id
        for q in self.quests.values():
            q.start_hubs = tuple(sorted({self.hub_of[(c.map, c.x, c.y)] for c in q.start_places}))
            q.end_hubs = tuple(sorted({self.hub_of[(c.map, c.x, c.y)] for c in q.end_places}))
            for o in q.objectives:
                o.hubs = tuple(sorted({self.hub_of[(c.map, c.x, c.y)] for c in o.spots})) or q.start_hubs
        npcs, records = self.pack.table("npcs"), self.pack.table("quests")
        names: dict[int, dict] = {}
        for q in self.quests.values():
            record = records.get(q.id) or {}
            for part in ("s", "e"):
                for npc in guide_draft._ids((record.get(part) or {}).get("npc")):
                    entry = npcs.get(npc) or {}
                    for c in guide_travel.coords_of(entry.get("p")):
                        hub = self.hub_of.get((c.map, c.x, c.y))
                        if hub is not None and entry.get("n"):
                            counts = names.setdefault(hub, {})
                            counts[entry["n"]] = counts.get(entry["n"], 0) + 1
        for hub in self.hubs:
            counts = names.get(hub.id) or {}
            top = max(counts, key=counts.get) if counts else f"{hub.x:.0f},{hub.y:.0f}"
            hub.label = f"{self.world.geo.name(hub.zone)}: {top}"

    def _profit(self) -> None:
        """Which quests are worth their time: experience per second, travel to the objectives included, against what grinding
        gives at the level the quest is done at. A class quest and what a kept quest needs are kept whatever they give."""
        s, model = self.s, self.model
        keep: set[int] = set()
        for q in self.quests.values():
            nominal = min(s.cap, max(q.req, q.level - 1, 1))
            q.rate = self._quest_rate(q, nominal)
            q.unknown_xp = q.id not in model.quest_xp
            if not s.skip_unprofitable or q.mandatory or q.unknown_xp or q.rate >= s.profit_threshold * model.grind_xp_per_second(nominal):
                keep.add(q.id)
        stack = list(keep)
        while stack:
            q = self.quests[stack.pop()]
            needed = list(q.pre_all)
            if q.pre_any and not any(p in keep for p in q.pre_any):
                needed.append(max(q.pre_any, key=lambda p: self.quests[p].rate))
            for p in needed:
                if p not in keep:
                    keep.add(p)
                    stack.append(p)
        # what the class quests need: past the cap nothing else is worth the time
        core = {q.id for q in self.quests.values() if q.mandatory}
        stack = list(core)
        while stack:
            q = self.quests[stack.pop()]
            needed = list(q.pre_all)
            if q.pre_any and not any(p in core for p in q.pre_any):
                needed.append(max(q.pre_any, key=lambda p: self.quests[p].rate))
            for p in needed:
                if p not in core:
                    core.add(p)
                    stack.append(p)
        self.core = core
        for q in self.quests.values():
            q.kept = q.id in keep
            if not q.kept:
                q.why = "slower than grinding"
                self._drop("slower than grinding", q.id)
        for q in self.quests.values():
            if q.kept:
                for p in list(q.pre_all) + list(q.pre_any):
                    if p in self.quests:
                        self.quests[p].needed = True

    def _quest_rate(self, q: PQuest, level: int) -> float:
        model = self.model
        seconds = 2 * model.p["interact_seconds"]
        xp = model.reward_xp(q.id, level)
        for o in q.objectives:
            s, _wait, x = self.objective(q.id, o.index, level)
            seconds += s
            xp += x
        walk = self._yards(q.start_places[0], q.end_places[0])
        for o in q.objectives:
            if o.spots:
                walk += 2 * min(self._yards(q.start_places[0], c) for c in o.spots)
        seconds += walk / pricing.PRICES.walk_speed * self.s.detour
        return xp / max(seconds, 1.0)

    def _index(self) -> None:
        self.window = sorted((q for q in self.quests.values() if q.kept), key=lambda q: (q.req, q.id))
        places: dict[int, dict] = {}

        def note(c: Coord) -> tuple:
            key = (c.map, c.x, c.y)
            places.setdefault(self.hub_of[key], {})[key] = c
            return key

        for q in self.window:
            for c in q.start_places:
                self.starts_by_place.setdefault(note(c), []).append(q)
            for c in q.end_places:
                self.ends_by_place.setdefault(note(c), []).append(q)
            for o in q.objectives:
                for c in o.spots or q.start_places:  # no position in the data: worked where it starts, and the guide says so
                    self.objs_by_place.setdefault(note(c), []).append((q, o))
        self.places_at = {hub: list(found.values()) for hub, found in places.items()}

    # distances and the model's numbers -------------------------------------------------------------------------------

    def _yards(self, a: Coord, b: Coord) -> float:
        d = self.world.geo.distance(a, b)
        if d is not None:
            return d
        return ((a.x - b.x) ** 2 + (a.y - b.y) ** 2) ** 0.5 * 10 if a.map == b.map else 6000.0

    def _walk(self, a: int, b: int) -> float | None:
        d = self.world.geo.distance(self.hubs[a].center, self.hubs[b].center)
        return None if d is None else d * self.s.detour / pricing.PRICES.walk_speed

    def travel(self, a: int | None, b: int) -> float:
        """Seconds from hub a to hub b: walking on one continent; between continents the walk to the capital's boat or
        zeppelin, the ride (waiting included) and the walk from the other capital (pricing.PRICES.continent, 15 minutes, if a gateway is
        unknown). The prices are signpost_tools/pricing.py's, which the simulation of the written route uses too."""
        if a is None or a == b:
            return 0.0
        key = (a, b)
        if key not in self._travel:
            seconds = self._walk(a, b)
            if seconds is None:
                geo = self.world.geo
                ga, gb = self.gateways.get(geo.instance(self.hubs[a].map)), self.gateways.get(geo.instance(self.hubs[b].map))
                legs = (self._walk(a, ga), self._walk(gb, b)) if ga is not None and gb is not None else (None, None)
                seconds = legs[0] + self.s.ferry_seconds + legs[1] if None not in legs else pricing.PRICES.continent
            self._travel[key] = self._travel[(b, a)] = seconds
        return self._travel[key]

    def objective(self, quest: int, index: int, level: int) -> tuple:
        key = (quest, index, level)
        if key not in self._objective:
            self._objective[key] = self.model.objective(quest, index, level)
        return self._objective[key]

    def reward(self, quest: int, level: int) -> float:
        key = (quest, level)
        if key not in self._reward:
            self._reward[key] = self.model.reward_xp(quest, level)
        return self._reward[key]

    def order(self, hub: int, came_from: int | None) -> list:
        """The places of a hub in the order a visit walks them: nearest first, from the one closest to where it came from."""
        key = (hub, came_from)
        if key not in self._order:
            left = list(self.places_at.get(hub, ()))
            here = self.hubs[came_from].center if came_from is not None else self.hubs[hub].center
            walk = []
            while left:
                nearest = min(left, key=lambda c: self._yards(here, c))
                left.remove(nearest)
                walk.append(nearest)
                here = nearest
            self._order[key] = walk
        return self._order[key]

    # the rules ------------------------------------------------------------------------------------------------------

    def worth_now(self, q: PQuest, level: int) -> bool:
        """Whether a quest still pays at this level: experience per second against grinding here. A quest that has outgrown
        the character (its mobs grey, its reward cut) is left out; a class quest, one a kept quest needs, and one the data has
        no experience for are never."""
        if not self.s.skip_unprofitable or q.mandatory or q.needed or q.unknown_xp:
            return True
        key = (q.id, level)
        if key not in self._rates:
            self._rates[key] = self._quest_rate(q, level) >= self.s.profit_threshold * self.model.grind_xp_per_second(level)
        return self._rates[key]

    def ready(self, q: PQuest, done, active, gone, level: int = 0) -> bool:
        """Every condition but the level: prerequisites, quests that close it, its parent, the quest that hands it over."""
        for p in q.pre_all:
            if p not in done:
                return False
        if q.pre_any and not any(p in done for p in q.pre_any):
            return False
        for x in q.excl:
            if x in done or x in active:
                return False
        if q.parent is not None and q.parent not in active:
            return False
        for p in q.parents:
            if p in active:
                return False  # the game offers it when that quest is turned in, not before
            if p in self.forbidden:
                continue
            parent = self.quests[p]
            if p not in done and p not in gone and parent.kept and not any(x in done for x in parent.excl) and (not level or self.worth_now(parent, level)):
                return False  # in this route it follows that quest
        return True

    def offered(self, q: PQuest, level: int, done, active, gone) -> bool:
        if level < q.req or q.level > level + self.accept_over or q.id in self.forbidden:
            return False
        if level >= self.s.cap and q.id not in self.core:
            return False  # at the cap only the class quests (and what they need) are still worth the walk
        return self.ready(q, done, active, gone, level) and self.worth_now(q, level)

    def soon(self, q: PQuest, level: int) -> bool:
        """An objective waits while its quest is well above the character."""
        return q.level <= level + self.work_over

    # edges ----------------------------------------------------------------------------------------------------------

    def start(self, start_hub: int, level: int = 1) -> PState:
        st = PState()
        st.hub, st.zone, st.level = start_hub, self.hubs[start_hub].zone, level
        return st

    def options(self, st: PState) -> dict[int, float]:
        """The hubs with something to do now, with a rough worth for ranking: the experience at stake there."""
        level, done, active, gone = st.level, st.done, st.active, st.gone
        worth: dict[int, float] = {}
        capped = level >= self.s.cap
        for qid, open_ in active.items():
            q = self.quests[qid]
            if capped and qid not in self.core:
                continue
            if not open_:
                for h in q.end_hubs:
                    worth[h] = worth.get(h, 0.0) + self.reward(qid, level)
            elif self.soon(q, level):
                for o in q.objectives:
                    if o.index in open_:
                        x = self.objective(qid, o.index, level)[2]
                        for h in o.hubs:
                            worth[h] = worth.get(h, 0.0) + x
        for q in self.window:
            if q.req > level:
                break
            if q.id in done or q.id in active or q.id in gone:
                continue
            if self.offered(q, level, done, active, gone):
                x = self.reward(q.id, level) / 2
                for h in q.start_hubs:
                    worth[h] = worth.get(h, 0.0) + x
        return worth

    def visit(self, st: PState, hub: int) -> PState | None:
        """Go to a hub and do everything worthwhile there until nothing new turns up; None when there is nothing to do."""
        s, p = self.s, self.model.p
        progress = guide_sim.Progress(self.model, st.level, st.xp)
        done, gone = set(st.done), set(st.gone)
        active = {q: set(o) for q, o in st.active.items()}
        gated = st.gated
        actions: list[Action] = []
        interact_s = p["interact_seconds"]
        interact = objective = longest_wait = gained = owed = 0.0
        sweeps = 0
        progressed = True
        while progressed and sweeps < 8:
            progressed, sweeps = False, sweeps + 1
            for place in self.order(hub, st.hub):
                key = (place.map, place.x, place.y)
                changed = True
                while changed:
                    changed = False
                    for q in self.ends_by_place.get(key, ()):
                        if q.id in active and not active[q.id]:
                            gained += progress.gain(self.reward(q.id, progress.level))
                            owed += self.lateness(q, progress.level)
                            interact += interact_s
                            actions.append(Action("turnin", q.id, None, place))
                            del active[q.id]
                            done.add(q.id)
                            gone.update(q.excl)
                            changed = True
                    for q in self.starts_by_place.get(key, ()):
                        if q.id in done or q.id in active or q.id in gone:
                            continue
                        if not self.offered(q, progress.level, done, active, gone):
                            continue
                        gated = max(gated, q.req) if q.req > 1 else gated
                        if q.unknown_work:
                            objective += s.unknown_work
                        interact += interact_s
                        actions.append(Action("accept", q.id, None, place))
                        active[q.id] = {o.index for o in q.objectives}
                        gone.update(x for x in q.excl if x not in done)
                        changed = True
                    for q, o in self.objs_by_place.get(key, ()):
                        if progress.level >= s.cap and q.id not in self.core:
                            continue
                        if q.id in active and o.index in active[q.id] and self.soon(q, progress.level):
                            seconds, wait, xp = self.objective(q.id, o.index, progress.level)
                            objective += seconds - wait
                            longest_wait = max(longest_wait, wait)
                            gained += progress.gain(xp)
                            actions.append(Action("complete", q.id, o.index, place))
                            active[q.id].discard(o.index)
                            changed = True
                    progressed = progressed or changed
        if not actions:
            return None
        switches = sum(1 for a, b in zip(actions, actions[1:]) if a.place != b.place)
        walk = self.travel(st.hub, hub) + switches * s.local_walk
        seconds = walk + interact + objective + longest_wait
        new = PState()
        new.hub, new.zone = hub, self.hubs[hub].zone
        new.level, new.xp = progress.level, progress.xp
        zone_change = new.zone != st.zone
        new.clock = st.clock + seconds
        new.penalty = st.penalty + (s.zone_friction if zone_change else 0.0)
        new.late = st.late + owed
        new.gated, new.done, new.gone = gated, frozenset(done), frozenset(gone)
        new.active = {q: frozenset(o) for q, o in active.items()}
        new.parent, new.depth, new.ground = st, st.depth + 1, st.ground
        new.visit = Visit(hub, actions, seconds, gained, zone_change, progress.level, objective, interact, walk, longest_wait)
        self.nodes_made += 1
        return new

    def grind(self, st: PState, voluntary: bool = False) -> PState | None:
        """Kill for the experience until a waiting quest (or objective) opens, or the cap. Forced when nothing can be done;
        voluntary (one level) when what can be done pays less than killing would."""
        level, done, active, gone = st.level, st.done, st.active, st.gone
        if voluntary:
            return self._grind_to(st, min(level + 1, self.s.cap))
        wanted: list[int] = []
        for q in self.window:
            if q.id in done or q.id in active or q.id in gone or not self.ready(q, done, active, gone, level):
                continue
            if not self.worth_now(q, level) and q.level + 8 < level:
                continue  # it has outgrown the character: waiting for a level would not make it pay
            wanted.append(max(q.req, q.level - self.accept_over))
        for qid, open_ in active.items():
            q = self.quests[qid]
            if open_ and not self.soon(q, level):
                wanted.append(q.level - self.work_over)
        wanted = [n for n in wanted if n > level]
        target = min(wanted) if wanted else (self.s.cap if level < self.s.cap else None)
        if target is None:
            return None
        return self._grind_to(st, min(target, self.s.cap))

    def _grind_to(self, st: PState, target: int) -> PState | None:
        level = st.level
        progress = guide_sim.Progress(self.model, level, st.xp)
        seconds = progress.grind_to(target)
        if seconds <= 0:
            return None
        new = PState()
        new.hub, new.zone, new.level, new.xp = st.hub, st.zone, progress.level, progress.xp
        new.clock, new.penalty, new.late = st.clock + seconds, st.penalty, st.late
        new.gated, new.done, new.gone, new.active = max(st.gated, target), st.done, st.gone, st.active
        new.parent, new.depth, new.ground = st, st.depth + 1, st.ground + progress.ground_xp
        new.visit = Visit(None, [Action(GRIND, None, target, None)], seconds, progress.ground_xp, False, progress.level, grind_seconds=seconds)
        self.nodes_made += 1
        return new

    # the goal and the estimate ---------------------------------------------------------------------------------------

    def lateness(self, q: PQuest, level: int) -> float:
        """What a class quest costs the route for being undone at this level: a push to do it early, not a deadline. The route
        picks it up when it passes the giver, and makes the trip for a far one soon after it opens."""
        if not q.mandatory:
            return 0.0
        return min(max(0, level - q.req - self.s.class_grace), self.s.class_levels) * self.s.class_push

    def pending_mandatory(self, st: PState) -> list[int]:
        """Class quests still to do that the route can do: not done, not closed by a quest it did."""
        return [
            qid
            for qid in self.mandatory
            if qid in self.quests
            and qid not in st.done
            and qid not in st.gone
            and not any(x in st.done for x in self.quests[qid].excl)
        ]

    def terminal(self, st: PState) -> bool:
        return st.level >= self.s.cap and not self.pending_mandatory(st)

    def to_go(self, st: PState) -> float:
        """The estimated seconds still to go: the experience left at the pace a greedy walk made at each level, and the
        class quests not done."""
        model, left = self.model, 0.0
        for n in range(st.level, self.s.cap):
            need = model.to_next(n) - (st.xp if n == st.level else 0.0)
            left += max(0.0, need) / self.rate_curve.get(n, model.grind_xp_per_second(n))
        for qid in self.pending_mandatory(st):
            q = self.quests[qid]
            level = max(st.level, q.req)
            left += 2 * model.p["interact_seconds"] + sum(self.objective(qid, o.index, level)[0] for o in q.objectives)
        return left

    def _pace(self, level: int) -> float:
        """Levels gained per second at a level, by the pace of the greedy walk (the cost-to-go's)."""
        if level >= self.s.cap:
            return 0.0
        rate = self.rate_curve.get(level) or self.model.grind_xp_per_second(level)
        return rate / max(1.0, self.model.to_next(level))

    def _next_hubs(self, q: PQuest, st: PState) -> tuple:
        """Where a class quest is next worked on: its giver, the open objectives, its ender."""
        open_ = st.active.get(q.id)
        if open_ is None:
            return q.start_hubs
        if open_:
            return tuple(h for o in q.objectives if o.index in open_ for h in o.hubs)
        return q.end_hubs

    def pending_charge(self, st: PState) -> float:
        """What the class quests still undone are expected to cost the route: each at the level the character will have when it
        gets there (the level it opens at, if that is above the character's, and the levels gained on the way to where it is next
        worked on). A quest that opens later costs the same at every level before it opens, so levelling is never what a route is
        charged for, and one that is far away costs for the levels the trip takes."""
        s, pace, total = self.s, self._pace(st.level), 0.0
        for qid in self.pending_mandatory(st):
            q = self.quests[qid]
            hubs = self._next_hubs(q, st)
            trip = 0.0 if st.hub in hubs else min((self.travel(st.hub, h) for h in hubs), default=0.0)
            late = st.level + trip * pace - q.req - s.class_grace
            total += min(max(0.0, late), s.class_levels) * s.class_push
        return total

    def score(self, st: PState) -> float:
        """What the searches rank partial routes by: the time so far, what class quests undone are costing, the time to go."""
        return st.total + self.pending_charge(st) + self.to_go(st)

    def hopeless(self, st: PState, best_time: float) -> bool:
        """A partial route that cannot beat the best finished one (by more than the `prune` margin) even if the class quests still
        undone were free. The charge for them is left out on purpose: it is a ranking, not a cost (a route that lets them wait has
        not paid it yet), and set against a finished route's real charges it made every partial route look worse than the greedy one,
        so the beam finished nothing."""
        return st.total + self.to_go(st) >= best_time * self.s.prune

    # the searches ---------------------------------------------------------------------------------------------------

    def rank(self, st: PState, worth: dict[int, float], limit: int) -> list[int]:
        """The hubs worth trying from a state: the most experience for the walk, and the nearest few."""
        best = sorted(worth, key=lambda h: -worth[h] / (self.travel(st.hub, h) + 30.0))
        nearest = sorted(worth, key=lambda h: self.travel(st.hub, h))[:3]
        chosen: list[int] = []
        for h in nearest + best:
            if h not in chosen:
                chosen.append(h)
            if len(chosen) >= limit:
                break
        return chosen

    def overdue_hubs(self, st: PState, most: int = 4) -> list[int]:
        """The nearest hubs where a class quest past the level it opens at can be got on with (its giver, an open objective, its
        ender), so the search always considers the trip: a far hub never makes the best-ranked few on experience for the walk."""
        found: dict[int, float] = {}
        for qid in self.pending_mandatory(st):
            q = self.quests[qid]
            if st.level <= q.req + self.s.class_grace:
                continue
            if qid in st.active:
                open_ = st.active[qid]
                if not open_:
                    hubs = q.end_hubs
                elif self.soon(q, st.level):
                    hubs = tuple(h for o in q.objectives if o.index in open_ for h in o.hubs)
                else:
                    continue
            elif self.offered(q, st.level, st.done, st.active, st.gone):
                hubs = q.start_hubs
            else:
                continue
            for h in hubs:
                if h != st.hub:
                    found[h] = min(found.get(h, float("inf")), self.travel(st.hub, h))
        return sorted(found, key=found.get)[:most]

    def children(self, st: PState, limit: int) -> list[PState]:
        out = []
        hubs = self.rank(st, self.options(st), limit)
        hubs += [h for h in self.overdue_hubs(st) if h not in hubs]
        for h in hubs:
            child = self.visit(st, h)
            if child is not None:
                out.append(child)
        g = self.grind(st) if not out else (self.grind(st, voluntary=True) if st.level < self.s.cap else None)
        if g is not None:
            out.append(g)
        return out

    def greedy_step(self, st: PState) -> PState | None:
        """The nearest hub with something to do, a zone finished before the next (the drafter's rule)."""
        worth = self.options(st)
        if not worth:
            return self.grind(st)

        def cost(h: int) -> tuple:
            return (self.travel(st.hub, h) + (self.s.zone_friction * 4 if self.hubs[h].zone != st.zone else 0.0), -worth[h])

        for h in sorted(worth, key=cost):
            child = self.visit(st, h)
            if child is not None:
                return child
        return self.grind(st)

    def rollout(self, st: PState, steps: int | None = None) -> PState:
        n = 0
        while not self.terminal(st) and st.depth < self.s.max_depth and (steps is None or n < steps):
            nxt = self.greedy_step(st)
            if nxt is None:
                break
            st, n = nxt, n + 1
        return st

    def plan(self, preset: str, start_hub: int, progress: Callable[[str], None] | None = None) -> Plan:
        started = time.perf_counter()
        nodes0 = self.nodes_made
        if preset == "greedy":
            plan = self._finish(self.rollout(self.start(start_hub)))
        elif preset == "lookahead":
            plan = self._lookahead(start_hub, progress)
        elif preset in ("beam", "thorough"):
            plan = self._beam(start_hub, progress)
        else:
            raise ValueError(f"unknown preset {preset!r}")
        plan = self.tidy(plan, start_hub)
        plan.preset = preset
        plan.stats.update(seconds=time.perf_counter() - started, nodes=self.nodes_made - nodes0)
        return plan

    def tidy(self, plan: Plan, start_hub: int) -> Plan:
        """A guide must not accept a quest it never turns in: the quests a search left in the log at the end (it reached the
        cap first) are taken out of the route, and the same hubs are walked again without them (more than once if that
        leaves others unfinished); a level that falls short is ground at the end."""
        stats, trace, preset = dict(plan.stats), plan.trace, plan.preset
        alternatives, decisions = plan.alternatives, plan.decisions
        removed: set[int] = set()
        for _ in range(4):
            unfinished = set(plan.final.active) - removed if plan.final else set()
            if not unfinished:
                break
            removed |= unfinished
            self.forbidden = set(removed)
            st = self.start(start_hub)
            for v in plan.visits:
                if v.hub is None:  # a level ground to open quests that waited for it: ground again, to the same level
                    target = v.actions[0].index
                    child = self._grind_to(st, target) if target > st.level else None
                else:
                    child = self.visit(st, v.hub)
                if child is not None:
                    st = child
            plan = self._finish(self.rollout(st))
        self.forbidden = set()
        plan.stats, plan.trace, plan.preset = stats, trace, preset
        plan.alternatives, plan.decisions = alternatives, decisions
        plan.stats["removed"] = sorted(removed | set(stats.get("removed", ())))  # a plan tidied twice still says what was taken out
        return plan

    def _finish(self, final: PState) -> Plan:
        plan = Plan(final=final, seconds=final.clock, penalty=final.penalty, late=final.late)
        path, st = [], final
        while st is not None and st.visit is not None:
            path.append(st.visit)
            st = st.parent
        plan.visits = list(reversed(path))
        plan.complete = self.terminal(final)
        return plan

    def calibrate(self, plan: Plan) -> None:
        """The pace of a walk at each level: the cost-to-go the other searches score with."""
        reached: dict[int, float] = {}
        clock, level = 0.0, 1
        for v in plan.visits:
            clock += v.seconds
            while level < v.level:
                level += 1
                reached[level] = clock
        previous = 0.0
        for n in range(1, self.s.cap):
            if n + 1 in reached and reached[n + 1] > previous:
                self.rate_curve[n] = self.model.to_next(n) / (reached[n + 1] - previous)
                previous = reached[n + 1]
        # no level is paced slower than grinding: the walk can always do that
        for n in range(1, self.s.cap):
            self.rate_curve[n] = max(self.rate_curve.get(n, 0.0), self.model.grind_xp_per_second(n))

    def _lookahead(self, start_hub: int, progress) -> Plan:
        st = self.start(start_hub)
        self.calibrate(self._finish(self.rollout(st)))
        step = 0
        decisions: list = []
        while not self.terminal(st) and st.depth < self.s.max_depth:
            step += 1
            candidates = self.children(st, self.s.branch)
            if not candidates:
                break
            valued = [(self.score(self.rollout(child, self.s.horizon)), child) for child in candidates]
            value, chosen = min(valued, key=lambda pair: pair[0])
            if chosen.visit is not None and chosen.visit.hub is not None and chosen.visit.zone_change:
                best: dict = {}
                for score, child in valued:
                    if child.zone != chosen.zone and (child.zone not in best or score < best[child.zone][0]):
                        best[child.zone] = (score, child.zone, child.level, child.clock)
                decisions.append(
                    dict(
                        depth=chosen.depth,
                        clock=st.clock,
                        level=st.level,
                        from_zone=st.zone,
                        to_zone=chosen.zone,
                        travel=chosen.visit.travel_seconds,
                        chosen=value,
                        alternatives=sorted(best.values())[:3],
                    )
                )
            st = chosen
            if progress and step % 50 == 0:
                progress(f"  lookahead step {step}: level {st.level}, {st.clock / 3600:.1f} h")
        plan = self._finish(st)
        plan.decisions = decisions
        return plan

    def _bucket(self, st: PState, parts: int) -> int:
        """How far a route has got: the level and the part of the next one (`parts` to a level), one bucket from the cap on."""
        if st.level >= self.s.cap:
            return self.s.cap * parts
        return st.level * parts + int(min(st.xp / max(1.0, self.model.to_next(st.level)), 0.999) * parts)

    def _beam(self, start_hub: int, progress) -> Plan:
        """A beam over how far the routes have got. Partial routes are compared with others that have got as far (the same level and
        part of the next), never with a route that has made as many visits: a route that dawdles is not ahead of one that has levelled,
        and the one that has levelled is not penalised for it. One run per entry of `Settings.parts` (a different grain of progress
        each, every one independent: what an earlier grain found never prunes a later one). The runs' best finished routes are then
        compared as they would be written, tidied (a guide may not leave quests in the log, and taking them out can cost a route much),
        with the greedy route tidied too: the result is never slower than that."""
        s = self.s
        base = self._finish(self.rollout(self.start(start_hub)))
        self.calibrate(base)
        known = base.final.total if base.complete else float("inf")
        runs = [self._layers(start_hub, max(1, parts), known, progress) for parts in s.parts or (2,)]
        reference = self.tidy(base, start_hub)
        origin: dict[int, BeamRun] = {}
        tidied: list[Plan] = []
        seen: set = set()
        for final, run in sorted(((f, r) for r in runs for f in r.finished), key=lambda pair: pair[0].total):
            sig = self.signature(final)
            if sig in seen:
                continue
            seen.add(sig)
            candidate = self.tidy(self._finish(final), start_hub)
            origin[id(candidate)] = run
            tidied.append(candidate)
            if len(tidied) >= s.alternatives + 8:
                break
        pool = sorted((c for c in tidied if c.complete), key=lambda c: c.total)
        plan = pool[0] if pool and (not reference.complete or pool[0].total < reference.total) else reference
        winner = origin.get(id(plan), runs[0])
        plan.decisions = self._beam_decisions(plan.final, winner) if plan is not reference else []
        plan.trace = winner.trace
        plan.alternatives = [c for c in pool if c is not plan][: s.alternatives]
        plan.stats.update(
            pruned=sum(r.pruned for r in runs),
            finals=sum(r.finals for r in runs),
            baseline_seconds=reference.total,
            runs=len(runs),
            chosen="greedy" if plan is reference else "beam",
        )
        return plan

    def _layers(self, start_hub: int, parts: int, best_time: float, progress) -> "BeamRun":
        """One beam run: the buckets of progress are taken in order, each keeps its `width` best routes (by the estimate of the whole
        route), and every one of them is tried at `branch` hubs. A route that lands in the bucket being worked is worked on with it
        again, so the routes in a bucket are always compared with each other, never with ones that have not got there yet.
        `best_time` is the total of the route to beat (the greedy one's); a route that finishes lowers it for the rest of this run."""
        s = self.s
        run = BeamRun(parts)
        start = self.start(start_hub)
        layers: dict[int, dict] = {self._bucket(start, parts): {start.key(): (self.score(start), start)}}
        last_level = 0
        while layers:
            b = min(layers)
            ranked = sorted(layers.pop(b).values(), key=lambda pair: pair[0])
            width = max(1, s.width)
            run.pruned += max(0, len(ranked) - width)
            ranked = ranked[:width]
            held = run.log.setdefault(b, [])
            held.extend((value, st.zone, st.level, st.clock) for value, st in ranked[:24])
            held.sort(key=lambda item: item[0])
            del held[24:]
            run.trace.append((b / parts, len(ranked), ranked[0][0]))
            if progress and b // parts > last_level:
                last_level = b // parts
                progress(f"  beam ({parts} to a level), level {last_level}: {len(ranked)} routes kept, best estimate {ranked[0][0] / 3600:.2f} h")
            for _, st in ranked:
                for child in self.children(st, s.branch):
                    if child.depth >= s.max_depth:
                        continue
                    if self.terminal(child):
                        run.finals += 1
                        run.finished.append(child)
                        best_time = min(best_time, child.total)  # the bound of this run only
                        continue
                    if self.hopeless(child, best_time):
                        run.pruned += 1
                        continue
                    value = self.score(child)
                    key = child.key()
                    slot = layers.setdefault(self._bucket(child, parts), {})
                    if key in slot:
                        run.pruned += 1  # the same situation, reached by another way, and as far on: only the better one lives on
                        if slot[key][0] <= value:
                            continue
                    slot[key] = (value, child)
        return run

    def _beam_decisions(self, final: PState, run: "BeamRun") -> list:
        """At each change of zone on the route the search chose: the estimate of the route it chose and of the best route in each
        other zone the beam held in that bucket of progress (the same estimator it ranked them with)."""
        path, st = [], final
        while st is not None:
            path.append(st)
            st = st.parent
        path.reverse()
        decisions = []
        for before, after in zip(path, path[1:]):
            v = after.visit
            if v is None or v.hub is None or not v.zone_change:
                continue
            chosen = self.score(after)
            best: dict = {}
            for score, zone, level, clock in run.log.get(self._bucket(after, run.parts), ()):
                if zone != after.zone and (zone not in best or score < best[zone][0]):
                    best[zone] = (score, zone, level, clock)
            decisions.append(
                dict(
                    depth=after.depth,
                    clock=before.clock,
                    level=before.level,
                    from_zone=before.zone,
                    to_zone=after.zone,
                    travel=v.travel_seconds,
                    chosen=chosen,
                    alternatives=sorted(best.values())[:3],
                )
            )
        return decisions

    def signature(self, final: PState) -> tuple:
        """The order of zones a route visits (a run in one zone counts once): two routes with the same one are the same route."""
        zones: list = []
        st = final
        while st is not None and st.visit is not None:
            if st.visit.hub is not None and (not zones or zones[-1] != st.zone):
                zones.append(st.zone)
            st = st.parent
        return tuple(reversed(zones))

    # the route as guide text ------------------------------------------------------------------------------------------

    def skipquests(self, plan: Plan) -> dict[int, str]:
        """The `#skipquest` lines a route needs: class quests it does not do (with why), and the alternatives to a quest it did."""
        skips: dict[int, str] = {}
        done = plan.final.done if plan.final else frozenset()
        for qid in sorted(self.mandatory):
            if qid in done:
                continue
            if qid in self.skip_reasons:
                skips[qid] = self.skip_reasons[qid]
            elif qid not in self.quests:
                why = next((reason for reason, ids in self.dropped.items() if qid in ids), "not routable here")
                skips[qid] = f"the planner could not route it: {why}"
            else:
                chosen = next((x for x in self.quests[qid].excl if x in done), None)
                skips[qid] = f"alternative to quest {chosen}, which is routed" if chosen else "not reached by this route"
        for qid in self.dropped.get("excluded", ()):
            if qid in self.skip_reasons and qid not in skips:
                skips[qid] = self.skip_reasons[qid]
        for qid in done:
            for other in self.quests[qid].excl:
                if other not in done and other in self.quests and other not in skips:
                    skips[other] = f"alternative to quest {qid}, which is routed"
        return skips

    def hub_near(self, coord: Coord) -> int | None:
        """The hub a coordinate is in, or the nearest hub on its map."""
        found = self.hub_of.get((coord.map, coord.x, coord.y))
        if found is not None:
            return found
        on_map = [h for h in self.hubs if h.map == coord.map]
        return min(on_map, key=lambda h: self._yards(h.center, coord)).id if on_map else None

    def hub_name(self, hub: int | None) -> str:
        return self.hubs[hub].label if hub is not None else "(grinding)"

    def emit(self, plan: Plan, class_token: str, split_after: int = 10) -> list:
        """The route as chapters of guide steps: written one place at a time, then neighbouring steps of one kind joined
        (signpost_tools/steps.py: a pick-up and hand-in step per area, a doing step per group of quests whose objectives are
        near each other), a `.level` line before a quest above the last level asked for, a `.level` step for a grind,
        `.optional` on group quests and `.note` where the rules have one. A chapter ends where the zone changes (once it has
        `split_after` steps)."""
        chapters: list[ChapterText] = []
        current: ChapterText | None = None
        gated = 0
        level = 1
        for v in plan.visits:
            zone = self.hubs[v.hub].zone if v.hub is not None else (current.zone if current else None)
            if current is None or (v.hub is not None and zone != current.zone and len(current.steps) >= split_after):
                current = ChapterText(zone, level)
                chapters.append(current)
            if v.hub is None:
                target = v.actions[0].index
                current.steps.append([f"  .level {target} -- reach it first: kill or grind on the way"])
                gated = max(gated, target)
                level = v.level
                current.level_out = level
                continue
            group: list[Action] = []
            for a in v.actions + [None]:
                if group and (a is None or a.place != group[0].place):
                    gated = self._step(current, group, class_token, gated)
                    group = []
                if a is not None:
                    group.append(a)
            level = v.level
            current.level_out = level

        def near(a: Coord, b: Coord) -> bool:
            return a.map == b.map and self._yards(a, b) <= self.s.group_yards

        def objectives(qid: int) -> list[int] | None:
            return [o.index for o in self.quests[qid].objectives] if qid in self.quests else None

        for chapter in chapters:
            chapter.steps = steps.group(chapter.steps, near, objectives)
        return chapters

    def _step(self, chapter: "ChapterText", group: list, class_token: str, gated: int) -> int:
        place = group[0].place
        lines = [f"  .goto {place.dsl()}"] if place is not None else []
        optional: dict[int, str] = {}
        for a in group:
            q = self.quests[a.quest]
            name = guide_draft._clean(q.name)
            gate = guide_draft.class_gate(q.class_mask, class_token)
            if a.kind == "accept":
                if q.req > 1 and q.req > gated:
                    lines.append(f"  .level {q.req}")
                    gated = q.req
                lines.append(f"  .accept {q.id}{gate} -- {name}")
                if q.unknown_work:
                    lines.append(f'  .todo "{name}: the pack has no objective for it; read what it asks in the quest log"')
                if q.id in self.notes:
                    lines.append(f"  .note {guide_draft._clean(self.notes[q.id])}")
            elif a.kind == "turnin":
                if q.end_unknown:
                    lines.append(f'  .todo "{name}: the turn-in has no position in the pack"')
                lines.append(f"  .turnin {q.id}{gate} -- {name}")
            else:
                objective = next((o for o in q.objectives if o.index == a.index), None)
                if objective is None or not objective.spots:
                    why = "is only in places this guide does not go" if objective is not None and objective.elsewhere else "has no position in the pack"
                    lines.append(f'  .todo "{name}: objective {a.index} {why}"')
                lines.append(f"  .complete {q.id},{a.index}{gate} -- {name}")
                if q.scripted:
                    lines.append(f"  .note {name}: {SCRIPTED_NOTES[(q.scripted, self.s.hardcore)]}")
            if q.optional:
                optional[q.id] = name
        for qid, name in optional.items():
            lines.append(f"  .optional {qid} -- group quest: {name}")
        chapter.steps.append(lines)
        return gated


@dataclass
class ChapterText:
    zone: int | None
    level_in: int
    level_out: int = 0
    steps: list = field(default_factory=list)

    def text(self, name: str) -> str:
        lines = [f"#chapter {self.level_in}-{max(self.level_in, self.level_out)} {name}"]
        for step in self.steps:
            lines.append("step")
            lines.extend(step)
        return "\n".join(lines) + "\n"


# helpers ---------------------------------------------------------------------------------------------------------------


def slug(text: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")


def _unique(coords: list) -> list:
    seen, out = set(), []
    for c in coords:
        key = (c.map, c.x, c.y)
        if key not in seen:
            seen.add(key)
            out.append(c)
    return out


def start_hub_for(planner: Planner, level: int = 1) -> int | None:
    """Where a character begins: the giver of the lowest-level quest only its race gets (its own first quest), else of the
    lowest-level quest there is (guide_draft.start_place's rule over the planner's quests)."""
    records = planner.pack.table("quests")
    own = [
        q
        for q in planner.quests.values()
        if isinstance((records.get(q.id) or {}).get("races"), int)
        and records[q.id]["races"] not in guide_draft.FACTION_MASKS
        and q.class_mask is None
        and q.req <= level
    ]
    pool = own or [q for q in planner.quests.values() if q.req <= level] or list(planner.quests.values())
    first = min(pool, key=lambda q: (q.req, q.level, q.id), default=None)
    if first is None:
        return None
    c = first.start_places[0]
    return planner.hub_of[(c.map, c.x, c.y)]
