"""Check Signpost's guides offline (PLAN §5, docs/GUIDE-FORMAT.md).

    python tools/guide_lint.py                 report errors, warnings and .todo steps (exit 0)
    python tools/guide_lint.py --strict        the same, but exit 1 on any error (CI; no guides at all is fine)
    python tools/guide_lint.py --guide horde-troll-hunter-1-60 --pack ../Signpost_Data
    python tools/guide_lint.py --skip-ids item      do not check item IDs against the pack (also quest, map, ...)

Every guide, chapter and track file is parsed the way Engine/Parser.lua parses it. Each guide is then checked for every
character it serves (faction, race, class and profession plan, as far as its gates tell them apart), on its own and
with each profession track merged in:
- IDs the data pack does not know: quests, items, maps, spells, recipes and flight nodes, for each table the pack has
  (in a step with .todo only a warning); profession keys against Professions/ and the tracks; gate tokens;
- quests accepted but never turned in, turned in without (or before) an accept, accepted or turned in twice,
  .complete outside the quest's accept..turn-in; quest level requirements against the level the route expects;
- chapter level ranges that go down; .todo steps (listed: they make a guide incomplete, not wrong);
- a quest the data pack gives objectives that is accepted and turned in with no .complete for them (and no .todo that
  names it): an error with none at all, a warning for some of them but not all (a generator dropped an objective);
- zone changes between steps without travel steps (PLAN §3.6; tools/guide_travel.py proposes them), and .fly to a
  flight path that no earlier .fp teaches;
- class-only directives in a chapter or track without a .class gate for that class;
- profession track steps that find no anchor in a guide (a `@level` anchor above the guide's highest chapter level is a note:
  the guide stops before it);
- class quests (classQuests in Classes/<CLASS>.lua and the pack's classes) and profession quests (the pack's
  professions) that are neither accepted and turned in nor #skipquest-ed, up to the guide's highest chapter level.
Without the data pack (as in CI) the checks that need it are skipped, and a note says which.
"""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import guide_sim  # noqa: E402
import guide_travel  # noqa: E402
from signpost_tools import availability, guidefile  # noqa: E402
from signpost_tools.guidefile import Directive, Problem, Route, RouteStep, Source, Step  # noqa: E402

REPO_ROOT = Path(__file__).resolve().parent.parent
SEVERITY_ORDER = {"error": 0, "warning": 1}
ID_KINDS = ("quest", "item", "map", "spell", "recipe", "node")  # what --skip-ids can switch off

Found = list[tuple[Problem, list[RouteStep]]]  # a route check's problems, each with the steps it involves


class Report:
    """Problems, deduplicated across a guide's variants (each remembers the variants it occurs in), and .todo steps."""

    def __init__(self) -> None:
        self.entries: dict[tuple, set[str]] = {}
        self.variants: dict[str, int] = {}
        self.todos: dict[tuple, str] = {}
        self.notes: list[str] = []

    def add(self, problem: Problem, guide: str | None = None, variant: str | None = None) -> None:
        key = (problem.severity, problem.code, problem.message, problem.path, problem.line, guide)
        labels = self.entries.setdefault(key, set())
        if variant:
            labels.add(variant)

    def count(self, severity: str) -> int:
        return sum(1 for key in self.entries if key[0] == severity)

    def codes(self, severity: str | None = None) -> list[str]:
        return sorted(key[1] for key in self.entries if severity in (None, key[0]))

    def render(self, quiet: bool = False) -> list[str]:
        def order(key: tuple) -> tuple:
            return key[3] or "", key[4] or 0, SEVERITY_ORDER[key[0]], key[1], key[2], key[5] or ""

        lines = []
        for key in sorted(self.entries, key=order):
            severity, code, message, path, line, guide = key
            if quiet and severity != "error":
                continue
            where = f"{path}:{line}" if path and line else path or "(project)"
            context = ""
            if guide:
                labels = self.entries[key]
                partial = bool(labels) and len(labels) < self.variants.get(guide, 1)
                context = f" (guide {guide}" + (f"; only for {'; '.join(sorted(labels))}" if partial else "") + ")"
            lines.append(f"{where}: {severity} [{code}] {message}{context}")
        if self.todos and not quiet:
            lines.append(f".todo steps ({len(self.todos)}):")
            for (path, line, _), reason in sorted(self.todos.items(), key=lambda item: (item[0][0], item[0][1] or 0)):
                lines.append(f"  {path}:{line}: {reason}")
        return lines


