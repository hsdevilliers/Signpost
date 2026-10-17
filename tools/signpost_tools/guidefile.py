"""Read Signpost's guide files offline and parse the guide language (docs/GUIDE-FORMAT.md) as Engine/Parser.lua does.

    project = load_project(repo_root)
    guide = project.guides["horde-troll-hunter-1-60"]
    expansion = expand(project, guide)                    # #include resolved, nothing gated yet
    for variant in variants(project, guide, expansion):    # every faction/race/class/profession plan it serves
        route = build_route(project, guide, variant, expansion)
        merged, unmatched = merge_tracks(project, route, ["skinning"])

Guide, chapter and track files register pure literals (GUIDE-FORMAT "Files"), read here with the SavedVariables literal
parser. Class modules (Classes/*.lua) and profession modules (Professions/*.lua) also hold functions, so only what the
tools need is taken from them: the class token and `classQuests`, the profession key, `skillLine` and `primary`, and
the names of the directives they register. Guides/Travel/*.lua is read for `ns.Travel:RegisterBorders`.

Like the in-game parser this never raises on guide text: each problem is recorded with its source and line, and the
offending line (or step) is skipped.
"""

from __future__ import annotations

import re
from collections import namedtuple
from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable, Iterable

from .savedvars import LuaParseError, _Parser

# The classes and races of the Forever client (docs/FOREVER-API-NOTES.md, beta 1.60.1.70450); class modules add theirs.
CLIENT_CLASSES = ("WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID")
CLIENT_RACES = ("Human", "Orc", "Dwarf", "NightElf", "Scourge", "Tauren", "Gnome", "Troll", "Skyborne")
FACTIONS = ("Horde", "Alliance")
GATES = ("class", "race", "faction", "prof", "hc")
# Directives that take the player from one zone to another (PLAN §3.6); `.fp` and `.hs` are travel directives too.
TRAVEL_MOVES = ("path", "zone", "fly", "boat", "zeppelin", "home")
# The race/class token of a variant that stands for "any other" when a guide serves "*".
OTHER = "*other*"
# `.reward <questID>,<n>`: n up to this is a choice index, above it an item ID.
REWARD_CHOICES = 10

HEADER_PLACES = {
    "professions": ("guide",),
    "guide": ("guide",),
    "author": ("guide",),
    "version": ("guide",),
    "class": ("guide",),
    "race": ("guide",),
    "faction": ("guide",),
    "include": ("guide", "chapter"),
    "chapter": ("guide", "chapter"),
    "skipquest": ("guide", "chapter"),
    "track": ("track",),
}
_PLACE_NAMES = {("guide",): "a guide", ("guide", "chapter"): "a guide or a chapter", ("track",): "a track file"}
# The headers ns.Parser:Headers reads (a guide's own text only; the first of each kind counts).
GUIDE_HEADERS = ("professions", "guide", "author", "version", "class", "race", "faction")

__all__ = [
    "ArgError",
    "Chapter",
    "ClassModule",
    "Coord",
    "Directive",
    "Expansion",
    "Gate",
    "Guide",
    "Header",
    "Problem",
    "ProfessionModule",
    "Project",
    "Route",
    "RouteStep",
    "Source",
    "Spec",
    "Step",
    "Variant",
    "build_route",
    "expand",
    "find_register_calls",
    "fmt_number",
    "load_project",
    "merge_tracks",
    "parse_coord",
    "parse_source",
    "registry",
    "track_steps",
    "variants",
]


# Data shapes ---------------------------------------------------------------------------------------------------------


@dataclass(frozen=True)
class Problem:
    severity: str  # "error" or "warning"
    code: str
    message: str
    path: str | None = None  # the file, relative to the project root
    line: int | None = None  # the line in that file
    source: str | None = None  # guide id, chapter id or track:<key>


def fmt_number(value: float) -> str:
    """A coordinate as guides write it: one or two decimals (52.0, 52.15)."""
    text = f"{value:.2f}"
    return text[:-1] if text.endswith("0") else text


@dataclass(frozen=True)
class Coord:
    map: int
    x: float
    y: float

    def dsl(self) -> str:
        return f"{self.map},{fmt_number(self.x)},{fmt_number(self.y)}"


@dataclass(frozen=True)
class Variant:
    """One kind of character a guide serves: gates are resolved against it, and `.prof` against its plan."""

    faction: str
    race: str
    cls: str
    plan: frozenset = frozenset()

    def label(self) -> str:
        race = "other race" if self.race == OTHER else self.race
        cls = "other class" if self.cls == OTHER else self.cls
        plan = ",".join(sorted(self.plan)) if self.plan else "no professions"
        return f"{self.faction} {race} {cls}, {plan}"

    def with_plan(self, keys: Iterable[str]) -> Variant:
        return Variant(self.faction, self.race, self.cls, self.plan | frozenset(keys))


@dataclass(frozen=True)
class Gate:
    kind: str  # class, race, faction, prof, hc
    items: tuple[str, ...]
    line: int

    @property
    def plain(self) -> tuple[str, ...]:
        return tuple(item for item in self.items if not item.startswith("!"))

    @property
    def negated(self) -> tuple[str, ...]:
        return tuple(item[1:] for item in self.items if item.startswith("!"))

    def passes(self, variant: Variant) -> bool:
        """GUIDE-FORMAT "Gates": any plain item matches, no negated item matches; .hc is always false for now.
        Items compare case-insensitively, as in Engine/Parser.lua."""
        if self.kind == "hc":
            return False
        if self.kind == "prof":
            values = {key.lower() for key in variant.plan}
        else:
            values = {{"class": variant.cls, "race": variant.race, "faction": variant.faction}[self.kind].lower()}
        if any(item.lower() in values for item in self.negated):
            return False
        plain = self.plain
        return any(item.lower() in values for item in plain) if plain else True


@dataclass
class Spec:
    """A directive the parser knows: core (GUIDE-FORMAT), travel, or one a class/profession module registers."""

    name: str
    parse: Callable[[str], dict]
    completable: bool = True
    kind: str = "misc"  # quest, travel, profession, misc; "class" or "profession" for a module's directive
    owners: tuple[str, ...] = ()  # the class tokens or profession keys whose modules register it


@dataclass
class Directive:
    name: str
    args: dict
    raw: str  # the argument text (after `>>` text and trailing gates are taken off)
    text: str | None  # the `>> text` override
    line: int
    gates: tuple[Gate, ...] = ()  # trailing gates: they filter this line only
    inner: Directive | None = None  # the directive inside `.sticky`
    spec: Spec | None = None

    def walk(self) -> Iterable[Directive]:
        """This directive, then the one inside it (for `.sticky`)."""
        yield self
        if self.inner is not None:
            yield self.inner


@dataclass
class Header:
    kind: str
    value: object
    line: int


@dataclass
class Step:
    source: str
    n: int  # position in its source text before gating: the stable step id is "<source>:<n>"
    line: int
    end_line: int
    anchor: tuple[str, object] | None = None  # track steps: ("hub", name) | ("level", n) | ("zone", uiMapID)
    gates: list[Gate] = field(default_factory=list)  # gate lines: they gate the whole step
    directives: list[Directive] = field(default_factory=list)  # every directive line that parsed, in line order
    invalid: bool = False  # a wrong anchor or gate line: the step is dropped
    content: int = 0  # directive lines other than gates and modifiers, parsed or not

    @property
    def id(self) -> str:
        return f"{self.source}:{self.n}"


