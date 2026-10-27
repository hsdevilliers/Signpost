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
# Why a normal route tags a quest `.optional` (`PQuest.group`): the comment of its `.optional` line, and the `.note` the accept carries (an elite kill is a
# group quest and needs no note: the player knows).
GROUP_COMMENTS = {"elite": "group quest", "dungeon": "dungeon quest", "follows": "follows a group quest"}
GROUP_NOTES = {"dungeon": "dungeon quest: needs a group", "follows": "follows a group quest: needs a group too"}
GRAIN_TRIES = 5  # finished routes of one grain (a different order of zones each) written out to find that grain's best


class RequiredQuestError(ValueError):
    """A quest the guide requires (`Planner.build(required=...)`) cannot be offered to this character: the message names each and says why."""


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
    walk_by_map: bool = False  # charge the walk between the places of one hub by the map's distance (and from the hub's centre to the first), not local_walk
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
    # The most quests the log holds at once; an accept is refused while it is full (a quest handed in at the NPC that gave it needs a free place
    # too). Classic's is 25, Forever's is 40: confirmed by the user in the game, 2026-10-21 (they had said so before: "I believe the quest log
    # limit has been bumped up from 25 to 40 for WoW Forever").
    quest_log_limit: int = 40
    chapter_min_steps: int = 3  # a change of zone starts a new chapter only when the new zone lasts at least this many steps (counted once joined)
    # Finishing what the route picks up (docs/PLANNER.md, "Completeness"). The search accepts a quest wherever it passes (an accept costs it nothing)
    # and works it only when that is the better use of the time; one still in the log at the end is taken out when the route is written
    # (`Planner.tidy`). With `completeness` F > 0, tidy first tries to finish it: a stop at its objectives, right after the pick-up, when they are at
    # most `completeness_trip` seconds of walking away and the quest pays at least F times the route's pace (experience per second, the trip
    # included). The user chose 0.6 and 45 s (2026-10-21) from the table in docs/PLANNER.md, "Measurements". 0 is off: the quest is taken out, and the
    # report says why (a record for each in `plan.stats["left_out"]`).
    completeness: float = 0.6
    completeness_trip: float = 45.0
    # Stops (backlog `plan-stops-together-...`, the user's first fresh-character test, 2026-10-21): a guide does everything one area offers in one
    # stop. `stop_yards`: the quest givers and enders within that many yards of a hub's centre are part of one visit to the hub (hand in everything
    # ready, take everything offered, then go), and a completeness stop goes after the run of nearby visits that follow the pick-up, not right
    # after it. `share_yards`: while an objective is worked, the other open objectives with a spot within that many yards are worked there too, hub
    # boundary or not, and an objective with spots in several hubs is worked at the spot nearest the most others when that hub is at most
    # `share_trip` seconds away. 0 switches a rule off.
    stop_yards: float = 150.0
    share_yards: float = 100.0
    share_trip: float = 30.0


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
    optional: bool = False  # a group quest in a normal guide: an elite kill, a dungeon quest, or what needs one of those first
    group: str = ""  # why: "elite", "dungeon" or "follows" (it needs a group quest first); GROUP_COMMENTS
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

    __slots__ = ("hub", "zone", "level", "xp", "clock", "penalty", "late", "gated", "done", "active", "gone", "parent", "visit", "depth", "ground", "work_here")

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
        self.work_here: bool | None = None  # whether a required quest has work in this zone (`Planner._work_here`), found when first asked

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

    def log_peak(self) -> tuple[int, int, float]:
        """The most quests the route holds in the quest log at once, counted action by action (an accept adds one, a hand-in takes one out),
        with the level the character had when the visit that first reached it began and the clock then. (0, 1, 0.0) for an empty route."""
        held = peak = 0
        level, clock = 1, 0.0
        at = (1, 0.0)
        for v in self.visits:
            for a in v.actions:
                if a.kind == "accept":
                    held += 1
                    if held > peak:
                        peak, at = held, (level, clock)
                elif a.kind == "turnin":
                    held -= 1
            level, clock = v.level, clock + v.seconds
        return peak, at[0], at[1]