@dataclass
class Chain:
    name: str
    level: int | None
    quests: list[int]
    origin: str
    races: tuple[str, ...] | None = None  # raceFile tokens the chain is for; None = every race
    pending: bool = False  # a chain known to exist (Forever's own additions) whose quest IDs are not known yet


def _chains(value: object, origin: str) -> list[Chain]:
    """classQuests or a pack record's quests: { { id, name|n, level|l, quests = { ... } }, ... }, or a list of IDs."""
    if isinstance(value, dict):
        value = list(value.values())
    if not isinstance(value, list):
        return []
    if value and all(isinstance(item, int) for item in value):
        return [Chain(origin, None, list(value), origin)]
    chains = []
    for entry in value:
        if not isinstance(entry, dict):
            continue
        quests = entry.get("quests")
        quests = list(quests.values()) if isinstance(quests, dict) else quests
        quests = [quest for quest in quests or [] if isinstance(quest, int)]
        level = entry.get("level", entry.get("l"))
        name = entry.get("name") or entry.get("n") or entry.get("id") or "?"
        races = entry.get("races")
        races = list(races.values()) if isinstance(races, dict) else races
        races = tuple(r for r in races or [] if isinstance(r, str)) or None
        pending = entry.get("pending") is True
        chains.append(Chain(str(name), level if isinstance(level, int) else None, quests, origin, races, pending))
    return chains


def _quest(pack: guide_travel.Pack, quest_id: int) -> str:
    record = pack.table("quests").get(quest_id)
    name = record.get("n") if isinstance(record, dict) else None
    return f'quest {quest_id} "{name}"' if isinstance(name, str) else f"quest {quest_id}"


def _problem(severity: str, code: str, message: str, rs: RouteStep, line: int | None) -> Problem:
    return Problem(severity, code, message, rs.source.path, rs.source.file_line(line), rs.source.id)


def _where(rs: RouteStep, line: int | None) -> str:
    return f"{rs.source.path}:{rs.source.file_line(line)}"


# Checks on the files -------------------------------------------------------------------------------------------------


def ids_in(directive: Directive) -> list[tuple[str, int]]:
    """The (kind, ID) pairs a directive refers to."""
    args, name = directive.args, directive.name
    if name in ("accept", "turnin", "complete", "optional"):
        return [("quest", args["quest"])]
    if name == "reward":
        return [("quest", args["quest"])] + ([("item", args["item"])] if "item" in args else [])
    if name in ("buy", "collect", "use"):
        return [("item", args["item"])]
    if name in ("goto", "fish"):
        return [("map", args["coord"].map)]
    if name == "path":
        return [("map", point.map) for point in args["points"]]
    if name in ("boat", "zeppelin"):
        return [("map", args["from"].map), ("map", args["to"].map)]
    if name in ("zone", "fp"):
        return [("map", args["map"])]
    if name == "train" and "spell" in args:
        return [("spell", args["spell"])]
    if name == "craft":
        return [("recipe", args["spell"])]
    return []


def known_ids(pack: guide_travel.Pack) -> dict[str, set]:
    """The IDs the pack knows, per kind; a kind the pack has no records of is missing (and not checked)."""
    known: dict[str, set] = {}
    for kind, table in (("quest", "quests"), ("item", "items"), ("map", "maps")):
        if pack.has(table):
            known[kind] = set(pack.table(table))
    recipes: set = set()
    for record in pack.table("professions").values():
        if isinstance(record, dict) and isinstance(record.get("recipes"), dict):
            recipes.update(key for key in record["recipes"] if isinstance(key, int))
    spells: set = set()
    for record in pack.table("classes").values():
        by_level = record.get("spells") if isinstance(record, dict) else None
        for ids in by_level.values() if isinstance(by_level, dict) else by_level or []:
            spells.update(spell for spell in (ids if isinstance(ids, list) else [ids]) if isinstance(spell, int))
    if recipes:
        known["recipe"] = recipes
    if spells or recipes:
        known["spell"] = spells | recipes  # .train teaches class spells and trainer recipes
    return known