@dataclass
class Source:
    """One registered text: a guide's `text`, a chapter or a profession track."""

    kind: str  # guide, chapter, track
    id: str  # guide id, chapter id or track:<key> (the step id prefix)
    key: str  # guide id, chapter id or profession key
    text: str
    path: str  # the file, relative to the project root
    first_line: int  # the file line of the text's first line
    call_line: int = 0  # the file line of the Register call
    items: list = field(default_factory=list)  # Header and Step, in text order
    problems: list[Problem] = field(default_factory=list)

    def file_line(self, line: int | None) -> int | None:
        return None if line is None else self.first_line + line - 1

    def problem(self, severity: str, code: str, message: str, line: int | None = None) -> Problem:
        return Problem(severity, code, message, self.path, self.file_line(line), self.id)

    def steps(self) -> list[Step]:
        return [item for item in self.items if isinstance(item, Step)]

    def headers(self, kind: str) -> list[Header]:
        return [item for item in self.items if isinstance(item, Header) and item.kind == kind]


@dataclass
class Guide:
    id: str
    name: str
    faction: str
    races: tuple[str, ...]
    classes: tuple[str, ...]
    levels: tuple[int, int]
    source: Source
    path: str
    line: int  # the file line of the Register call
    headers: dict = field(default_factory=dict)

    @property
    def professions(self) -> list[str]:
        return list(self.headers.get("professions") or [])


@dataclass
class ClassModule:
    token: str
    path: str
    quests: object = None  # classQuests as written, or None
    directives: list[str] = field(default_factory=list)


@dataclass
class ProfessionModule:
    key: str
    path: str
    skill_line: int | None = None
    primary: bool | None = None
    directives: list[str] = field(default_factory=list)


@dataclass
class Project:
    root: Path
    guides: dict[str, Guide] = field(default_factory=dict)
    chapters: dict[str, Source] = field(default_factory=dict)
    tracks: dict[str, Source] = field(default_factory=dict)
    classes: dict[str, ClassModule] = field(default_factory=dict)
    professions: dict[str, ProfessionModule] = field(default_factory=dict)
    borders: list = field(default_factory=list)  # (path, line, entry) from ns.Travel:RegisterBorders
    specs: dict[str, Spec] = field(default_factory=dict)
    problems: list[Problem] = field(default_factory=list)

    def sources(self) -> list[Source]:
        guides = [guide.source for guide in self.guides.values()]
        return guides + list(self.chapters.values()) + list(self.tracks.values())

    def class_tokens(self) -> set[str]:
        return set(CLIENT_CLASSES) | set(self.classes)

    def profession_keys(self) -> set[str]:
        return set(self.professions) | set(self.tracks)


# Directive arguments -------------------------------------------------------------------------------------------------


class ArgError(ValueError):
    pass


_WHOLE = re.compile(r"\d+")
_NUMBER = re.compile(r"-?(?:\d+(?:\.\d*)?|\.\d+)")
_KEY = re.compile(r"[a-z][a-z0-9]*")


def _whole(text: str, what: str) -> int:
    text = text.strip()
    if not text:
        raise ArgError(f"{what} is missing")
    if not _WHOLE.fullmatch(text) or int(text) <= 0:
        raise ArgError(f"{what} must be a positive whole number, not {text!r}")
    return int(text)


def _number(text: str, what: str) -> float:
    text = text.strip()
    if not _NUMBER.fullmatch(text):
        raise ArgError(f"{what} must be a number, not {text!r}")
    return float(text)


def _percent(text: str, axis: str) -> float:
    value = _number(text, axis)
    if not 0 <= value <= 100:
        raise ArgError(f"{axis} {text.strip()} is outside 0-100 (percent of the map)")
    return value


def _split(text: str, sep: str) -> list[str]:
    return [part.strip() for part in text.split(sep)]


def parse_coord(text: str) -> Coord:
    """`<map>,<x>,<y>` as directives write it. Raises ArgError."""
    parts = _split(text, ",")
    if len(parts) != 3:
        raise ArgError(f"expected <map>,<x>,<y>, not {text.strip()!r}")
    return Coord(_whole(parts[0], "the map ID"), _percent(parts[1], "x"), _percent(parts[2], "y"))


_coord = parse_coord


def _ids(args: str, names: tuple[str, ...], optional: int = 0) -> list[int]:
    parts = _split(args, ",") if args.strip() else []
    if not len(names) - optional <= len(parts) <= len(names):
        usage = ",".join(f"<{name}>" if i < len(names) - optional else f"[<{name}>]" for i, name in enumerate(names))
        raise ArgError(f"expected {usage}")
    return [_whole(part, f"the {name}") for part, name in zip(parts, names)]


def _key(text: str, what: str = "profession key") -> str:
    text = text.strip()
    if not _KEY.fullmatch(text):
        raise ArgError(f"expected a {what} (lowercase letters and digits, e.g. firstaid), not {text!r}")
    return text


def _text(args: str, what: str = "text") -> str:
    if not args.strip():
        raise ArgError(f"the {what} is missing")
    return args.strip()


def _none(args: str) -> dict:
    if args.strip():
        raise ArgError("takes no arguments")
    return {}


def _p_goto(args: str) -> dict:
    parts = _split(args, ",")
    if len(parts) not in (3, 4):
        raise ArgError("expected <map>,<x>,<y>[,<radius>]")
    result: dict[str, object] = {"coord": _coord(",".join(parts[:3]))}
    if len(parts) == 4:
        radius = _number(parts[3], "the radius")
        if radius <= 0:
            raise ArgError("the radius must be more than 0 yards")
        result["radius"] = radius
    return result


def _p_complete(args: str) -> dict:
    ids = _ids(args, ("questID", "objective"), optional=1)
    return {"quest": ids[0], "objective": ids[1] if len(ids) > 1 else None}


def _p_reward(args: str) -> dict:
    quest, pick = _ids(args, ("questID", "choice or itemID"))
    return {"quest": quest, "choice": pick} if pick <= REWARD_CHOICES else {"quest": quest, "item": pick}


def _p_train(args: str) -> dict:
    return {"class": True} if args.strip() == "class" else {"spell": _ids(args, ("spellID",))[0]}


def _p_skill(args: str) -> dict:
    match = re.fullmatch(r"(\S+)\s+(\S+)", args.strip())
    if not match:
        raise ArgError("expected <key> <N> (a space between them, e.g. .skill cooking 75)")
    return {"key": _key(match.group(1)), "level": _whole(match.group(2), "the skill level")}


def _p_count(what: str) -> Callable[[str], dict]:
    def parse(args: str) -> dict:
        ident, count = _ids(args, (what, "count"))
        return {"spell" if what == "spellID" else "item": ident, "count": count}

    return parse