@dataclass
class BeamRun:
    """What one run of the beam found."""

    parts: int  # buckets to a level
    finals: int = 0  # routes it finished
    finished: list = field(default_factory=list)
    pruned: int = 0
    trace: list = field(default_factory=list)  # (level, routes kept, best estimated total seconds) for each bucket worked
    log: dict = field(default_factory=dict)  # bucket -> the best routes held in it: (estimate, zone, level, clock)
    seconds: float = 0.0  # how long the run took
    best: "Plan | None" = None  # the best of its finished routes as it would be written (tidied); None when it finished none


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
        self.mandatory: set[int] = set()  # the class quests and the required ones: each is done, or (a class quest) accounted for
        self.asked: set[int] = set()  # the quests the guide names as required (`Planner.build(required=...)`)
        self.required: set[int] = set()  # ... and the quests they need: all mandatory like a class quest, and never given up (docs/PLANNER.md)
        self._closes_required: set[int] = set()  # the quests that would close a required one (its exclusive alternatives): never taken
        self.notes: dict[int, str] = {}
        self.skip_reasons: dict[int, str] = {}
        self.gateways: dict[int, int] = {}  # continent (world instance) -> the hub its boats and zeppelins leave from
        self.rate_curve: dict[int, float] = {}  # experience per second by level, from a greedy walk (the cost-to-go)
        self._travel: dict[tuple, float] = {}
        self._objective: dict[tuple, tuple] = {}
        self._reward: dict[tuple, float] = {}
        self._rates: dict[tuple, bool] = {}
        self._order: dict[tuple, list] = {}
        self._extras: dict[int, list] = {}  # hub -> the nearby places of other hubs a visit to it also walks (`extras`)
        self._near_spots: dict[tuple, list] = {}  # an objective place -> the (quest, objective) pairs with a spot within `share_yards` of it
        self.nodes_made = 0
        self.skip_zones: dict[int, str] = {}  # map -> why no quest of it is routed (a battleground)
        self._giver_index: dict[int, list] = {}  # start NPC -> (quest, name, class mask) of every quest of the pack
        self._required: set[int] = set()  # quests that another quest needs first
        self.home: Coord | None = None  # where the character begins
        self.core: set[int] = set()  # the class quests and the quests they need: all that is done once the cap is reached
        self.forbidden: set[int] = set()  # quests a tidied route no longer accepts (it never turned them in)
        self.lifted: frozenset = frozenset()  # ... except the ones tidy is finishing at the visit being replayed (`_finishable`)
        self._ratio: dict[tuple, float] = {}  # (quest, level) -> what the quest pays against the route's pace (`finish_ratio`)
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
        required: tuple = (),
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
        planner.asked = set(required)
        planner.required = set(required)
        planner.mandatory = set(mandatory) | planner.required
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
        planner._expand_required()
        planner._prune_territory(character.faction)
        planner._prune_unreachable()
        planner._mark_group_chains()
        planner._check_required()
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
        scripted = "" if qid in self.mandatory and qid not in self.required else (self.model.scripted_work(qid) or "")
        unknown_work = not objectives and one_npc and not scripted
        if unknown_work and not s.instant_quests and qid not in self.mandatory and qid not in self._required and not record.get("next"):
            return self._drop("no objective in the data (accepted and handed in at one NPC)", qid)
        if scripted:  # the one objective that stands for the work: done where the quest starts, which is where the escort sets off
            objectives.append(PObjective(1, "scripted", 0, list(starts)))
        dungeon = self._in_instance(record)
        if s.hardcore and elite:
            return self._drop("HARDCORE: needs an elite or boss kill", qid)
        if s.hardcore and dungeon:
            return self._drop("HARDCORE: dungeon quest (needs a group)", qid)
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
            optional=(elite or dungeon) and not s.hardcore,
            group="elite" if elite else ("dungeon" if dungeon else ""),
            mandatory=qid in self.mandatory,
            end_unknown=end_unknown,
            unknown_work=unknown_work and qid in self.mandatory,
            scripted=scripted,
        )

    def _in_instance(self, record: dict) -> bool:
        """Whether a quest belongs to a dungeon or a raid: the pack gives the quest the zone it is sorted under, and a dungeon's id is not one of the pack's maps (its
        world zones, continents and battlegrounds are); a quest with no zone is not. Its objectives lie inside, and a solo player cannot do them."""
        zone = record.get("zone")
        maps = self.pack.table("maps")
        return bool(maps) and isinstance(zone, int) and not isinstance(zone, bool) and zone not in maps

    def _mark_group_chains(self) -> None:
        """A quest that needs a group quest first (the pack's prerequisites, or the chain that hands it over) cannot be done solo either: a normal route tags it
        `.optional` too, and so on down the chain. A quest with alternatives (any one of its `preSingle`) is tagged only when every alternative is. A class
        quest keeps its place. (A HARDCORE route has dropped the group quests and, with them, everything that needs them.)"""
        changed = True
        while changed:
            changed = False
            for q in self.quests.values():
                if q.optional or q.mandatory:
                    continue
                needed = [self.quests[p] for p in list(q.pre_all) + list(q.parents) if p in self.quests]
                alternatives = [self.quests[p] for p in q.pre_any if p in self.quests]
                if any(p.optional for p in needed) or (alternatives and all(p.optional for p in alternatives)):
                    q.optional, q.group = True, "follows"
                    changed = True

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

    def _expand_required(self) -> None:
        """The quests a required quest needs are required too: all mandatory, so that the search does them (and is pushed to, like a class chain's
        quests) and not only keeps them. Of the alternatives a quest takes (any one of its `preSingle`) the one that pays best stands for them."""
        todo = [qid for qid in self.required if qid in self.quests]
        while todo:
            q = self.quests[todo.pop()]
            needed = list(q.pre_all) + ([q.parent] if q.parent is not None else [])
            options = [p for p in q.pre_any if p in self.quests]
            if options and not any(p in self.required for p in options):
                nominal = lambda p: min(self.s.cap, max(self.quests[p].req, self.quests[p].level - 1, 1))  # noqa: E731
                needed.append(max(options, key=lambda p: self._quest_rate(self.quests[p], nominal(p))))
            for p in needed:
                if p in self.quests and p not in self.required:
                    self.required.add(p)
                    self.mandatory.add(p)
                    self.quests[p].mandatory = True
                    todo.append(p)

    def _why_not(self, qid: int, depth: int = 0) -> str:
        """Why a quest is not among the ones this character's route can use: the reason `_consider` or a prune gave it, and for a quest whose
        prerequisite cannot be routed, which prerequisite and why."""
        record = self.pack.table("quests").get(qid)
        if not isinstance(record, dict):
            return "it is not in the data pack"
        reason = next((r for r, ids in self.dropped.items() if qid in ids), None)
        if reason is None:
            return "the planner left it out"
        if reason == "excluded":
            return f"it is excluded ({self.skip_reasons.get(qid, 'by the guide')})"
        if reason == "a prerequisite cannot be routed" and depth < 4:
            needed = guide_draft._ids(record.get("preGroup"))
            alternatives = guide_draft._ids(record.get("preSingle"))
            gaps = [p for p in needed if p not in self.quests] or ([] if any(p in self.quests for p in alternatives) else alternatives)
            if gaps:
                return "a prerequisite cannot be routed: " + "; ".join(f"{p} ({self._why_not(p, depth + 1)})" for p in gaps[:3])
        return reason

    def _check_required(self) -> None:
        """Every required quest must be one the character's route can use; if not, a clear error names each and says why (not the availability
        rules' fault alone: a HARDCORE route's elite rule, an exclusion or a prerequisite that cannot be routed stops a quest the same way)."""
        problems: list[str] = []
        for qid in sorted(self.asked):
            record = self.pack.table("quests").get(qid)
            name = f" ({record['n']})" if isinstance(record, dict) and record.get("n") else ""
            if qid not in self.quests:
                problems.append(f"quest {qid}{name}: {self._why_not(qid)}")
                continue
            q = self.quests[qid]
            if max(q.req, q.level - self.accept_over) > self.s.cap:
                problems.append(f"quest {qid}{name}: it can be accepted from level {max(q.req, q.level - self.accept_over)}, above the route's cap of {self.s.cap}")
            for other in q.excl:
                if other in self.asked and other > qid:
                    problems.append(f"quests {qid}{name} and {other} are exclusive alternatives: both cannot be required")
        if problems:
            raise RequiredQuestError("a required quest cannot be offered to this character:\n  " + "\n  ".join(problems))
        self._closes_required = {x for r in self.required for x in self.quests[r].excl} | {
            q.id for q in self.quests.values() if q.id not in self.required and self.required & set(q.excl)
        }

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

    def _legs(self, actions: list) -> float:
        """The walking between the places of a visit's actions, in turn, by the map's distance and the detour factor (`Settings.walk_by_map`)."""
        total = 0.0
        for a, b in zip(actions, actions[1:]):
            if a.place != b.place:
                total += self._yards(a.place, b.place) / guide_travel.WALK_SPEED * self.s.detour
        return total

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

    def extras(self, hub: int) -> list:
        """With `Settings.stop_yards`: the places of other hubs on the map where a quest is given or handed in, within that many yards of this hub's
        centre, nearest first. A visit to the hub walks them too, so the quest givers and enders of one stop are one visit."""
        if self.s.stop_yards <= 0:
            return []
        if hub not in self._extras:
            here, found = self.hubs[hub], []
            for other in self.hubs:
                if other.id == hub or other.map != here.map or self._yards(here.center, other.center) > self.s.stop_yards + self.s.hub_radius:
                    continue
                for c in self.places_at.get(other.id, ()):
                    key = (c.map, c.x, c.y)
                    if (key in self.starts_by_place or key in self.ends_by_place) and self._yards(here.center, c) <= self.s.stop_yards:
                        found.append(c)
            found.sort(key=lambda c: self._yards(here.center, c))
            self._extras[hub] = found
        return self._extras[hub]

    def _neighbours(self, c: Coord) -> list:
        """The (quest, objective) pairs with a spot within `Settings.share_yards` of this one."""
        key = (c.map, c.x, c.y)
        if key not in self._near_spots:
            home, found = self.hub_of[key], []
            here = self.hubs[home]
            for other in self.hubs:
                if other.map != here.map or self._yards(here.center, other.center) > self.s.share_yards + 2 * self.s.hub_radius:
                    continue
                for place in self.places_at.get(other.id, ()):
                    pairs = self.objs_by_place.get((place.map, place.x, place.y))
                    if pairs and self._yards(c, place) <= self.s.share_yards:
                        found.extend(pairs)
            self._near_spots[key] = found
        return self._near_spots[key]

    def _shared(self, q: PQuest, c: Coord, level: int, done, active, gone) -> int:
        """How many other quests have an objective spot near this one and are open or about to be: the quests one trip to the spot would serve."""
        others = set()
        for q2, _o2 in self._neighbours(c):
            if q2.id == q.id or q2.id in others or q2.id in done or q2.id in gone or not self.soon(q2, level):
                continue
            if q2.id in active or self.offered(q2, level, done, active, gone):
                others.add(q2.id)
        return len(others)

    def _defer(self, q: PQuest, o: PObjective, here: Coord, hub: int, came: int | None, level: int, done, active, gone) -> bool:
        """With `Settings.share_yards`: whether this objective is better worked at a spot of another hub, a short walk away, that is near more of the
        other open objectives than this one is (the route comes to it there: the hub is one of the objective's `hubs`)."""
        if len(o.spots) < 2:
            return False
        best = self._shared(q, here, level, done, active, gone)
        for c in o.spots:
            h = self.hub_of[(c.map, c.x, c.y)]
            if h == hub or h == came or self.travel(hub, h) > self.s.share_trip:  # (not back to where the route came from: no ping-pong)
                continue
            if self._shared(q, c, level, done, active, gone) > best:
                return True
        return False

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
        """Whether the quest may be accepted now: the game offers it (level, prerequisites, chains, ...), the route still wants it, and the
        quest log has a free place. Every accept the searches make or predict goes through here (`visit`, `options`, `overdue_hubs`)."""
        if len(active) >= self.s.quest_log_limit and q.id not in self.required:
            return False  # (a required quest is never kept out by a full log)
        if level < q.req or q.level > level + self.accept_over or (q.id in self.forbidden and q.id not in self.lifted):
            return False
        if q.id in self._closes_required:
            return False  # taking it would close a required quest
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

    def _work_here(self, st: PState) -> bool:
        """Whether a required quest has work in the zone the route stands in: one the game would offer that starts here, one with an open objective
        here, one whose hand-in is here. The route does not leave a zone with that undone (it may do anything else there first), so a required
        chain is finished before the route goes on, and one level-gated waits for the level in the zone."""
        if st.work_here is None:
            found = False
            for qid in self.required:
                if qid in st.done or qid in st.gone:
                    continue
                q = self.quests[qid]
                open_ = st.active.get(qid)
                if open_ is None:
                    if not self.ready(q, st.done, st.active, st.gone):
                        continue
                    hubs = q.start_hubs
                elif open_:
                    hubs = tuple(h for o in q.objectives if o.index in open_ for h in o.hubs)
                else:
                    hubs = q.end_hubs
                if any(self.hubs[h].zone == st.zone for h in hubs):
                    found = True
                    break
            st.work_here = found
        return st.work_here

    def leaving(self, st: PState) -> list[int]:
        """The hubs the route must go to now: it holds a required quest that has only to be handed in, and only in another zone (the ride out
        of a story zone, such as the exit quest of a start island), and has no required work left in this one, so it leaves for it with nothing
        else done first."""
        if not self.required or st.hub is None or self._work_here(st):
            return []
        found: list[int] = []
        for qid, open_ in st.active.items():
            if qid in self.required and not open_:
                found += self.quests[qid].end_hubs  # (none of them is in this zone: that would be work here)
        return sorted(set(found))

    def options(self, st: PState) -> dict[int, float]:
        """The hubs with something to do now, with a rough worth for ranking: the experience at stake there."""
        leaving = self.leaving(st)
        if leaving:
            return {h: 1.0 for h in leaving}
        worth = self._options(st)
        if self.required and st.hub is not None and self._work_here(st):
            worth = {h: w for h, w in worth.items() if self.hubs[h].zone == st.zone}  # the zone lock
        return worth

    def _options(self, st: PState) -> dict[int, float]:
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
        walk_places = self.order(hub, st.hub)
        extra = self.extras(hub)
        extra_keys = {(c.map, c.x, c.y) for c in extra}
        walk_places = walk_places + extra if extra else walk_places
        while progressed and sweeps < 8:
            progressed, sweeps = False, sweeps + 1
            for place in walk_places:
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
                    for q, o in () if key in extra_keys else self.objs_by_place.get(key, ()):
                        if progress.level >= s.cap and q.id not in self.core:
                            continue
                        if q.id in active and o.index in active[q.id] and self.soon(q, progress.level):
                            if s.share_yards > 0 and self._defer(q, o, place, hub, st.hub, progress.level, done, active, gone):
                                continue
                            seconds, wait, xp = self.objective(q.id, o.index, progress.level)
                            objective += seconds - wait
                            longest_wait = max(longest_wait, wait)
                            gained += progress.gain(xp)
                            actions.append(Action("complete", q.id, o.index, place))
                            active[q.id].discard(o.index)
                            changed = True
                            if s.share_yards > 0:  # the other open objectives with a spot near this one are worked here too, hub or no hub
                                for q2, o2 in self._neighbours(place):
                                    if (
                                        q2.id in active and o2.index in active[q2.id] and o2.spots and self.soon(q2, progress.level)
                                        and not (progress.level >= s.cap and q2.id not in self.core)
                                    ):
                                        near = min(o2.spots, key=lambda c: self._yards(place, c))
                                        if self._yards(place, near) > s.share_yards:
                                            continue
                                        seconds, wait, xp = self.objective(q2.id, o2.index, progress.level)
                                        objective += seconds - wait
                                        longest_wait = max(longest_wait, wait)
                                        gained += progress.gain(xp)
                                        actions.append(Action("complete", q2.id, o2.index, near))
                                        active[q2.id].discard(o2.index)
                    progressed = progressed or changed
        if not actions:
            return None
        if s.walk_by_map:  # (an experiment) the walk between the places of the hub is priced by the map, from the hub's centre to the first one too
            walk = self.travel(st.hub, hub) + self._legs(actions) + self._yards(self.hubs[hub].center, actions[0].place) / guide_travel.WALK_SPEED * s.detour
        else:
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
            if len(active) >= self.s.quest_log_limit and q.id not in self.required:
                continue  # a full log accepts nothing, whatever the level: no quest is waited for (a required one is)
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
        if not q.mandatory or q.id in self.required:
            return 0.0  # (a required quest is not pushed: a chain of thirty quests would drown the real time; the zone lock schedules it)
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
            if qid in self.required:
                continue
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
        if self.leaving(st):
            return []
        locked = bool(self.required) and st.hub is not None and self._work_here(st)
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
                if h != st.hub and not (locked and self.hubs[h].zone != st.zone):
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
        if out and self.leaving(st):
            return out  # the route is leaving for a hand-in: nothing else is an option, not even a grind
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
        """A guide must not accept a quest it never turns in: the quests a search left in the log at the end (it reached the cap first) are taken
        out of the route, and the same hubs are walked again without them (more than once if that leaves others unfinished); a level that falls
        short is ground at the end. Nothing is taken out silently: `plan.stats["left_out"]` has a record for each quest, with the reason and the
        numbers (`Planner._left_out`).

        With `Settings.completeness` F > 0 a quest is finished before it is taken out, if that is cheap (`_finishable`): the walk is repeated with
        a stop at its objectives right after the pick-up (and one at the place to hand it in, if the route does not pass it later). A quest finished
        this way is in `plan.stats["completed"]`; one that still is not finished after that is taken out for good."""
        stats, trace, preset = dict(plan.stats), plan.trace, plan.preset
        alternatives, decisions = plan.alternatives, plan.decisions
        removed: set[int] = set()
        gave_up: set[int] = set()  # a stop was added for them and they still were not finished
        lifted_before: set[int] = set()
        found: dict[int, tuple] = {}  # quest -> `_pickups` of the plan it was first found unfinished in: (level, place, hub, whether the route passes a hand-in later)
        for _ in range(6 if self.s.completeness > 0 else 4):
            active = set(plan.final.active) if plan.final else set()
            stuck = active & lifted_before
            unseen = active - removed - self.required
            if not (stuck or unseen):
                break
            levels = self._pickups(plan)
            for qid in unseen:
                found.setdefault(qid, levels.get(qid))
            gave_up |= stuck
            removed |= unseen | stuck
            lifts, stops = self._finishable(plan, removed - gave_up) if self.s.completeness > 0 else ({}, {})
            if self.s.stop_yards > 0 and stops:
                stops = self._after_cluster(plan, stops)
            lifted_before = {qid for ids in lifts.values() for qid in ids}
            self.forbidden = set(removed)
            st = self.start(start_hub)
            for index, v in enumerate(plan.visits):
                if v.hub is None:  # a level ground to open quests that waited for it: ground again, to the same level
                    target = v.actions[0].index
                    child = self._grind_to(st, target) if target > st.level else None
                else:
                    self.lifted = frozenset(lifts.get(index, ()))
                    child = self.visit(st, v.hub)
                    self.lifted = frozenset()
                if child is not None:
                    st = child
                for hub in stops.get(index, ()):  # a stop at the objectives (or the place to hand in) of a quest picked up at this visit
                    stop = self.visit(st, hub)
                    if stop is not None:
                        st = stop
            plan = self._finish(self.rollout(st))
        self.forbidden, self.lifted = set(), frozenset()
        completed = {qid for qid in lifted_before if plan.final and qid in plan.final.done}
        plan.stats, plan.trace, plan.preset = stats, trace, preset
        plan.alternatives, plan.decisions = alternatives, decisions
        gone = sorted(removed - completed)
        plan.stats["removed"] = sorted(set(gone) | set(stats.get("removed", ())))  # a plan tidied twice still says what was taken out
        plan.stats["completed"] = sorted(completed | set(stats.get("completed", ())))  # and what was saved by finishing it
        plan.stats["completed_unplaced"] = [qid for qid in plan.stats["completed"] if self.unplaced(qid)]  # (how many of those the data cannot place)
        records = {r["quest"]: r for r in stats.get("left_out", ())}
        for qid in gone:
            records[qid] = self._left_out(qid, found.get(qid), qid in gave_up)
        plan.stats["left_out"] = [records[qid] for qid in sorted(records, key=lambda i: (records[i]["picked_level"] or 0, i))]
        return plan

    def xp_pace(self, level: int) -> float:
        """The experience per second the route makes at a level: the pace of the greedy walk the searches are calibrated with (grinding's, before
        a calibration)."""
        return self.rate_curve.get(level) or self.model.grind_xp_per_second(level)

    def finish_ratio(self, q: PQuest, level: int) -> float:
        """What a quest pays when it is picked up on the route and finished (experience per second, the walk to its objectives and the hand-in
        included, at this level) against the route's pace at that level: 1 is the same, 0.8 a fifth less."""
        key = (q.id, level)
        if key not in self._ratio:
            self._ratio[key] = self._quest_rate(q, level) / max(self.xp_pace(level), 1e-9)
        return self._ratio[key]

    def trip(self, q: PQuest, place: Coord) -> tuple:
        """What finishing a quest picked up at `place` asks, beyond the pick-up: (seconds of walking, from there, to the farthest of its objectives
        (0 for a quest with none); the hubs of the nearest places to work them, nearest first; seconds of walking to the nearest place to hand it
        in; the hub of that place)."""
        speed, detour = guide_travel.WALK_SPEED, self.s.detour
        ways: dict[int, float] = {}
        for o in q.objectives:
            nearest = min(o.spots or q.start_places, key=lambda c: self._yards(place, c))
            hub = self.hub_of[(nearest.map, nearest.x, nearest.y)]
            ways[hub] = min(ways.get(hub, float("inf")), self._yards(place, nearest) * detour / speed)
        end = min(q.end_places, key=lambda c: self._yards(place, c))
        far = max((seconds for seconds in ways.values()), default=0.0)
        return far, sorted(ways, key=ways.get), self._yards(place, end) * detour / speed, self.hub_of[(end.map, end.x, end.y)]

    def unplaced(self, qid: int) -> bool:
        """True when an objective of the quest has no position in the data: the planner works it where the quest is picked up, with no walk to it
        (`_index`, `_quest_rate`), and the guide says so in a .todo. Such a quest looks cheaper to finish than it is; the reports count them."""
        q = self.quests.get(qid)
        return q is not None and any(not o.spots for o in q.objectives)

    def _pickups(self, plan: Plan) -> dict[int, tuple]:
        """Where each quest of this route was picked up, the first time: {quest: (the character's level, the place, the hub's name, whether the route goes
        on to a hub where the quest is handed in)}."""
        found: dict[int, tuple] = {}
        path, st = [], plan.final
        while st is not None and st.visit is not None:
            path.append(st)
            st = st.parent
        path.reverse()
        for index, state in enumerate(path):
            for a in state.visit.actions:
                if a.kind == "accept" and a.quest not in found:
                    later = {s.visit.hub for s in path[index + 1 :] if s.visit.hub is not None}
                    found[a.quest] = (state.level, a.place, self.hubs[state.visit.hub].label if state.visit.hub is not None else "",
                                      bool(later & set(self.quests[a.quest].end_hubs)))
        return found

    def _finishable(self, plan: Plan, candidates: set) -> tuple[dict, dict]:
        """Tidy's completeness: of the quests this route left unfinished, the ones worth finishing and how. Returns ({visit index: {quests that
        must be picked up there even though they are forbidden}}, {visit index: [hubs to stop at after that visit]}). A quest qualifies when it
        could be worked at the level it was picked up at, pays at least `Settings.completeness` of the route's pace, and its objectives are at most
        `Settings.completeness_trip` seconds of walking from where it was picked up, and so is the place to hand it in unless the route goes on to a
        hub where it is handed in anyway. The stops are the hubs of its objectives (nearest first) and, unless the route passes the hand-in later,
        the hand-in's hub. A quest this route did finish (an earlier round of tidy) keeps its pick-up where it is."""
        s = self.s
        hubs = [v.hub for v in plan.visits]
        path, st = [], plan.final
        while st is not None and st.visit is not None:
            path.append(st)
            st = st.parent
        path.reverse()
        lifts: dict[int, set] = {}
        stops: dict[int, list] = {}
        for qid in sorted(candidates):
            q = self.quests[qid]
            picked = next((i for i, v in enumerate(plan.visits) if any(a.kind == "accept" and a.quest == qid for a in v.actions)), None)
            if picked is None:
                continue
            if qid in plan.final.done:
                lifts.setdefault(picked, set()).add(qid)
                continue
            level = path[picked].level
            if not self.soon(q, level) or (level >= s.cap and qid not in self.core) or self.finish_ratio(q, level) < s.completeness:
                continue
            place = next(a.place for a in plan.visits[picked].actions if a.kind == "accept" and a.quest == qid)
            far, objective_hubs, end_seconds, end_hub = self.trip(q, place)
            passes = bool({h for h in hubs[picked + 1 :] if h is not None} & set(q.end_hubs))  # the route goes on to a hub where it is handed in
            if far > s.completeness_trip or (end_seconds > s.completeness_trip and not passes):
                continue
            visiting = list(objective_hubs)
            if not passes and (not visiting or visiting[-1] != end_hub):
                visiting.append(end_hub)
            lifts.setdefault(picked, set()).add(qid)
            stops.setdefault(picked, []).extend(visiting)
        return lifts, stops

    def _after_cluster(self, plan: Plan, stops: dict) -> dict:
        """A completeness stop goes after the run of visits that follow the pick-up at hubs within `Settings.stop_yards` of it (the hand-ins and
        pick-ups of the stop the route is standing in), not right after the pick-up, which would leave a ready hand-in for a later trip."""
        moved: dict[int, list] = {}
        for index, hubs in stops.items():
            end = index
            while end + 1 < len(plan.visits):
                a, b = plan.visits[end].hub, plan.visits[end + 1].hub
                if a is None or b is None or self.hubs[a].map != self.hubs[b].map or self._yards(self.hubs[a].center, self.hubs[b].center) > self.s.stop_yards:
                    break
                end += 1
            moved.setdefault(end, []).extend(hubs)
        return moved

    def _left_out(self, qid: int, found: tuple | None, tried: bool) -> dict:
        """Why a quest the search picked up is not in the written route, with the numbers: the record `plan.stats["left_out"]` and the `#skipquest`
        line carry. `code` is one of price (its work is near but pays less than the route's pace asks), far (its objectives are beyond the trip the
        route walks), handin (the place to hand it in is), level (it could not be worked then), unfinished (a stop was added and it still was not
        finished)."""
        q, s = self.quests[qid], self.s
        picked_level, place, hub, passes = found if found else (None, q.start_places[0], "", False)
        level = max(1, picked_level or 1)
        far, _hubs, end_seconds, _end = self.trip(q, place)
        rate, pace = self._quest_rate(q, level), self.xp_pace(level)
        ratio = rate / max(pace, 1e-9)
        reach = s.completeness_trip
        work = sum(self.objective(qid, o.index, level)[0] for o in q.objectives)
        if tried:
            code, why = "unfinished", "a stop at its objectives was added and the route still did not finish it"
        elif not self.soon(q, level) or (level >= s.cap and qid not in self.core):
            code = "level"
            why = (f"it could not be worked at level {level} (a level {q.level} quest) and the route did not come back when it could"
                   if level < s.cap else "the route had reached the cap")
        elif far > reach:
            code, why = "far", f"its objectives are {far:.0f} s of walking away (the route walks up to {reach:.0f} s for one)"
        elif end_seconds > reach and not passes:
            code, why = "handin", f"it is handed in {end_seconds:.0f} s of walking away and the route does not pass there"
        else:
            code = "price"
            where = f"its work is {far:.0f} s away" if q.objectives else f"it is handed in {end_seconds:.0f} s away"
            asked = f"completeness is {s.completeness:.2f}" if s.completeness > 0 else f"completeness {ratio:.2f} or less would finish it"
            why = f"{where} and pays {rate:.2f} XP/s against the route's {pace:.2f} ({ratio:.0%}); {asked}"
        if self.unplaced(qid) and code != "unfinished":
            why += "; an objective of it has no position in the data, so the planner works it where the quest is picked up, with no walk"
        record = dict(
            quest=qid, name=q.name, level=q.level, picked_level=picked_level, hub=hub, code=code, why=why,
            trip=round(far, 1), handin=round(end_seconds, 1), work=round(work, 1), rate=round(rate, 3), pace=round(pace, 3), ratio=round(ratio, 3),
            unplaced=self.unplaced(qid),
        )
        return record

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
        self._ratio.clear()

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
        with the greedy route tidied too: the result is never slower than that. Each grain's own best route as written (of its first
        `GRAIN_TRIES` different orders of zones) is a finalist too and is kept in `stats["grains"]` with what the grain did, so that the report
        can say how far apart the grains are: the least the best route found can be off by."""
        s = self.s
        base = self._finish(self.rollout(self.start(start_hub)))
        self.calibrate(base)
        known = base.final.total if base.complete else float("inf")
        runs = []
        for parts in s.parts or (2,):
            started = time.perf_counter()
            run = self._layers(start_hub, max(1, parts), known, progress)
            run.seconds = time.perf_counter() - started
            runs.append(run)
        reference = self.tidy(base, start_hub)
        written: dict[int, Plan] = {}  # a finished route as it is written, found once

        def as_written(final: PState) -> Plan:
            if id(final) not in written:
                written[id(final)] = self.tidy(self._finish(final), start_hub)
            return written[id(final)]

        origin: dict[int, BeamRun] = {}
        tidied: list[Plan] = []
        seen: set = set()
        for final, run in sorted(((f, r) for r in runs for f in r.finished), key=lambda pair: pair[0].total):
            sig = self.signature(final)
            if sig in seen:
                continue
            seen.add(sig)
            candidate = as_written(final)
            origin[id(candidate)] = run
            tidied.append(candidate)
            if len(tidied) >= s.alternatives + 8:
                break
        for run in runs:  # each grain's own best route as it is written, so that the report can say how far apart the grains are
            signatures: set = set()
            for final in sorted(run.finished, key=lambda f: f.total):
                sig = self.signature(final)
                if sig in signatures:
                    continue
                signatures.add(sig)
                candidate = as_written(final)
                if candidate.complete and (run.best is None or candidate.total < run.best.total):
                    run.best = candidate
                if len(signatures) >= GRAIN_TRIES:
                    break
            if run.best is not None and not any(run.best is c for c in tidied):
                origin[id(run.best)] = run
                tidied.append(run.best)
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
            grains=[
                dict(parts=r.parts, finals=r.finals, seconds=r.seconds, total=r.best.total if r.best is not None else None) for r in runs
            ],
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
        for qid in sorted(self.mandatory - self.required):  # (a required quest is never skipped)
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
        for record in plan.stats.get("left_out", ()):  # nothing is dropped silently: what tidy took out is named, with its reason
            skips.setdefault(record["quest"], f"not finished by this route: {record['why']}")
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

    def grind_kills(self, level: int, target: int, xp: float) -> float:
        """The kills a grind from `level` to `target` that is worth `xp` experience comes to: at each level it climbs through, the kills of
        creatures of that level the model's kill experience says its experience bar takes (the character's first level is part-way up)."""
        model = self.model
        have = max(0.0, sum(model.to_next(n) for n in range(level, target)) - xp)  # already earned towards `level`
        kills = 0.0
        for n in range(level, target):
            each = model.kill_xp(n, n)
            if each > 0:
                kills += max(0.0, model.to_next(n) - have) / each
            have = 0.0
        return kills

    def grind_note(self, xp: float, kills: float) -> str:
        """What a grind step says about the size of the job: the experience still to grind and the kills it is, both rounded and both an
        estimate (the experience a player needs depends on rested experience, the quests in the log and the creatures at hand). It does not
        say "here": the grind follows the step before it, which may be in a town where nothing of the player's level lives."""
        count = max(1, approx(kills))
        return (
            f"Grind about {approx(xp):,} experience before you go on: about {count:,} {'kill' if count == 1 else 'kills'} "
            f"of creatures near your level (an estimate)"
        )

    def step_marks(self, hub: int, place: Coord | None) -> list:
        """Lines that mark the step written for a place of a hub, after its quest lines. The seam where a step in a town gets the `.hub <town>`
        line that profession tracks anchor on (a step with one is never joined with its neighbours): none yet."""
        return []

    def _grind_lines(self, target: int, xp: float, kills: float) -> list:
        return [f"  .level {target} -- reach it first: kill or grind on the way", f"  .note {self.grind_note(xp, kills)}"]

    def emit(self, plan: Plan, class_token: str) -> list:
        """The route as chapters of guide steps. It is written one place at a time (the places of a visit are steps of their own), then
        neighbouring steps of one kind are joined (signpost_tools/steps.py: a pick-up and hand-in step per area, a doing step per group of
        quests whose objectives are near each other), with a `.level` line before a quest above the last level asked for, `.optional` on
        group quests and `.note` where the rules have one. A grind (the route stops to kill for the level that opens quests) is a `.level N`
        line and a note saying how much experience that is, written on the step before it, where the character stands when it begins (one
        that comes first has no step before it and goes on the one after). Chapters are cut where the route goes to another zone for at
        least `Settings.chapter_min_steps` steps and are named after the zone most of their steps are in (`split_chapters`)."""
        pieces: list[Piece] = []
        gated = 0
        level = 1
        for v in plan.visits:
            if v.hub is None:  # a grind
                target = v.actions[0].index
                xp, kills = v.xp, self.grind_kills(level, target, v.xp)
                if pieces and pieces[-1].grind is not None:  # two in a row are one
                    before = pieces[-1]
                    target, xp, kills = max(target, before.grind[0]), xp + before.grind[1], kills + before.grind[2]
                    pieces.pop()
                    first_in = before.level_in
                else:
                    first_in = level
                pieces.append(Piece(self._grind_lines(target, xp, kills), None, first_in, v.level, (target, xp, kills)))
                gated = max(gated, target)
                level = v.level
                continue
            zone = self.hubs[v.hub].zone
            group: list[Action] = []
            for a in v.actions + [None]:
                if group and (a is None or a.place != group[0].place):
                    lines, gated = self._step(group, class_token, gated)
                    pieces.append(Piece(lines + self.step_marks(v.hub, group[0].place), zone, level, v.level))
                    group = []
                if a is not None:
                    group.append(a)
            level = v.level

        def near(a: Coord, b: Coord) -> bool:
            return a.map == b.map and self._yards(a, b) <= self.s.group_yards

        def objectives(qid: int) -> list[int] | None:
            return [o.index for o in self.quests[qid].objectives] if qid in self.quests else None

        joined: list[Piece] = []
        for lines, first, last in steps.group_spans([p.lines for p in pieces], near, objectives):
            head, tail = pieces[first], pieces[last]
            joined.append(Piece(lines, head.zone, head.level_in, tail.level_out, head.grind))
        placed: list[Piece] = []  # a grind is folded into the step before it (a lone `.level` step has no place of its own)
        carried: Piece | None = None
        for piece in joined:
            if piece.grind is None:
                if carried is not None:  # the route began with a grind: it goes on its first step, after the step's `.goto` lines
                    at = next((i for i, line in enumerate(piece.lines) if not steps.is_goto(line)), len(piece.lines))
                    piece.lines = piece.lines[:at] + carried.lines + piece.lines[at:]
                    piece.level_in = carried.level_in
                    carried = None
                placed.append(piece)
            elif placed:
                placed[-1].lines = placed[-1].lines + piece.lines
                placed[-1].level_out = piece.level_out
            else:
                carried = piece
        if carried is not None:  # nothing but grinds: the chapter that says so
            placed.append(carried)
        chapters: list[ChapterText] = []
        for first, last, zone in split_chapters([p.zone for p in placed], self.s.chapter_min_steps):
            chapter = ChapterText(zone, placed[first].level_in, placed[last].level_out)
            chapter.steps = [p.lines for p in placed[first : last + 1]]
            chapters.append(chapter)
        return chapters

    def _step(self, group: list, class_token: str, gated: int) -> tuple[list, int]:
        """The lines of the step for the actions of one place, and the highest level the route has asked for so far."""
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
                if q.group in GROUP_NOTES:
                    lines.append(f"  .note {name}: {GROUP_NOTES[q.group]}")
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
                if (objective is None or not objective.spots) and q.group != "dungeon":  # (a dungeon's objectives lie inside it: the note says so)
                    why = "is only in places this guide does not go" if objective is not None and objective.elsewhere else "has no position in the pack"
                    lines.append(f'  .todo "{name}: objective {a.index} {why}"')
                lines.append(f"  .complete {q.id},{a.index}{gate} -- {name}")
                if q.scripted:
                    lines.append(f"  .note {name}: {SCRIPTED_NOTES[(q.scripted, self.s.hardcore)]}")
            if q.optional:
                optional[q.id] = f"{GROUP_COMMENTS.get(q.group, 'group quest')}: {name}"
        for qid, comment in optional.items():
            lines.append(f"  .optional {qid} -- {comment}")
        return lines, gated