class FileChecks:
    """What can be checked without a guide: the language, IDs, keys, gate tokens, class gates, .todo."""

    def __init__(self, project: guidefile.Project, pack: guide_travel.Pack, report: Report, skip=()) -> None:
        self.project, self.report = project, report
        self.known = {kind: ids for kind, ids in known_ids(pack).items() if kind not in skip}
        self.professions = project.profession_keys() if project.professions else None
        self.classes = project.class_tokens()
        self.guide_of = {id(guide.source): guide for guide in project.guides.values()}

    def run(self) -> None:
        for problem in self.project.problems:
            self.report.add(problem)
        for source in self.project.sources():
            for problem in source.problems:
                self.report.add(problem)
            for header in source.headers("professions"):
                for key in header.value:
                    if self.professions is not None and key not in self.professions:
                        message = f"#professions {key}: no profession module or track has that key"
                        self.add(source, "error", "unknown-profession", message, header.line)
            for header in source.headers("skipquest"):
                quest = header.value["quest"]
                if "quest" in self.known and quest not in self.known["quest"]:
                    message = f"#skipquest {quest}: quest not in the data pack"
                    self.add(source, "error", "unknown-id", message, header.line)
            for step in source.steps():
                self.step(source, step)

    def add(self, source: Source, severity: str, code: str, message: str, line: int | None) -> None:
        self.report.add(source.problem(severity, code, message, line))

    def step(self, source: Source, step: Step) -> None:
        todo = any(d.name == "todo" for d in step.directives)
        for gate in step.gates + [gate for d in step.directives for gate in d.gates]:
            self.gate(source, gate)
        if step.anchor and step.anchor[0] == "zone" and step.anchor[1] not in self.known.get("map", (step.anchor[1],)):
            self.add(source, "error", "unknown-id", f"@zone {step.anchor[1]}: map not in the data pack", step.line)
        for line_directive in step.directives:
            for d in line_directive.walk():
                if d.name == "todo":
                    self.report.todos[(source.path, source.file_line(d.line), source.id)] = d.args["reason"]
                for kind, ident in ids_in(d):
                    if kind in self.known and ident not in self.known[kind]:
                        message = f".{d.name}: {kind} {ident} is not in the data pack"
                        if todo:
                            self.add(source, "warning", "unknown-id", message + " (the step is marked .todo)", d.line)
                        else:
                            self.add(source, "error", "unknown-id", message, d.line)
                key = d.args.get("key") if d.name in ("trainprof", "skill") else None
                if key and self.professions is not None and key not in self.professions:
                    message = f".{d.name} {key}: no profession module or track has that key"
                    self.add(source, "error", "unknown-profession", message, d.line)
                if d.spec is not None and d.spec.kind == "class":
                    self.class_gate(source, step, line_directive, d)

    def gate(self, source: Source, gate: guidefile.Gate) -> None:
        """Gate items the game cannot match (compared case-insensitively, as the in-game parser does)."""

        def known(item: str, tokens) -> bool:
            return item.lower() in {token.lower() for token in tokens}

        for item in gate.plain + gate.negated:
            if gate.kind == "class" and not known(item, self.classes):
                message = f".class {item}: not a class token ({', '.join(sorted(self.classes))})"
                self.add(source, "error", "gate", message, gate.line)
            elif gate.kind == "race" and not known(item, guidefile.CLIENT_RACES):
                message = f".race {item}: not a race the client has ({', '.join(guidefile.CLIENT_RACES)})"
                self.add(source, "warning", "gate", message, gate.line)
            elif gate.kind == "faction" and not known(item, guidefile.FACTIONS):
                self.add(source, "error", "gate", f".faction {item}: use {' or '.join(guidefile.FACTIONS)}", gate.line)
            elif gate.kind == "prof" and self.professions is not None and not known(item, self.professions):
                message = f".prof {item}: no profession module or track has that key"
                self.add(source, "error", "unknown-profession", message, gate.line)

    def class_gate(self, source: Source, step: Step, line_directive: Directive, d: Directive) -> None:
        """A class directive needs a .class gate (on its step or its line) that admits only its class."""
        admitted: set[str] | None = None
        for gate in step.gates + list(line_directive.gates):
            if gate.kind == "class" and gate.plain:
                plain = {item.upper() for item in gate.plain}
                admitted = plain if admitted is None else admitted & plain
        guide = self.guide_of.get(id(source))
        if guide is not None and "*" not in guide.classes:
            classes = {item.upper() for item in guide.classes}
            admitted = classes if admitted is None else admitted & classes
        owners = {owner.upper() for owner in d.spec.owners}
        if admitted is None or not admitted <= owners:
            where = {"chapter": "a chapter", "track": "a track"}.get(source.kind, "a guide for several classes")
            tokens = ",".join(sorted(owners))
            message = f".{d.name} is a {tokens} directive: in {where} it needs a .class {tokens} gate"
            self.add(source, "error", "class-directive", message, d.line)