def _p_todo(args: str) -> dict:
    """`.todo "<reason>"`; like the in-game parser, a reason without quotes is taken too (the lint warns)."""
    text = args.strip()
    match = re.fullmatch(r'"(.*)"', text, re.S)
    reason = (match.group(1) if match else text).strip()
    if not reason:
        raise ArgError('expected .todo "<reason>"')
    return {"reason": reason, "quoted": bool(match)}


def _p_link(args: str) -> dict:
    url = _text(args, "URL")
    if re.search(r"\s", url):
        raise ArgError(f"a URL has no spaces: {url!r}")
    return {"url": url}


def _p_hub(args: str) -> dict:
    name = _text(args, "hub name")
    if re.search(r"\s", name):
        raise ArgError(f"a hub name is one word, e.g. razorhill: {name!r}")
    return {"name": name}


def _p_path(args: str) -> dict:
    if not args.strip():
        raise ArgError("expected <map>,<x>,<y> ; <map>,<x>,<y> ; ...")
    return {"points": [_coord(point) for point in args.split(";")]}


def _p_fp(args: str) -> dict:
    map_text, sep, node = args.partition(",")
    if not sep or not node.strip():
        raise ArgError("expected <map>,<node name>")
    return {"map": _whole(map_text, "the map ID"), "node": node.strip()}


def _p_transport(args: str) -> dict:
    parts = args.split(">")
    if len(parts) != 2:
        raise ArgError("expected <map>,<x>,<y> > <map>,<x>,<y> (departure > arrival)")
    return {"from": _coord(parts[0]), "to": _coord(parts[1])}


def _p_module(args: str) -> dict:
    return {"raw": args.strip()}


def _spec(name: str, parse: Callable[[str], dict], completable: bool = True, kind: str = "misc") -> Spec:
    return Spec(name, parse, completable, kind)


CORE_SPECS = [
    _spec("goto", _p_goto),
    _spec("accept", lambda a: {"quest": _ids(a, ("questID",))[0]}, kind="quest"),
    _spec("turnin", lambda a: {"quest": _ids(a, ("questID",))[0]}, kind="quest"),
    _spec("complete", _p_complete, kind="quest"),
    _spec("optional", lambda a: {"quest": _ids(a, ("questID",))[0]}, False, "quest"),
    _spec("reward", _p_reward, False, "quest"),
    _spec("train", _p_train, kind="profession"),
    _spec("trainprof", lambda a: {"key": _key(a)}, kind="profession"),
    _spec("skill", _p_skill, kind="profession"),
    _spec("craft", _p_count("spellID"), kind="profession"),
    _spec("fish", lambda a: {"coord": _coord(a)}, False, "profession"),
    _spec("buy", _p_count("itemID")),
    _spec("collect", _p_count("itemID")),
    _spec("use", lambda a: {"item": _ids(a, ("itemID",))[0]}, False),
    _spec("level", lambda a: {"level": _ids(a, ("N",))[0]}),
    # `.todo` is never satisfied: the step waits for the player's `>` (Phase 2 acceptance: "except at .todo steps").
    _spec("todo", _p_todo),
    _spec("note", lambda a: {"text": _text(a)}, False),
    _spec("text", lambda a: {"text": _text(a)}, False),
    _spec("link", _p_link, False),
    _spec("sticky", lambda a: {}, False),  # parsed by parse_directive_line
    _spec("hub", _p_hub, False),
]
TRAVEL_SPECS = [
    _spec("path", _p_path, kind="travel"),
    _spec("zone", lambda a: {"map": _ids(a, ("uiMapID",))[0]}, kind="travel"),
    _spec("fp", _p_fp, kind="travel"),
    _spec("fly", lambda a: {"node": _text(a, "node name")}, kind="travel"),
    _spec("boat", _p_transport, kind="travel"),
    _spec("zeppelin", _p_transport, kind="travel"),
    _spec("hs", lambda a: {"inn": _text(a, "inn name")}, kind="travel"),
    _spec("home", _none, kind="travel"),
]


def registry(classes: Iterable[ClassModule] = (), professions: Iterable[ProfessionModule] = ()) -> dict[str, Spec]:
    """Every directive the in-game parser knows: core, travel, and the class and profession modules' own."""
    specs = {spec.name: spec for spec in CORE_SPECS + TRAVEL_SPECS}
    for kind, modules in (("class", classes), ("profession", professions)):
        for module in modules:
            owner = module.token if kind == "class" else module.key
            for name in module.directives:
                spec = specs.get(name)
                if spec is None and name not in GATES:
                    specs[name] = Spec(name, _p_module, True, kind, (owner,))
                elif spec is not None and spec.kind == kind and owner not in spec.owners:
                    spec.owners += (owner,)
    return specs


# Lines ---------------------------------------------------------------------------------------------------------------

_COMMENT = re.compile(r"\s--")
_HEADER = re.compile(r"#(\S*)\s*(.*)")
_STEP = re.compile(r"step(?:\s+(.*))?")
_DIRECTIVE = re.compile(r"\.([A-Za-z][A-Za-z0-9_]*)(.*)", re.S)
_ANCHOR = re.compile(r"@([A-Za-z]+)\s+(\S+)\s*(.*)")
_GATE_TAIL = re.compile(r"(.*?)\s+\.([A-Za-z]+)\s+(\S+)", re.S)
_HC_TAIL = re.compile(r"(.*?)\s+\.hc", re.S)
_GATE_NAME = re.compile(r"\s\.([A-Za-z]+)")
_GATE_LIST = re.compile(r"!?[A-Za-z0-9_]+(?:,!?[A-Za-z0-9_]+)*")
_CHAPTER = re.compile(r"(\S+)\s+(.+)")
_LEVELS = re.compile(r"(\d+)(?:-(\d+))?")
_CHAPTER_ID = re.compile(r"[a-z0-9-]+")
_SKIPQUEST = re.compile(r"(\d+)\s*>>\s*(.*)", re.S)
# Step modifiers: `.optional` and `.hub` mark the step; they are not content of their own.
MODIFIERS = ("optional", "hub")


def strip_comment(line: str) -> str:
    """GUIDE-FORMAT "Lines": `--` at the start of a line, or whitespace then `--` anywhere, starts a comment."""
    if line.lstrip().startswith("--"):
        return ""
    match = _COMMENT.search(line)
    return (line[: match.start()] if match else line).strip()


def parse_gate(kind: str, items: str, line: int) -> Gate:
    if kind == "hc":
        if items:
            raise ArgError(".hc takes no list")
        return Gate("hc", (), line)
    if not items:
        raise ArgError(f".{kind} needs a list, e.g. .{kind} {'HUNTER' if kind == 'class' else 'a,!b'}")
    if not _GATE_LIST.fullmatch(items):
        raise ArgError(f"a gate list is comma-separated without spaces (items may start with !), not {items!r}")
    return Gate(kind, tuple(items.split(",")), line)


def _take_gates(text: str, gates: list[Gate], line: int) -> str:
    """The gates at the end of `text` (" .class a,!b", " .hc") go into `gates`, in line order; returns the rest."""
    found = []
    while True:
        match = _GATE_TAIL.fullmatch(text)
        if match and match.group(2) in GATES:
            rest, kind, items = match.groups()
        else:
            match = _HC_TAIL.fullmatch(text)
            if not match:
                break
            rest, kind, items = match.group(1), "hc", ""
        found.append(parse_gate(kind, items, line))
        text = rest
    gates.extend(reversed(found))
    return text