@dataclass
class Piece:
    """One step of the route as the planner writes it, before neighbours are joined: its lines, the zone of its first `.goto` (None for a grind,
    which has no place of its own), the level the character had when the visit it comes from began and when it ended, and for a grind what it
    asks: (the level to reach, the experience to grind, the kills that is)."""

    lines: list
    zone: int | None
    level_in: int
    level_out: int
    grind: tuple | None = None


@dataclass
class ChapterText:
    zone: int | None  # the zone most of its steps are in: its name
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


def approx(value: float) -> int:
    """A number rounded to two significant figures, as a person would say it (2,437 -> 2,400; 555 -> 560; 54.6 -> 55; 8.4 -> 8)."""
    whole = int(value + 0.5)
    if whole < 100:
        return whole
    step = 10 ** (len(str(whole)) - 2)
    return int(whole / step + 0.5) * step


def split_chapters(zones: list, min_steps: int) -> list[tuple[int, int, object]]:
    """Cut a route, given the zone of each of its steps in order, into chapters: [(first step, last step, zone it is named after)].

    A change of zone starts a new chapter only when the zone it goes to lasts at least `min_steps` steps in a row (counted once the steps are
    joined); a shorter stay is a detour and belongs to the chapter it happens in, so a chapter never ends a step or two after it started.
    The first chapter begins at the first step whatever it is (a short stay before the first long one goes into it); a return to the zone a
    chapter began in after a detour goes on with that chapter. Each chapter is named after the zone most of its steps are in (on a tie the one
    it began in, then the earliest)."""
    if not zones:
        return []
    runs: list[list] = []  # [zone, first step, last step] of every stay in one zone
    for index, zone in enumerate(zones):
        if runs and runs[-1][0] == zone:
            runs[-1][2] = index
        else:
            runs.append([zone, index, index])
    starts: list[tuple[int, object]] = []  # (first step, the zone it began in)
    for zone, first, last in runs:
        if last - first + 1 < max(1, min_steps):
            continue
        if not starts:
            starts.append((0, zone))
        elif zone != starts[-1][1]:
            starts.append((first, zone))
    if not starts:
        starts.append((0, zones[0]))  # every stay is short: one chapter
    chapters = []
    for number, (first, began) in enumerate(starts):
        last = starts[number + 1][0] - 1 if number + 1 < len(starts) else len(zones) - 1
        counts: dict = {}
        for zone in zones[first : last + 1]:
            counts[zone] = counts.get(zone, 0) + 1
        order = list(counts)  # the order of first appearance
        named = max(order, key=lambda z: (counts[z], z == began, -order.index(z)))
        chapters.append((first, last, named))
    return chapters


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