# Checks on a route ---------------------------------------------------------------------------------------------------


def quest_flow(route: Route, pack: guide_travel.Pack) -> Found:
    """Accept/turn-in balance, duplicates, and .complete while the quest is not in the log."""
    found: Found = []
    state: dict[int, tuple[str, RouteStep, int]] = {}  # quest -> (accepted | done | orphan, step, line)
    for rs in route.steps:
        for d in rs.all_directives():
            if d.name not in ("accept", "turnin", "complete"):
                continue
            quest = d.args["quest"]
            name = _quest(pack, quest)
            status, at, at_line = state.get(quest, (None, None, None))
            if d.name == "accept":
                if status == "accepted":
                    message = f"{name} is accepted again (already at {_where(at, at_line)})"
                    found.append((_problem("error", "duplicate-accept", message, rs, d.line), [rs, at]))
                elif status == "done":
                    message = f"{name} is accepted again after its turn-in at {_where(at, at_line)}"
                    found.append((_problem("error", "duplicate-accept", message, rs, d.line), [rs, at]))
                elif status == "orphan":
                    message = f"{name} is turned in before it is accepted (at {_where(rs, d.line)})"
                    found.append((_problem("error", "turnin-before-accept", message, at, at_line), [rs, at]))
                    state[quest] = ("done", at, at_line)
                else:
                    state[quest] = ("accepted", rs, d.line)
            elif d.name == "turnin":
                if status == "accepted":
                    state[quest] = ("done", rs, d.line)
                elif status in ("done", "orphan"):
                    message = f"{name} is turned in again (already at {_where(at, at_line)})"
                    found.append((_problem("error", "duplicate-turnin", message, rs, d.line), [rs, at]))
                else:
                    state[quest] = ("orphan", rs, d.line)
            elif status != "accepted":
                message = f".complete {quest}: {name} is not in the quest log here (accept it first)"
                found.append((_problem("error", "complete-outside", message, rs, d.line), [rs]))
    for quest, (status, rs, line) in state.items():
        if status == "accepted":
            message = f"{_quest(pack, quest)} is accepted but never turned in"
            found.append((_problem("error", "never-turned-in", message, rs, line), [rs]))
        elif status == "orphan":
            message = f"{_quest(pack, quest)} is turned in but never accepted"
            found.append((_problem("error", "never-accepted", message, rs, line), [rs]))
    return found


def availability_checks(route: Route, pack: guide_travel.Pack, world: guide_travel.World, skill_lines: dict | None = None) -> Found:
    """Every `.accept` against the rules the game applies (tools/signpost_tools/availability.py), at the level, the quest log
    and the turned-in quests the walk has by then: required level, prerequisites and chains, quests that close each other,
    quests of another race, class or faction. The level is tools/guide_sim.py's estimate; a `.level N` step is the guide's own
    guarantee, and a quest above the last one asked for is flagged even where the estimate says the character has it."""
    quests = pack.table("quests")
    if not quests:
        return []
    rules = availability.Rules(quests, guide_sim.character_of(route, skill_lines))
    result = guide_sim.run(route, world, guide_sim.make_model(pack), rules=rules)
    found: Found = []
    for violation in result.violations:
        reason = violation.reason
        if reason.code == "unknown":
            continue  # a quest the pack does not know is the unknown-id check's
        message = f"{_quest(pack, violation.quest)}: {reason.text}"
        found.append((_problem(reason.severity, f"quest-{reason.code}", message, violation.step, violation.line), [violation.step]))
    return found