def split_line(rest: str, line: int) -> tuple[str, str | None, list[Gate]]:
    """What follows a directive's name: (arguments, `>> text` or None, trailing gates). A trailing gate stands right
    before the `>>` or at the very end of the line; one anywhere else is an error. Raises ArgError."""
    head, sep, text = rest.partition(">>")
    gates: list[Gate] = []
    head = _take_gates(" " + head.strip(), gates, line)
    override = None
    if sep:
        override = _take_gates(" " + text.strip(), gates, line).strip()
        if not override:
            raise ArgError("nothing after >>")
    for name in _GATE_NAME.findall(head):
        if name in GATES:
            raise ArgError(f"misplaced or malformed gate .{name}")
    return head.strip(), override, gates


def parse_directive_line(line: str, number: int, specs: dict[str, Spec]) -> Directive | list[Gate]:
    """One `.name args [>> text]` line: a gate line (its gates), or a directive with its trailing gates."""
    match = _DIRECTIVE.fullmatch(line)
    if not match:
        raise ArgError("malformed directive line")
    name, rest = match.group(1), match.group(2)
    if rest and not rest[0].isspace():
        raise ArgError(f"expected a space after .{name}")
    if name == "sticky":
        inner = re.match(r"\s*\.([A-Za-z]+)", rest)
        if inner and inner.group(1) in GATES:
            raise ArgError(f".{inner.group(1)} cannot be sticky")
    args, override, gates = split_line(rest, number)
    if name in GATES:
        if override is not None:
            raise ArgError(f">> text is not allowed on .{name}")
        return [parse_gate(name, args, number), *gates]
    if name in MODIFIERS and override is not None:
        raise ArgError(f">> text is not allowed on .{name}")
    spec = specs.get(name)
    if spec is None:
        raise ArgError(f"unknown directive .{name}")
    if name == "sticky":
        inner = _DIRECTIVE.fullmatch(args)
        if not inner:
            raise ArgError(".sticky needs a directive: .sticky .<name> <arguments>")
        inner_name, inner_rest = inner.group(1), inner.group(2)
        if inner_name in ("sticky", *MODIFIERS):
            raise ArgError(f".{inner_name} cannot be sticky")
        if inner_rest and not inner_rest[0].isspace():
            raise ArgError(f"expected a space after .{inner_name}")
        inner_spec = specs.get(inner_name)
        if inner_spec is None:
            raise ArgError(f"unknown directive .{inner_name}")
        if not inner_spec.completable:
            raise ArgError(f".sticky needs a directive that can be satisfied, not .{inner_name}")
        try:
            inner_args = inner_spec.parse(inner_rest.strip())
        except ArgError as exc:
            raise ArgError(f".{inner_name}: {exc}") from None
        held = Directive(inner_name, inner_args, inner_rest.strip(), None, number, (), None, inner_spec)
        return Directive(name, {"inner": inner_name}, args, override, number, tuple(gates), held, spec)
    try:
        parsed = spec.parse(args)
    except ArgError as exc:
        raise ArgError(f".{name}: {exc}") from None
    return Directive(name, parsed, args, override, number, tuple(gates), None, spec)


def _header(source: Source, name: str, rest: str, number: int) -> Header:
    """One `#name ...` statement. Raises ArgError."""
    places = HEADER_PLACES.get(name)
    if places is None:
        raise ArgError(f"unknown header #{name}")
    if source.kind not in places:
        raise ArgError(f"#{name} belongs in {_PLACE_NAMES[places]}, not in a {source.kind}")
    if name in ("professions", "class", "race"):
        items = _split(rest, ",") if rest else []
        if not items or not all(items) or any(re.search(r"\s", item) for item in items):
            raise ArgError(f"expected #{name} <item>,<item>,... (comma-separated, no spaces)")
        if name == "professions":
            items = [_key(item) for item in items]
        return Header(name, items, number)
    if name in ("guide", "author", "version", "faction"):
        if not rest:
            raise ArgError(f"#{name} needs a value")
        return Header(name, rest, number)
    if name == "include":
        if not _CHAPTER_ID.fullmatch(rest):
            raise ArgError(f"expected #include <chapterId> (lowercase letters, digits and -), not {rest!r}")
        return Header(name, rest, number)
    if name == "chapter":
        match = _CHAPTER.fullmatch(rest)
        title, dungeon = (match.group(2), False) if match else (None, False)
        if title is not None and re.search(r"\s#dungeon$", title):
            title, dungeon = re.sub(r"\s+#dungeon$", "", title), True
        if title is None or title == "#dungeon":
            raise ArgError("expected #chapter <N or N-M> <name> [#dungeon]")
        levels = _LEVELS.fullmatch(match.group(1))
        low = int(levels.group(1)) if levels else 0
        high = int(levels.group(2)) if levels and levels.group(2) else low
        if low < 1 or high < low:
            raise ArgError("chapter levels must be N or N-M with 1 <= N <= M")
        return Header(name, {"levels": (low, high), "name": title.strip(), "dungeon": dungeon}, number)
    if name == "skipquest":
        match = _SKIPQUEST.fullmatch(rest)
        if not match or int(match.group(1)) < 1 or not match.group(2).strip():
            raise ArgError("expected #skipquest <questID> >> <reason> (the reason is required)")
        return Header(name, {"quest": int(match.group(1)), "reason": match.group(2).strip()}, number)
    # track
    return Header(name, _key(rest), number)


def parse_source(source: Source, specs: dict[str, Spec]) -> None:
    """Parse one registered text into headers and steps, recording problems (GUIDE-FORMAT "Errors")."""
    source.items, source.problems = [], []

    def add(severity: str, code: str, message: str, line: int) -> None:
        source.problems.append(source.problem(severity, code, message, line))

    current: Step | None = None
    count = statements = 0
    first_header: dict[str, int] = {}
    for number, raw in enumerate(source.text.split("\n"), 1):
        line = strip_comment(raw)
        if not line:
            continue
        statements += 1
        if source.kind == "track" and statements == 1 and not re.match(r"#track(\s|$)", line):
            add("error", "track-header", f"a track starts with #track {source.key}", number)
        try:
            step_line = _STEP.fullmatch(line)
            if line.startswith("."):
                if current is None:
                    raise ArgError("a directive line outside a step (it needs a `step` line before it)")
                _directive_line(source, current, line, number, specs, add)
            elif line.startswith("#"):
                name, rest = _HEADER.fullmatch(line).groups()
                if name in ("chapter", "include") and source.kind != "track":
                    current = None  # #chapter and #include end the step; other headers do not
                header = _header(source, name, rest.strip(), number)
                if header.kind == "track" and statements != 1:
                    raise ArgError("#track must be the first statement of a track")
                if header.kind == "track" and header.value != source.key:
                    message = f"#track {header.value} does not match the track key {source.key}"
                    add("error", "track-header", message, number)
                if header.kind in GUIDE_HEADERS:
                    if header.kind in first_header:
                        raise ArgError(f"duplicate #{header.kind} (first on line {first_header[header.kind]})")
                    first_header[header.kind] = number
                source.items.append(header)
            elif step_line:
                count += 1  # every step line counts, so fixing a broken one keeps the ids after it
                current = Step(source.id, count, number, number)
                source.items.append(current)
                _step_line(source, current, (step_line.group(1) or "").strip())
            else:
                raise ArgError(f"not a step, directive or header: {line!r}")
        except ArgError as exc:
            add("error", "parse", str(exc), number)
    if source.kind == "track" and statements == 0:
        add("error", "track-header", f"a track starts with #track {source.key}", None)
    for step in source.steps():
        if step.invalid:
            continue
        if step.content == 0:
            add("error", "empty-step", "step has no directives", step.line)
        elif not any(d.name in ("note", "sticky") or (d.spec and d.spec.completable) for d in step.directives):
            message = "a step with no completable directive and no .note completes only by the player's >"
            add("warning", "manual-step", message, step.line)
        hubs = [d for d in step.directives if d.name == "hub" and not d.gates]
        if len({d.args["name"] for d in hubs}) > 1:
            add("error", "hub", f"a step has one .hub ({hubs[0].args['name']} already)", hubs[-1].line)


def _directive_line(source: Source, step: Step, line: str, number: int, specs: dict[str, Spec], add) -> None:
    """A directive or gate line of the step being read (Parser.lua scanDirective)."""
    name = _DIRECTIVE.fullmatch(line)
    name = name.group(1) if name else None
    if name not in GATES and name not in MODIFIERS:
        step.content += 1  # what makes a step not empty, even when its own arguments are wrong
    step.end_line = number
    try:
        item = parse_directive_line(line, number, specs)
    except ArgError:
        if name in GATES:
            step.invalid = True  # a malformed gate drops the step rather than show it to every character
        raise
    if isinstance(item, list):
        step.gates += item
        return
    step.directives.append(item)
    if item.name == "todo" and not item.args["quoted"]:
        add("warning", "todo-quotes", 'write the reason in quotes: .todo "<reason>"', number)


def _step_line(source: Source, step: Step, rest: str) -> None:
    if source.kind == "track":
        anchor = _ANCHOR.fullmatch(rest)
        step.invalid = True  # until the anchor is known good
        if not anchor:
            raise ArgError("a track step needs one anchor: @hub <name>, @level <N> or @zone <uiMapID>")
        kind, value, extra = anchor.groups()
        if extra:
            raise ArgError("a track step has exactly one anchor")
        if kind not in ("hub", "level", "zone"):
            raise ArgError(f"unknown anchor @{kind}")
        if kind != "hub" and not (_WHOLE.fullmatch(value) and int(value) >= 1):
            raise ArgError(f"@{kind} needs a positive whole number")
        step.anchor = (kind, value if kind == "hub" else int(value))
        step.invalid = False
    elif rest.startswith("@"):  # reported, but the step stays (Parser.lua scanStep)
        raise ArgError("anchors (@hub, @level, @zone) belong to profession tracks")
    elif rest:
        raise ArgError(f"unexpected text after step: {rest!r}")


# Lua files -----------------------------------------------------------------------------------------------------------

Token = namedtuple("Token", "kind text start end")

_LUA_TOKEN = re.compile(
    r"""
      (?P<space>\s+)
    | (?P<comment>--\[(?P<ceq>=*)\[.*?\](?P=ceq)\]|--[^\n]*)
    | (?P<long>\[(?P<leq>=*)\[.*?\](?P=leq)\])
    | (?P<string>"(?:[^"\\\n]|\\.)*"|'(?:[^'\\\n]|\\.)*')
    | (?P<name>[A-Za-z_][A-Za-z0-9_]*)
    | (?P<number>0[xX][0-9a-fA-F]+|(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?)
    | (?P<op>\.\.\.|\.\.|==|~=|<=|>=|::|[-+*/%^#<>=(){}\[\];:,.])
    """,
    re.S | re.X,
)
_TOKEN_KINDS = ("space", "comment", "long", "string", "name", "number", "op")
_LONG_OPEN = re.compile(r"\[=*\[")


def lua_tokens(text: str) -> list[Token]:
    """Lua tokens without whitespace and comments (enough to find calls and table fields; not a full lexer)."""
    tokens = []
    pos, end = 0, len(text)
    while pos < end:
        match = _LUA_TOKEN.match(text, pos)
        if not match:
            pos += 1
            continue
        kind = next(name for name in _TOKEN_KINDS if match.group(name) is not None)
        if kind not in ("space", "comment"):
            tokens.append(Token(kind, match.group(), match.start(), match.end()))
        pos = match.end()
    return tokens


def _line_of(text: str, offset: int) -> int:
    return text.count("\n", 0, offset) + 1


def _content_line(text: str, offset: int) -> int:
    """The line where a string literal's text begins (a long string's first newline belongs to the bracket)."""
    line = _line_of(text, offset)
    bracket = _LONG_OPEN.match(text, offset)
    if bracket and text.startswith("\n", bracket.end()):
        line += 1
    return line


class _PositionParser(_Parser):
    """The SavedVariables literal parser, remembering where each string literal starts."""

    def __init__(self, text: str) -> None:
        super().__init__(text)
        self.strings: list[tuple[int, str]] = []

    def value(self) -> object:
        self.skip()
        start = self.pos
        result = super().value()
        if isinstance(result, str):
            self.strings.append((start, result))
        return result


@dataclass
class LuaCall:
    owner: str
    method: str
    args: list
    starts: list[int]  # offset of each argument
    strings: list[tuple[int, str]]  # offset and value of every string literal in the arguments
    line: int

    def string_line(self, text: str, value: object) -> int | None:
        """The file line where the given string argument (or table field value) begins."""
        for offset, candidate in self.strings:
            if candidate is value:
                return _content_line(text, offset)
        return None


def _is(token: Token, kind: str, text: str | None = None) -> bool:
    return token.kind == kind and (text is None or token.text == text)


def _is_method(tokens: list[Token], i: int, owner: str, method: str) -> bool:
    """tokens[i:i+5] spell `ns.<owner>:<method>`."""
    return (
        _is(tokens[i], "name", "ns")
        and _is(tokens[i + 1], "op", ".")
        and _is(tokens[i + 2], "name", owner)
        and _is(tokens[i + 3], "op", ":")
        and _is(tokens[i + 4], "name", method)
    )