def talk_to(record: dict, objective: dict) -> bool:
    """An objective the pack models as "talk to X": a kill or object objective on the very NPC or object that starts or ends
    the quest (QuestieDB's way of saying "speak with X"). The hand-in at that NPC is the whole of it: no `.complete` needed."""
    parties = {"kill": "npc", "object": "obj"}
    kind = parties.get(str(objective.get("k")))
    if kind is None or not isinstance(objective.get("id"), int):
        return False
    return any(
        objective["id"] in (entities.get(kind) or ()) for entities in (record.get("s") or {}, record.get("e") or {})
    )


def objective_checks(route: Route, pack: guide_travel.Pack) -> Found:
    """A quest the pack gives objectives that the route accepts and turns in with no `.complete` for them (and no `.todo` that
    marks it): the player gets a step that cannot be finished (an explore objective a generator dropped is the usual case) or
    free experience in the simulator. No `.complete` at all is an error; some of the objectives but not all, a warning (the
    numbers are the pack's own order, which the generators write: a hand-written guide may count as the quest log does).
    Exempt: a quest the pack gives no objective (a delivery, or a class quest whose `unknown_work` carries its own `.todo`) and
    one whose objectives are all "talk to" the NPC that starts or ends it."""
    quests = pack.table("quests")
    if not quests:
        return []
    accepted: dict[int, tuple[RouteStep, int | None]] = {}
    turned: set[int] = set()
    whole: set[int] = set()  # `.complete <quest>`: all of its objectives
    numbered: dict[int, set[int]] = {}  # `.complete <quest>,<n>`
    reasons: list[str] = []  # what the route's `.todo` lines say, lower case
    for rs in route.steps:
        for d in rs.all_directives():
            quest = d.args.get("quest")
            if d.name == "todo":
                reasons.append(str(d.args.get("reason", "")).lower())
            elif d.name == "accept":
                accepted.setdefault(quest, (rs, d.line))
            elif d.name == "turnin":
                turned.add(quest)
            elif d.name == "complete":
                if d.args["objective"] is None:
                    whole.add(quest)
                else:
                    numbered.setdefault(quest, set()).add(d.args["objective"])
    found: Found = []
    for quest, (rs, line) in accepted.items():
        record = quests.get(quest)
        if quest not in turned or quest in whole or not isinstance(record, dict):
            continue
        objectives = [o for o in record.get("o") or [] if isinstance(o, dict)]
        wanted = [number for number, o in enumerate(objectives, 1) if not talk_to(record, o)]
        if not wanted:
            continue  # no objectives, or all of them are "talk to"
        name = (record.get("n") or "").lower()
        if any(str(quest) in re.findall(r"\d+", text) or (name and name in text) for text in reasons):
            continue  # a `.todo` somewhere says what the quest asks
        kinds = ", ".join(str(objectives[number - 1].get("k")) for number in wanted)
        missing = [number for number in wanted if number not in numbered.get(quest, ())]
        if not missing:
            continue
        if len(missing) == len(wanted):
            message = (
                f"{_quest(pack, quest)} has objectives in the data pack ({kinds}) but the route accepts it and turns it in with no "
                f".complete for it: add .complete {quest}, or a .todo that says what it asks"
            )
            found.append((_problem("error", "missing-complete", message, rs, line), [rs]))
        else:
            left = ", ".join(f"{number} ({objectives[number - 1].get('k')})" for number in missing)
            message = (
                f"{_quest(pack, quest)} has {len(wanted)} objectives in the data pack ({kinds}) but the route has no .complete for "
                f"objective {left}: add .complete {quest},{missing[0]} (or .complete {quest} for all of them)"
            )
            found.append((_problem("warning", "partial-complete", message, rs, line), [rs]))
    return found


def chapter_order(route: Route) -> list[Problem]:
    """Chapter minimum levels never go down, and stay inside the guide's levels."""
    problems = []
    previous = None
    low, high = route.guide.levels
    for chapter in route.chapters:
        if chapter.first is None:
            continue
        source = chapter.source
        path = source.path if source else route.guide.path
        line = source.file_line(chapter.line) if source and chapter.line else route.guide.line
        levels = f"{chapter.levels[0]}-{chapter.levels[1]}"
        if previous is not None and chapter.levels[0] < previous.levels[0]:
            before = f"{previous.name} ({previous.levels[0]}-{previous.levels[1]})"
            message = f"chapter {chapter.name} ({levels}) follows {before}: chapter levels must not go down"
            problems.append(Problem("error", "chapter-order", message, path, line, source.id if source else None))
        if chapter.levels[0] < low or chapter.levels[1] > high:
            message = f"chapter {chapter.name} ({levels}) is outside the guide's levels {low}-{high}"
            problems.append(Problem("warning", "chapter-range", message, path, line, source.id if source else None))
        previous = chapter
    return problems