def find_register_calls(text: str, owner: str, method: str, tokens: list[Token] | None = None):
    """Every `ns.<owner>:<method>(...)` whose arguments are literals, plus (line, message) for those that are not."""
    tokens = lua_tokens(text) if tokens is None else tokens
    calls, problems = [], []
    for i in range(len(tokens) - 5):
        if not _is_method(tokens, i, owner, method):
            continue
        line = _line_of(text, tokens[i].start)
        after = tokens[i + 5]
        parser = _PositionParser(text)
        try:
            args, starts = [], []
            if _is(after, "op", "("):
                parser.pos = after.end
                if not parser.take(")"):
                    while True:
                        parser.skip()
                        starts.append(parser.pos)
                        args.append(parser.value())
                        if parser.take(","):
                            continue
                        parser.expect(")")
                        break
            elif after.kind in ("string", "long") or _is(after, "op", "{"):
                parser.pos = after.start
                starts.append(after.start)
                args.append(parser.value())
            else:
                raise LuaParseError("expected its arguments")
        except LuaParseError as exc:
            problems.append((line, f"ns.{owner}:{method}: the arguments are not pure literals ({exc})"))
            continue
        calls.append(LuaCall(owner, method, args, starts, parser.strings, line))
    return calls, problems


def _literal_after(text: str, tokens: list[Token], name: str) -> tuple[object, str | None]:
    """The literal table assigned to the first `<name> = {`: (value, None), (None, problem) or (None, None)."""
    for i in range(len(tokens) - 2):
        if _is(tokens[i], "name", name) and _is(tokens[i + 1], "op", "=") and _is(tokens[i + 2], "op", "{"):
            parser = _Parser(text)
            parser.pos = tokens[i + 2].start
            try:
                return parser.value(), None
            except LuaParseError as exc:
                return None, f"{name} is not a pure literal table ({exc})"
    return None, None


def _value_after(tokens: list[Token], name: str, kind: str) -> str | None:
    for i in range(len(tokens) - 2):
        if _is(tokens[i], "name", name) and _is(tokens[i + 1], "op", "=") and tokens[i + 2].kind == kind:
            return tokens[i + 2].text
    return None


def _string_token(token: Token) -> str | None:
    if token.kind not in ("string", "long"):
        return None
    try:
        value = _Parser(token.text).value()
    except LuaParseError:
        return None
    return value if isinstance(value, str) else None


def _table_keys(tokens: list[Token], start: int) -> list[str]:
    """The field names directly inside the table constructor that starts at tokens[start]."""
    keys, depth = [], 0
    for j in range(start, len(tokens)):
        token = tokens[j]
        if _is(token, "op", "{"):
            depth += 1
        elif _is(token, "op", "}"):
            depth -= 1
            if depth == 0:
                break
        elif depth == 1 and tokens[j - 1].text in ("{", ",", ";") and j + 1 < len(tokens):
            if token.kind == "name" and _is(tokens[j + 1], "op", "="):
                keys.append(token.text)
            elif _is(token, "op", "[") and j + 3 < len(tokens) and _is(tokens[j + 2], "op", "]"):
                if _is(tokens[j + 3], "op", "=") and _string_token(tokens[j + 1]):
                    keys.append(_string_token(tokens[j + 1]))
    return keys


def _module_directives(tokens: list[Token]) -> list[str]:
    """Directive names a module registers: `directives = { name = {...} }` and `ns.Directives:Register("name", ...)`."""
    names: list[str] = []
    for i in range(len(tokens) - 2):
        if _is(tokens[i], "name", "directives") and _is(tokens[i + 1], "op", "=") and _is(tokens[i + 2], "op", "{"):
            names += _table_keys(tokens, i + 2)
    for i in range(len(tokens) - 6):
        if _is_method(tokens, i, "Directives", "Register") and _is(tokens[i + 5], "op", "("):
            name = _string_token(tokens[i + 6])
            if name:
                names.append(name)
    return list(dict.fromkeys(names))


def _first_string_arg(tokens: list[Token], owner: str, method: str) -> str | None:
    for i in range(len(tokens) - 6):
        if _is_method(tokens, i, owner, method) and _is(tokens[i + 5], "op", "("):
            return _string_token(tokens[i + 6])
    return None


def read_text(path: Path) -> str:
    """A Lua file as the client sees it: UTF-8, LF line endings (Lua turns CRLF in long strings into LF)."""
    text = path.read_bytes().decode("utf-8", "replace").lstrip(chr(0xFEFF))
    return text.replace("\r\n", "\n").replace("\r", "\n")


def read_class_module(path: str, text: str) -> tuple[ClassModule, list[Problem]]:
    tokens = lua_tokens(text)
    token = _first_string_arg(tokens, "Classes", "Register") or Path(path).stem
    module = ClassModule(token, path, directives=_module_directives(tokens))
    quests, problem = _literal_after(text, tokens, "classQuests")
    module.quests = quests
    problems = [Problem("warning", "class-module", problem, path)] if problem else []
    return module, problems


def read_profession_module(path: str, text: str) -> ProfessionModule:
    tokens = lua_tokens(text)
    key = _first_string_arg(tokens, "Professions", "Register") or Path(path).stem.lower()
    skill_line = _value_after(tokens, "skillLine", "number")
    primary = _value_after(tokens, "primary", "name")
    return ProfessionModule(
        key,
        path,
        int(float(skill_line)) if skill_line and not skill_line.lower().startswith("0x") else None,
        {"true": True, "false": False}.get(primary or ""),
        _module_directives(tokens),
    )


def _list_field(value: object, what: str, problems: list[str]) -> tuple[str, ...]:
    if value == "*":
        return ("*",)
    if isinstance(value, list) and value and all(isinstance(item, str) and item for item in value):
        return tuple(value)
    problems.append(f"{what} must be a list of tokens (or {{ \"*\" }})")
    return ("*",)


def _read_guide(project: Project, path: str, text: str, call: LuaCall) -> None:
    def problem(message: str) -> None:
        project.problems.append(Problem("error", "register", message, path, call.line))

    if len(call.args) != 1 or not isinstance(call.args[0], dict):
        problem("ns.Guides:Register takes one table")
        return
    table = call.args[0]
    gid, body = table.get("id"), table.get("text")
    if not isinstance(gid, str) or not gid:
        problem("the guide table needs an id")
        return
    if not isinstance(body, str):
        problem(f"guide {gid}: the table needs text = [[ ... ]]")
        return
    if gid in project.guides:
        problem(f"guide id {gid} is registered twice (also in {project.guides[gid].path})")
        return
    issues: list[str] = []
    faction = table.get("faction")
    if faction not in ("*", *FACTIONS):
        issues.append(f"faction must be one of {', '.join(FACTIONS)} or *")
        faction = "*"
    levels = table.get("levels")
    if not (
        isinstance(levels, list)
        and len(levels) == 2
        and all(isinstance(level, int) and level > 0 for level in levels)
        and levels[0] <= levels[1]
    ):
        issues.append("levels must be { low, high }")
        levels = [1, 60]
    races = _list_field(table.get("races"), "races", issues)
    classes = _list_field(table.get("classes"), "classes", issues)
    for issue in issues:
        problem(f"guide {gid}: {issue}")
    name = table.get("name") if isinstance(table.get("name"), str) else ""  # load_project falls back to #guide, id
    first_line = call.string_line(text, body) or call.line
    source = Source("guide", gid, gid, body, path, first_line, call.line)
    project.guides[gid] = Guide(gid, name, faction, races, classes, (levels[0], levels[1]), source, path, call.line)


def _read_text_call(project: Project, path: str, text: str, call: LuaCall, kind: str) -> None:
    what = "ns.Chapters:Register" if kind == "chapter" else "ns.Professions:RegisterTrack"
    target = project.chapters if kind == "chapter" else project.tracks
    if len(call.args) != 2 or not all(isinstance(arg, str) for arg in call.args):
        project.problems.append(Problem("error", "register", f"{what} takes an id and a text", path, call.line))
        return
    key, body = call.args
    if kind == "chapter" and not _CHAPTER_ID.fullmatch(key):
        project.problems.append(
            Problem("error", "register", f"chapter id {key!r}: use lowercase letters, digits and -", path, call.line)
        )
    elif kind == "track" and not _KEY.fullmatch(key):
        message = f"track key {key!r}: use a profession key"
        project.problems.append(Problem("error", "register", message, path, call.line))
    if key in target:
        message = f"{kind} {key} is registered twice (also in {target[key].path})"
        project.problems.append(Problem("error", "register", message, path, call.line))
        return
    if Path(path).stem != key:
        project.problems.append(
            Problem("warning", "file-name", f"{kind} {key} lives in {path}; name the file {key}.lua", path, call.line)
        )
    first_line = call.string_line(text, body) or call.line
    source_id = key if kind == "chapter" else f"track:{key}"
    target[key] = Source(kind, source_id, key, body, path, first_line, call.line)


def _lua_files(directory: Path) -> list[Path]:
    return sorted(directory.rglob("*.lua")) if directory.is_dir() else []


def load_project(root: Path) -> Project:
    """Read every guide, chapter and track under Guides/, the class and profession modules, and the borders."""
    root = Path(root)
    project = Project(root)

    def rel(path: Path) -> str:
        return path.relative_to(root).as_posix()

    for path in _lua_files(root / "Classes"):
        module, problems = read_class_module(rel(path), read_text(path))
        project.classes[module.token] = module
        project.problems += problems
    for path in _lua_files(root / "Professions"):
        module = read_profession_module(rel(path), read_text(path))
        project.professions[module.key] = module
    project.specs = registry(project.classes.values(), project.professions.values())
    for module in [*project.classes.values(), *project.professions.values()]:
        for name in module.directives:
            spec = project.specs.get(name)
            if spec is None or not spec.owners:
                message = f".{name} is a core directive or a gate; ignored"
                project.problems.append(Problem("warning", "module-directive", message, module.path))

    for path in _lua_files(root / "Guides"):
        text = read_text(path)
        tokens = lua_tokens(text)
        found = [
            ("guide", find_register_calls(text, "Guides", "Register", tokens)),
            ("chapter", find_register_calls(text, "Chapters", "Register", tokens)),
            ("track", find_register_calls(text, "Professions", "RegisterTrack", tokens)),
            ("borders", find_register_calls(text, "Travel", "RegisterBorders", tokens)),
        ]
        for kind, (calls, problems) in found:
            for line, message in problems:
                severity = "warning" if kind == "borders" else "error"
                project.problems.append(Problem(severity, "register", message, rel(path), line))
            for call in calls:
                if kind == "guide":
                    _read_guide(project, rel(path), text, call)
                elif kind == "borders":
                    entries = call.args[0] if call.args else None
                    entries = list(entries.values()) if isinstance(entries, dict) else entries
                    if not isinstance(entries, list):
                        message = "ns.Travel:RegisterBorders takes a list"
                        project.problems.append(Problem("warning", "register", message, rel(path), call.line))
                        continue
                    project.borders += [(rel(path), call.line, entry) for entry in entries]
                else:
                    _read_text_call(project, rel(path), text, call, kind)

    for source in project.sources():
        parse_source(source, project.specs)
    for guide in project.guides.values():
        guide.headers = guide_headers(guide.source)
        guide.name = guide.name or guide.headers.get("guide") or guide.id  # Parser.lua: the Register name wins
    return project


def guide_headers(source: Source) -> dict:
    """ns.Parser:Headers: the guide's own header statements (the Register table wins for the name)."""
    headers: dict[str, object] = {"professions": []}
    for item in source.items:
        if isinstance(item, Header) and item.kind in GUIDE_HEADERS:
            headers[item.kind] = item.value
    return headers


# Include, gating, chapters -------------------------------------------------------------------------------------------


@dataclass
class Expansion:
    guide: Guide
    items: list  # (Source, Header | Step), #include spliced in, before gating
    included: list[str] = field(default_factory=list)
    problems: list[Problem] = field(default_factory=list)


def expand(project: Project, guide: Guide) -> Expansion:
    """Splice every #include (nested; a cycle, an unknown id or a second include of one chapter is an error)."""
    expansion = Expansion(guide, [])

    def walk(source: Source, stack: tuple[str, ...]) -> None:
        for item in source.items:
            if isinstance(item, Header) and item.kind == "include":
                chapter_id = item.value
                message = None
                if chapter_id in stack:
                    message = f"#include cycle: {' -> '.join((*stack, chapter_id))}"
                elif chapter_id not in project.chapters:
                    message = f"#include {chapter_id}: no chapter registers that id"
                elif chapter_id in expansion.included:
                    message = f"#include {chapter_id} a second time: its step ids would repeat"
                if message:
                    expansion.problems.append(source.problem("error", "include", message, item.line))
                else:
                    expansion.included.append(chapter_id)
                    walk(project.chapters[chapter_id], (*stack, chapter_id))
            else:
                expansion.items.append((source, item))

    walk(guide.source, (guide.id,))
    return expansion


def gate_tokens(items: Iterable[Step]) -> dict[str, set[str]]:
    """The items each kind of gate uses in these steps (negated ones too), one spelling per item."""
    used: dict[str, dict[str, str]] = {kind: {} for kind in GATES}
    for step in items:
        gates = list(step.gates) + [gate for d in step.directives for gate in d.gates]
        for gate in gates:
            for item in gate.items:
                used[gate.kind].setdefault(item.lstrip("!").lower(), item.lstrip("!"))
    return {kind: set(spellings.values()) for kind, spellings in used.items()}


def variants(project: Project, guide: Guide, expansion: Expansion | None = None) -> list[Variant]:
    """Every kind of character the guide serves, as far as its gates can tell them apart."""
    expansion = expansion or expand(project, guide)
    steps = [item for _, item in expansion.items if isinstance(item, Step)]
    steps += [step for track in project.tracks.values() for step in track.steps()]
    used = gate_tokens(steps)
    factions = list(FACTIONS) if guide.faction == "*" else [guide.faction]
    races = [*sorted(used["race"]), OTHER] if "*" in guide.races else list(guide.races)
    classes = [*sorted(used["class"]), OTHER] if "*" in guide.classes else list(guide.classes)
    suggested = frozenset(guide.professions)
    plans = [suggested]
    if used["prof"]:
        plans += [suggested | frozenset(used["prof"]), frozenset()]
    plans = list(dict.fromkeys(plans))
    return [
        Variant(faction, race, cls, plan) for faction in factions for race in races for cls in classes for plan in plans
    ]


@dataclass
class Chapter:
    name: str
    levels: tuple[int, int]
    dungeon: bool
    source: Source | None
    line: int | None
    first: int | None = None
    last: int | None = None