def travel_checks(route: Route, world: guide_travel.World) -> Found:
    """Uncovered zone changes (PLAN §3.6), .fly without .fp, and the simulation's other findings."""
    sim = guide_travel.simulate(route, world)
    found: Found = []
    for transition in sim.transitions:
        after, before = transition.after, transition.before
        message = (
            f"zone change from {world.label(transition.from_zone)} (step {before.id if before else '?'}) to "
            f"{world.label(transition.to_zone)} (step {after.id}) without travel steps between them; "
            f"python tools/guide_travel.py --guide {route.guide.id} proposes them"
        )
        involved = [after] + ([before] if before else [])
        found.append((_problem("error", "uncovered-transition", message, after, after.step.line), involved))
    for issue in sim.issues:
        found.append((_problem(issue.severity, issue.code, issue.message, issue.step, issue.line), [issue.step]))
    return found


def flight_node_names(route: Route, world: guide_travel.World) -> Found:
    """`.fp`/`.fly` names against the client's flight nodes (when the pack has the map dump's taxi lists)."""
    found: Found = []
    if not world.all_nodes:
        return found
    for rs in route.steps:
        for d in rs.all_directives():
            if d.name not in ("fp", "fly"):
                continue
            name = d.args["node"]
            usable = world.nodes_named(name)
            if not world.nodes_named(name, every_faction=True):
                message = f".{d.name} {name}: no flight node of that name in the data pack"
                found.append((_problem("error", "unknown-id", message, rs, d.line), [rs]))
            elif not usable:
                message = f".{d.name} {name}: that flight node is not available to {route.variant.faction}"
                found.append((_problem("error", "unknown-id", message, rs, d.line), [rs]))
            elif d.name == "fp":
                exact = [node for node in usable if node.exact]
                if exact and all(node.zone != world.zone(d.args["map"]) for node in exact):
                    where = world.label(exact[0].zone)
                    message = f".fp {d.args['map']},{name}: the data pack puts that flight master in {where}"
                    found.append((_problem("warning", "fp-zone", message, rs, d.line), [rs]))
    return found


def route_checks(route: Route, pack: guide_travel.Pack, world: guide_travel.World, skip=(), skill_lines=None) -> Found:
    found = quest_flow(route, pack) + availability_checks(route, pack, world, skill_lines) + travel_checks(route, world)
    found += objective_checks(route, pack)
    return found if "node" in skip else found + flight_node_names(route, world)


def class_chains(project: guidefile.Project, pack: guide_travel.Pack, cls: str, race: str | None = None) -> list[Chain]:
    """The class's quest chains; a chain that names races applies to a character of one of them only."""
    chains = []
    # guides may spell the class in any case (the in-game parser lowercases tokens); modules and the pack use the token
    module = next((m for token, m in project.classes.items() if token.lower() == cls.lower()), None)
    if module is not None:
        chains += _chains(module.quests, module.path)
    record = next((r for token, r in pack.table("classes").items() if str(token).lower() == cls.lower()), None)
    if isinstance(record, dict):
        chains += _chains(record.get("quests"), "data pack")
    if race and race != guidefile.OTHER:
        chains = [c for c in chains if c.races is None or race.lower() in {r.lower() for r in c.races}]
    return chains


def profession_chains(project: guidefile.Project, pack: guide_travel.Pack, key: str) -> list[Chain]:
    """The pack's profession quests for a key: matched by the module's skillLine, else by the profession's name."""
    module = project.professions.get(key)
    skill_line = module.skill_line if module else None
    chains = []
    for line, record in pack.table("professions").items():
        if not isinstance(record, dict):
            continue
        name = record.get("n") if isinstance(record.get("n"), str) else ""
        if line == skill_line or (skill_line is None and "".join(name.lower().split()) == key):
            chains += _chains(record.get("quests"), "data pack")
    return chains


def coverage(route: Route, pack: guide_travel.Pack, chains: list[Chain], what: str, code: str):
    """(problems, chains above): quests of the chains that the route neither accepts and turns in nor #skipquest-s.
    Chains above the route's highest chapter level are not required yet; only their number is returned."""
    accepted, turned = set(), set()
    for rs in route.steps:
        for d in rs.all_directives():
            if d.name == "accept":
                accepted.add(d.args["quest"])
            elif d.name == "turnin":
                turned.add(d.args["quest"])
    problems, above, top = [], 0, route.max_level()
    todos = " ".join(
        str(d.args.get("reason", "")).lower() for rs in route.steps for d in rs.all_directives() if d.name == "todo"
    )
    for chain in chains:
        if chain.level is not None and chain.level > top:
            above += 1
            continue
        if chain.pending:
            # Forever's own chains have no IDs yet: the guide must say where each belongs (a .todo naming it), or the quest is lost
            marked = chain.name.lower() in todos
            message = f"{what} chain {chain.name} (level {chain.level}, {chain.origin}) has no quest IDs yet"
            if marked:
                problems.append(Problem("warning", f"{code}-pending", message + " (a .todo marks it)", route.guide.path, route.guide.line))
            else:
                message += f": add a .todo step naming it to guide {route.guide.id}"
                problems.append(Problem("error", f"{code}-unmarked", message, route.guide.path, route.guide.line))
            continue
        for quest in chain.quests:
            missing = [label for label, done in (("accepted", accepted), ("turned in", turned)) if quest not in done]
            if missing and quest not in route.skip_quests:
                message = (
                    f"{what} {_quest(pack, quest)} (chain {chain.name}, {chain.origin}) is never "
                    f"{' or '.join(missing)}: route it or add #skipquest {quest} >> <reason>"
                )
                problems.append(Problem("error", code, message, route.guide.path, route.guide.line))
    for quest, (reason, source, line) in route.skip_quests.items():
        if quest in accepted and any(quest in chain.quests for chain in chains):
            message = f"#skipquest {quest} ({reason}), but the route accepts it"
            problems.append(source.problem("warning", "skipquest-routed", message, line))
    return problems, above


def lint_guide(
    project: guidefile.Project, pack: guide_travel.Pack, guide: guidefile.Guide, report: Report, world_for, skip=()
) -> None:
    """Every check that needs a guide, for each of its variants, on its own and with each track merged in."""
    expansion = guidefile.expand(project, guide)
    for problem in expansion.problems:
        report.add(problem, guide.id)
    variants = guidefile.variants(project, guide, expansion)
    report.variants[guide.id] = len(variants)
    skill_lines = {key: module.skill_line for key, module in project.professions.items() if module.skill_line}
    above = 0
    late: set[tuple[str, str]] = set()  # track steps anchored (@level) above the guide's highest chapter level
    for variant in variants:
        label = variant.label()
        world = world_for(variant.faction)
        route = guidefile.build_route(project, guide, variant, expansion)
        if not route.steps:
            problem = Problem("warning", "empty-guide", f"guide {guide.id} has no steps", guide.path, guide.line)
            report.add(problem, guide.id, label)
            continue
        for problem in chapter_order(route):
            report.add(problem, guide.id, label)
        for problem, _ in route_checks(route, pack, world, skip, skill_lines):
            report.add(problem, guide.id, label)
        chains = class_chains(project, pack, variant.cls, variant.race)
        problems, chains_above = coverage(route, pack, chains, "class", "class-quest")
        above = max(above, chains_above)
        for problem in problems:
            report.add(problem, guide.id, label)
        for key in sorted(project.tracks):
            track = project.tracks[key]
            merged, unmatched = guidefile.merge_tracks(project, route, [key], world.within)
            for _, step in unmatched:
                kind, value = step.anchor
                if kind == "level" and value > route.max_level():
                    late.add((key, step.id))  # the guide stops before that level: not required yet, as for class chains
                    continue
                message = f"track {key}: step {step.id} (@{kind} {value}) finds no anchor in guide {guide.id}"
                if kind == "zone" and not world.geo.maps:
                    message += " (without the data pack's map tree only the same map matches)"
                report.add(track.problem("error", "unmatched-anchor", message, step.line), guide.id, label)
            for problem, steps in route_checks(merged, pack, world, skip, skill_lines):
                if any(rs.track == key for rs in steps):
                    report.add(problem, guide.id, label)
            chains = profession_chains(project, pack, key)
            for problem in coverage(merged, pack, chains, key, "profession-quest")[0]:
                report.add(problem, guide.id, label)
    if above:
        note = f"guide {guide.id}: {above} class quest chain(s) above its highest chapter level are not required yet"
        report.notes.append(note)
    if late:
        note = f"guide {guide.id}: {len(late)} track step(s) anchored above its highest chapter level are not required yet"
        report.notes.append(note)