@dataclass
class RouteStep:
    step: Step
    source: Source
    directives: list[Directive]  # the active directive lines, in line order, without the sticky ones
    sticky: list[Directive]
    chapter: int
    track: str | None = None  # the profession key of a merged track step

    @property
    def id(self) -> str:
        return self.step.id

    @property
    def hub(self) -> str | None:
        return next((d.args["name"] for d in self.directives if d.name == "hub"), None)

    @property
    def optional(self) -> set[int]:
        return {d.args["quest"] for d in self.directives if d.name == "optional"}

    def first_target(self) -> Coord | None:
        """The first .goto/.path coordinate (what @zone anchors match)."""
        for d in self.directives:
            if d.name == "goto":
                return d.args["coord"]
            if d.name == "path":
                return d.args["points"][0]
        return None

    def all_directives(self) -> Iterable[Directive]:
        """The active directives, sticky ones included, and the directive inside each `.sticky`."""
        for d in self.directives + self.sticky:
            yield from d.walk()


@dataclass
class Route:
    guide: Guide
    variant: Variant
    chapters: list[Chapter]
    steps: list[RouteStep]
    skip_quests: dict[int, tuple[str, Source, int]] = field(default_factory=dict)

    def max_level(self) -> int:
        return max((chapter.levels[1] for chapter in self.chapters if chapter.first is not None), default=0)


def gate_step(step: Step, variant: Variant) -> tuple[list[Directive], list[Directive]] | None:
    """The step's active (directives, sticky) for this character, or None when the step is dropped."""
    if step.invalid or not all(gate.passes(variant) for gate in step.gates):
        return None
    directives, sticky = [], []
    for d in step.directives:
        if all(gate.passes(variant) for gate in d.gates):
            (sticky if d.name == "sticky" else directives).append(d)
    if not directives and not sticky:
        return None
    return directives, sticky


def _index_chapters(chapters: list[Chapter], steps: list[RouteStep]) -> None:
    for chapter in chapters:
        chapter.first = chapter.last = None
    for index, route_step in enumerate(steps):
        chapter = chapters[route_step.chapter]
        if chapter.first is None:
            chapter.first = index
        chapter.last = index


def build_route(project: Project, guide: Guide, variant: Variant, expansion: Expansion | None = None) -> Route:
    """ns.Parser:ParseGuide without the profession tracks: chapters and the gated route steps."""
    expansion = expansion or expand(project, guide)
    route = Route(guide, variant, [], [])
    current: int | None = None
    for source, item in expansion.items:
        if isinstance(item, Header):
            if item.kind == "chapter":
                value = item.value
                route.chapters.append(Chapter(value["name"], value["levels"], value["dungeon"], source, item.line))
                current = len(route.chapters) - 1
            elif item.kind == "skipquest":
                route.skip_quests.setdefault(item.value["quest"], (item.value["reason"], source, item.line))
            continue
        gated = gate_step(item, variant)
        if gated is None:
            continue
        if current is None:  # steps before the first #chapter: the guide's implicit chapter
            route.chapters.append(Chapter(guide.name, guide.levels, False, guide.source, None))
            current = len(route.chapters) - 1
        route.steps.append(RouteStep(item, source, gated[0], gated[1], current))
    _index_chapters(route.chapters, route.steps)
    return route


# Profession tracks ---------------------------------------------------------------------------------------------------


def track_steps(project: Project, key: str, variant: Variant) -> list[tuple[Step, list[Directive], list[Directive]]]:
    """ns.Parser:ParseTrack: a track's valid steps that pass the gates, with their active directives."""
    source = project.tracks.get(key)
    if source is None:
        return []
    result = []
    for step in source.steps():
        gated = gate_step(step, variant) if step.anchor else None
        if gated is not None:
            result.append((step, gated[0], gated[1]))
    return result


def _find_gap(route: Route, anchor: tuple[str, object], previous: int, within: Callable[[int, int], bool]):
    """Where a track step goes: the first gap >= previous for its anchor, or None. Gap g is "before route step g"
    (after route step g - 1), as in Engine/Professions.lua."""
    kind, value = anchor
    steps = route.steps
    if kind == "hub":  # after the hub step: the same visit as the track's previous step, or a later one
        for index in range(max(previous - 1, 0), len(steps)):
            if steps[index].hub == value:
                return index + 1
    elif kind == "level":
        for chapter in route.chapters:
            if chapter.first is not None and chapter.first >= previous and chapter.levels[0] >= value:
                return chapter.first
    elif kind == "zone":
        for index in range(previous, len(steps)):
            target = steps[index].first_target()
            if target is not None and within(target.map, value):
                return index
    return None


def _gap_chapter(route: Route, gap: int, steps: list[RouteStep]) -> int:
    """The chapter of the track steps in a gap: inside a chapter that chapter; between two, never a dungeon chapter
    when the other is not (a dungeon's Skip must not skip profession steps), else the earlier one when a step in the
    gap is anchored after its route step (@hub), else the later one."""
    before = route.steps[gap - 1] if gap > 0 else None
    after = route.steps[gap] if gap < len(route.steps) else None
    if before is None or after is None:
        return (before or after).chapter
    if before.chapter == after.chapter:
        return before.chapter
    dungeons = route.chapters[before.chapter].dungeon, route.chapters[after.chapter].dungeon
    if dungeons[0] != dungeons[1]:
        return after.chapter if dungeons[0] else before.chapter
    if any(rs.step.anchor and rs.step.anchor[0] == "hub" for rs in steps):
        return before.chapter
    return after.chapter


def merge_tracks(
    project: Project,
    route: Route,
    keys: Iterable[str],
    within: Callable[[int, int], bool] | None = None,
) -> tuple[Route, list[tuple[str, Step]]]:
    """GUIDE-FORMAT "Track merging": the route with the tracks' steps inserted, and the track steps without an anchor.

    `keys` is the plan order (primaries first, then secondaries); `within(map, ancestor)` answers "is this map the
    anchor's map or below it" (the data pack's map tree; without one only the same map matches).
    """
    within = within or (lambda map_id, ancestor: map_id == ancestor)
    keys = list(keys)
    variant = route.variant.with_plan(keys)
    inserted: dict[int, list[RouteStep]] = {}
    unmatched: list[tuple[str, Step]] = []
    for key in keys:
        source = project.tracks.get(key)
        if source is None:
            continue
        previous = 0
        for step, directives, sticky in track_steps(project, key, variant):
            gap = _find_gap(route, step.anchor, previous, within)
            if gap is None:
                unmatched.append((key, step))
                continue
            inserted.setdefault(gap, []).append(RouteStep(step, source, directives, sticky, 0, key))
            previous = gap
    steps: list[RouteStep] = []
    for gap in range(len(route.steps) + 1):
        group = inserted.get(gap, [])
        for rs in group:
            rs.chapter = _gap_chapter(route, gap, group)
        steps += group
        if gap < len(route.steps):
            steps.append(route.steps[gap])
    chapters = [Chapter(c.name, c.levels, c.dungeon, c.source, c.line) for c in route.chapters]
    _index_chapters(chapters, steps)
    return Route(route.guide, variant, chapters, steps, dict(route.skip_quests)), unmatched