def lint(root: Path, pack_dir: Path | None, guide_ids=None, why_no_pack: str = "not found", skip=()):
    """Lint the checkout at root: (report, project, pack). `skip` names ID kinds not to check against the pack."""
    project = guidefile.load_project(root)
    pack = guide_travel.load_pack(pack_dir) if pack_dir else guide_travel.Pack(problems=[why_no_pack])
    report = Report()
    # a pack that exists but cannot be read must not pass as an empty one: every ID check would silently find nothing
    if pack_dir and pack.problems and (pack.present or (Path(pack_dir) / "_meta.lua").is_file()):
        for message in pack.problems:
            report.add(Problem("error", "pack-load", f"data pack: {message}"))
    for gid in sorted(set(guide_ids or ()) - set(project.guides)):
        report.add(Problem("error", "unknown-guide", f"--guide {gid}: no guide with that id (have: {', '.join(sorted(project.guides)) or 'none'})"))
    FileChecks(project, pack, report, skip).run()
    worlds: dict[str, guide_travel.World] = {}

    def world_for(faction: str) -> guide_travel.World:
        if faction not in worlds:
            worlds[faction] = guide_travel.World(pack, project.borders, faction)
        return worlds[faction]

    included: set[str] = set()
    for gid, guide in sorted(project.guides.items()):
        included.update(guidefile.expand(project, guide).included)
        if not guide_ids or gid in guide_ids:
            lint_guide(project, pack, guide, report, world_for, skip)
    for chapter_id, source in sorted(project.chapters.items()):
        if chapter_id not in included:
            message = f"chapter {chapter_id} is not included by any guide"
            report.add(Problem("warning", "unused-chapter", message, source.path, source.call_line, source.id))
    known = known_ids(pack)
    if pack.present:
        missing = [kind for kind in ("quest", "item", "map", "spell", "recipe") if kind not in known]
        if missing:
            report.notes.append(f"the data pack has no {', '.join(missing)} records yet: those IDs are not checked")
        if skip:
            report.notes.append(f"--skip-ids: {', '.join(skip)} IDs are not checked")
    else:
        skipped = "unknown IDs, quest levels, quests whose objectives never appear as a .complete, flight node names and the pack's quest chains"
        report.notes.append(f"no data pack: {skipped} are not checked")
    if not project.professions:
        report.notes.append("no profession modules in Professions/: profession keys are not checked")
    return report, project, pack


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--strict", action="store_true", help="exit 1 if there is any error")
    parser.add_argument("--guide", action="append", help="only lint this guide id (repeatable; all files are parsed)")
    parser.add_argument("--root", type=Path, default=REPO_ROOT, help="the Signpost checkout (default: this one)")
    parser.add_argument("--pack", type=Path, help="the data pack folder (default: ../Signpost_Data when present)")
    parser.add_argument("--no-pack", action="store_true", help="lint without the data pack, as CI does")
    parser.add_argument(
        "--skip-ids", action="append", default=[], choices=ID_KINDS, help="do not check this kind of ID against the pack"
    )
    parser.add_argument("--quiet", action="store_true", help="print only errors and the summary")
    options = parser.parse_args(argv)
    guide_travel.safe_stdout()

    pack_dir = None if options.no_pack else options.pack or guide_travel.default_pack_dir(options.root)
    why = "--no-pack" if options.no_pack else "none next to the checkout"
    report, project, pack = lint(options.root, pack_dir, options.guide, why, tuple(options.skip_ids))
    for line in report.render(options.quiet):
        print(line)
    for note in report.notes:
        print(f"note: {note}")
    errors, warnings = report.count("error"), report.count("warning")
    print(pack.describe())
    files = f"{len(project.guides)} guide(s), {len(project.chapters)} chapter(s), {len(project.tracks)} track(s)"
    print(f"guide_lint: {files}: {errors} error(s), {warnings} warning(s), {len(report.todos)} .todo")
    return 1 if options.strict and errors else 0


if __name__ == "__main__":
    sys.exit(main())
