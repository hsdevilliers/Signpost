"""Polite, cached access to Wowhead's WoW: Forever database, and parsers for its pages.

These tools are run by the user on their own machine; Claude Code never runs them against the network (Wowhead's
robots.txt disallows Anthropic's agents) and never reads cached pages (CLAUDE.md). Diagnostics therefore describe page
*structure* only — which markers exist, field names, counts — never page text.

Rules (PLAN §6): at most one request every 2 s, single thread, an honest User-Agent naming the project, robots.txt
honoured for that agent, everything cached on disk and re-fetched only when older than max_age_days (or with force).
Only IDs, names, numbers and coordinates are extracted; never quest or NPC prose. Standard library only.

The parsers assume Wowhead's page structure as far as it is known (listviews, Quick Facts markup, mapper data, listview
row fields); `tools/wowhead_env.py` reports that structure from the user's machine, so each assumption can be checked.
"""

from __future__ import annotations

import gzip
import hashlib
import json
import re
import time
import urllib.error
import urllib.request
import urllib.robotparser
from dataclasses import dataclass
from pathlib import Path

USER_AGENT = "SignpostDataExporter/0.1 (+https://github.com/hsdevilliers/Signpost)"
BASE = "https://www.wowhead.com"
FLAVOR = "forever"
CLASSIC_FLAVOR = "classic"  # the Classic Era database: a quest missing there is new in Forever
MIN_DELAY = 2.0
MAX_RETRIES = 4
MAX_CONSECUTIVE_FAILURES = 10

# Wowhead entity type numbers (Gatherer data, tooltip types).
TYPE_NPC, TYPE_OBJECT, TYPE_ITEM, TYPE_QUEST, TYPE_SPELL = 1, 2, 3, 5, 6


class WowheadError(RuntimeError):
    pass


@dataclass
class Page:
    url: str
    status: int
    text: str
    from_cache: bool


class Wowhead:
    """Fetches pages with a disk cache, a global rate limit and robots.txt checks."""

    def __init__(
        self,
        cache_dir: Path,
        max_age_days: float = 7,
        force: bool = False,
        offline: bool = False,
        delay: float = MIN_DELAY,
        flavor: str = FLAVOR,
        log=print,
    ) -> None:
        self.cache_dir = Path(cache_dir)
        self.max_age = max_age_days * 86400
        self.force = force
        self.offline = offline
        self.delay = max(delay, MIN_DELAY)
        self.flavor = flavor
        self.log = log
        self.requests = 0
        self.cache_hits = 0
        self._last_request = 0.0
        self._failures = 0
        self._robots: urllib.robotparser.RobotFileParser | None = None

    # URLs ------------------------------------------------------------------------------------------------------------

    def url(self, path: str, flavor: str | None = None) -> str:
        """`quest=787` -> https://www.wowhead.com/forever/quest=787 (flavor picks another database, e.g. "classic")."""
        return f"{BASE}/{flavor or self.flavor}/{path.lstrip('/')}"

    # Cache -----------------------------------------------------------------------------------------------------------

    def _cache_file(self, url: str) -> Path:
        digest = hashlib.sha1(url.encode("utf-8")).hexdigest()
        return self.cache_dir / digest[:2] / f"{digest}.json"

    def _read_cache(self, url: str) -> dict | None:
        path = self._cache_file(url)
        if not path.exists():
            return None
        try:
            entry = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            return None
        return entry if entry.get("url") == url else None

    def _write_cache(self, url: str, status: int, text: str) -> None:
        path = self._cache_file(url)
        path.parent.mkdir(parents=True, exist_ok=True)
        entry = {"url": url, "status": status, "fetched": time.time(), "text": text}
        path.write_text(json.dumps(entry, ensure_ascii=False), encoding="utf-8")

    # Network ---------------------------------------------------------------------------------------------------------

    def _wait(self) -> None:
        pause = self._last_request + self.delay - time.monotonic()
        if pause > 0:
            time.sleep(pause)
        self._last_request = time.monotonic()

    def _download(self, url: str) -> tuple[int, str]:
        request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT, "Accept-Encoding": "gzip"})
        for attempt in range(MAX_RETRIES + 1):
            self._wait()
            self.requests += 1
            try:
                with urllib.request.urlopen(request, timeout=30) as response:
                    body = response.read()
                    if response.headers.get("Content-Encoding") == "gzip":
                        body = gzip.decompress(body)
                    return response.status, body.decode("utf-8", "replace")
            except urllib.error.HTTPError as error:
                if error.code == 404:
                    return 404, ""
                if error.code in (429, 500, 502, 503, 504) and attempt < MAX_RETRIES:
                    retry_after = error.headers.get("Retry-After") if error.headers else None
                    backoff = float(retry_after) if retry_after and retry_after.isdigit() else 15 * 2**attempt
                    self.log(f"  HTTP {error.code}; waiting {backoff:.0f} s before retrying")
                    time.sleep(backoff)
                    continue
                return error.code, ""
            except (urllib.error.URLError, TimeoutError, ConnectionError) as error:
                if attempt < MAX_RETRIES:
                    self.log(f"  network error ({error}); retrying")
                    time.sleep(10 * 2**attempt)
                    continue
                raise WowheadError(f"{url}: {error}") from error
        raise WowheadError(f"{url}: gave up after {MAX_RETRIES} retries")

    def _allowed(self, url: str) -> bool:
        if self._robots is None:
            self._robots = urllib.robotparser.RobotFileParser()
            status, text = self._download(f"{BASE}/robots.txt")
            if status != 200:
                raise WowheadError(f"cannot read robots.txt (HTTP {status}); not crawling without it")
            self._robots.parse(text.splitlines())
        return self._robots.can_fetch(USER_AGENT, url)

    def fetch(self, url: str) -> Page:
        """The page at url (from the cache when fresh). 404s are cached too; other errors are not."""
        cached = self._read_cache(url)
        if cached and (self.offline or (not self.force and time.time() - cached["fetched"] < self.max_age)):
            self.cache_hits += 1
            return Page(url, cached["status"], cached["text"], True)
        if self.offline:
            return Page(url, 0, "", True)
        if not self._allowed(url):
            raise WowheadError(f"robots.txt disallows {url} for {USER_AGENT}")
        status, text = self._download(url)
        if status in (200, 404):
            self._write_cache(url, status, text)
            self._failures = 0
        else:
            self._failures += 1
            if self._failures >= MAX_CONSECUTIVE_FAILURES:
                raise WowheadError(f"{self._failures} failures in a row (last HTTP {status} for {url}); stopping")
        return Page(url, status, text, False)

    def get(self, path: str, flavor: str | None = None) -> Page:
        return self.fetch(self.url(path, flavor))


# Parsing helpers -------------------------------------------------------------------------------------------------------

_OPENERS = {"[": "]", "{": "}"}


def extract_balanced(text: str, start: int) -> str | None:
    """The bracketed JS/JSON literal starting at text[start] ('[' or '{'), honouring strings and escapes."""
    if start >= len(text) or text[start] not in _OPENERS:
        return None
    depth, quote, i = 0, None, start
    while i < len(text):
        char = text[i]
        if quote:
            if char == "\\":
                i += 2
                continue
            if char == quote:
                quote = None
        elif char in "\"'":
            quote = char
        elif char in "[{":
            depth += 1
        elif char in "]}":
            depth -= 1
            if depth == 0:
                return text[start : i + 1]
        i += 1
    return None


def _json_after(text: str, pattern: re.Pattern) -> list[object]:
    """Every JSON value that directly follows a match of pattern (whose last group ends at the opening bracket)."""
    values = []
    for match in pattern.finditer(text):
        literal = extract_balanced(text, match.end() - 1)
        if literal is None:
            continue
        try:
            values.append(json.loads(literal))
        except ValueError:
            continue
    return values


_LISTVIEW = re.compile(r"new\s+Listview\s*\(\s*\{")
_LISTVIEW_DATA = re.compile(r"[\"']?data[\"']?\s*:\s*\[")
_LISTVIEW_FIELD = r"[\"']?{name}[\"']?\s*:\s*[\"']([^\"']*)[\"']"


def listviews(text: str) -> list[dict]:
    """[{template, id, data: [rows]}] for every `new Listview({...})` on the page."""
    found = []
    for match in _LISTVIEW.finditer(text):
        body = extract_balanced(text, match.end() - 1)
        if not body:
            continue
        data_match = _LISTVIEW_DATA.search(body)
        rows: list = []
        if data_match:
            literal = extract_balanced(body, data_match.end() - 1)
            try:
                rows = json.loads(literal) if literal else []
            except ValueError:
                rows = []
        view = {"data": rows}
        for field in ("template", "id"):
            field_match = re.search(_LISTVIEW_FIELD.format(name=field), body)
            view[field] = field_match.group(1) if field_match else None
        found.append(view)
    return found


def rows(text: str, template: str | None = None) -> list[dict]:
    """The rows (dicts) of every listview on the page, or of those with that template ("quest", "npc", "spell"...)."""
    return [
        row
        for view in listviews(text)
        if template is None or view["template"] == template
        for row in view["data"]
        if isinstance(row, dict)
    ]


_GATHERER = re.compile(r"WH\.Gatherer\.addData\(\s*(\d+)\s*,\s*(\d+)\s*,\s*\{")


def gatherer(text: str) -> dict[int, dict[str, dict]]:
    """{entity type: {id: fields}} from `WH.Gatherer.addData(type, env, {...})` calls (names of linked entities)."""
    data: dict[int, dict[str, dict]] = {}
    for match in _GATHERER.finditer(text):
        literal = extract_balanced(text, match.end() - 1)
        try:
            entries = json.loads(literal) if literal else {}
        except ValueError:
            continue
        data.setdefault(int(match.group(1)), {}).update(entries)
    return data


_MAPPER = re.compile(r"g_mapperData\s*=\s*\{")


def mapper(text: str) -> dict:
    """`g_mapperData = {...}`: {wowheadZoneID: {floor: {count, coords: [[x, y], ...], uiMapId?, ...}}}."""
    values = _json_after(text, _MAPPER)
    return values[0] if values and isinstance(values[0], dict) else {}


def coordinates(mapper_data: dict) -> list[dict]:
    """Flattened mapper data: [{zone: wowheadZoneID, uiMapId: id|None, x, y}] (percent coordinates)."""
    points = []
    for zone, floors in mapper_data.items():
        if not isinstance(floors, dict):
            continue
        for floor in floors.values():
            if not isinstance(floor, dict):
                continue
            ui_map = floor.get("uiMapId")
            for pair in floor.get("coords") or []:
                if isinstance(pair, list) and len(pair) >= 2:
                    points.append({"zone": to_int(zone), "uiMapId": to_int(ui_map), "x": pair[0], "y": pair[1]})
    return points


_INFOBOX = re.compile(r"(?:WH\.markup|Markup)\.printHtml\(\s*\"((?:[^\"\\]|\\.)*)\"\s*,\s*\"infobox-contents")


def infobox_markup(text: str) -> str | None:
    """The Quick Facts markup ([ul][li]...) of an entity page, unescaped."""
    match = _INFOBOX.search(text)
    if not match:
        return None
    try:
        return json.loads(f'"{match.group(1)}"')
    except ValueError:
        return None


_LINK = re.compile(r"\[url=/?(?:[a-z-]+/)?(npc|object|item|quest|zone|spell)=(\d+)")


def infobox_facts(markup: str) -> dict:
    """Level, required level, side and start/end entities from Quick Facts markup."""
    facts: dict = {}
    for item in re.findall(r"\[li\](.*?)\[/li\]", markup, re.S):
        plain = re.sub(r"\[/?[^\]]*\]", "", item).strip()
        if match := re.match(r"Level:\s*(\d+)", plain):
            facts["level"] = int(match.group(1))
        elif match := re.match(r"Requires level\s*(\d+)", plain, re.I):
            facts["reqlevel"] = int(match.group(1))
        elif plain.startswith("Side:"):
            facts["side"] = plain.split(":", 1)[1].strip()
        elif plain.startswith(("Start:", "End:")):
            key = "start" if plain.startswith("Start:") else "end"
            for kind, ident in _LINK.findall(item):
                facts.setdefault(key, []).append({"type": kind, "id": int(ident)})
    return facts


_SERIES = re.compile(r"<table[^>]*class=\"series\"[^>]*>(.*?)</table>", re.S)
_ROW = re.compile(r"<tr[^>]*>(.*?)</tr>", re.S)
_HREF = re.compile(r"href=\"/?(?:[a-z-]+/)?(npc|object|item|quest|zone|spell)=(\d+)")


def series(text: str) -> list[int | None]:
    """The quest's series in chain order: linked quest IDs, and None for the page's own quest (shown unlinked)."""
    match = _SERIES.search(text)
    if not match:
        return []
    chain: list[int | None] = []
    for row in _ROW.findall(match.group(1)):
        ids = [int(ident) for kind, ident in _HREF.findall(row) if kind == "quest"]
        if ids:
            chain.append(ids[0])
        elif "<b>" in row:
            chain.append(None)
    return chain


def neighbours(chain: list[int | None]) -> tuple[int | None, int | None]:
    """(previous, next) quest around the page's own quest in a series() chain."""
    if None not in chain:
        return None, None
    here = chain.index(None)
    previous = chain[here - 1] if here > 0 else None
    following = chain[here + 1] if here + 1 < len(chain) else None
    return previous, following


_DATA_ENV = re.compile(r"[\"']?dataEnv[\"']?\s*[:=]\s*(\d+)")


def data_env(text: str) -> list[int]:
    """Candidate dataEnv numbers mentioned on a page (for nether.wowhead.com tooltips)."""
    return sorted({int(value) for value in _DATA_ENV.findall(text)})


_HEADING = re.compile(r"<h1[^>]*>([^<]{1,80})</h1>")


def heading(text: str) -> str | None:
    """The page's <h1> (an entity page's name), when the Gatherer data did not name the entity."""
    match = _HEADING.search(text)
    return match.group(1).strip() if match else None


def entity_exists(page: Page) -> bool | None:
    """Whether an entity page shows a real entry: False for a 404, True with Quick Facts, None when unclear."""
    if page.status == 404:
        return False
    if page.status != 200:
        return None
    return True if infobox_markup(page.text) is not None else None


def to_int(value: object) -> int | None:
    """An ID, level or count as an int (numbers and digit strings), else None."""
    if isinstance(value, bool):
        return None
    try:
        return int(value)  # type: ignore[arg-type]
    except (TypeError, ValueError):
        return None


# Listview rows: NPCs, class spells, recipes ----------------------------------------------------------------------------
#
# Assumed row fields (check them in the wowhead_env.py report: listview row_keys_all and shapes):
#   npc rows    id, name, tag (the subtitle shown under the name), react = [alliance, horde] (1 friendly, 0 neutral,
#               -1 hostile)
#   spell rows  id, level (class spells: the level they are learned at), cat (7 = class ability), source (list of
#               Wowhead source codes, 6 = trainer), trainingcost; recipes also skill = [skillLineIDs], learnedat,
#               colors = [orange, yellow, green, grey], creates = [itemID, min, max], reagents = [[itemID, count], ...]

# A row whose tag matches is a candidate for that role; the first match wins.
_ROLES = (
    ("flight", re.compile(r"flight master|wind rider master|gryphon master|hippogryph master|bat handler", re.I)),
    ("inn", re.compile(r"\binnkeeper\b", re.I)),
    ("transport", re.compile(r"zeppelin master|dock ?master|harbou?r ?master", re.I)),
    ("trainer", re.compile(r"\btrainer\b", re.I)),
)
SOURCE_TRAINER = 6
# Wowhead source codes that tell where a recipe is learned, in order of preference (an extension of the schema's
# "trainer" | "vendor" | "drop": "quest").
RECIPE_SOURCES = {SOURCE_TRAINER: "trainer", 5: "vendor", 4: "quest", 2: "drop"}
CLASS_ABILITY_CATEGORY = 7


def react_side(react: object) -> str | None:
    """Who can use an NPC, from a row's `react`: "Alliance", "Horde", "both", "hostile" (to both), or None (unknown)."""
    if not isinstance(react, list) or len(react) < 2:
        return None
    values = [to_int(value) for value in react[:2]]
    if None in values:
        return None
    alliance, horde = (value >= 0 for value in values)  # type: ignore[operator]
    if alliance and horde:
        return "both"
    if alliance:
        return "Alliance"
    return "Horde" if horde else "hostile"


def npc_role(tag: object) -> str | None:
    """"flight", "inn", "transport" or "trainer" for an NPC row's tag, else None."""
    if not isinstance(tag, str):
        return None
    for role, pattern in _ROLES:
        if pattern.search(tag):
            return role
    return None


def transport_kind(tag: object) -> str:
    """"zeppelin" for a zeppelin master's tag, "boat" for any other transport tag."""
    return "zeppelin" if isinstance(tag, str) and "zeppelin" in tag.lower() else "boat"


def recipe(row: dict) -> tuple[dict, list[str]] | None:
    """A profession spell row as a recipe (item, skill colors, reagents, src) and the fields it lacks; None when the
    row is not a recipe at all (no colors, reagents or product: a rank or gathering spell)."""
    if not any(key in row for key in ("colors", "reagents", "creates")):
        return None
    record: dict = {}
    missing = []
    creates = row.get("creates")
    if isinstance(creates, list) and creates and (to_int(creates[0]) or 0) > 0:
        record["item"] = to_int(creates[0])
    colors = row.get("colors")
    skill = [to_int(value) for value in colors] if isinstance(colors, list) and len(colors) == 4 else []
    if skill and None not in skill:
        learned = to_int(row.get("learnedat"))
        if skill[0] <= 0 and learned and learned > 0:  # type: ignore[operator]
            skill[0] = learned
        record["skill"] = skill
    else:
        missing.append("skill colors")
    reagents = {}
    for pair in row.get("reagents") or []:
        if isinstance(pair, list) and len(pair) >= 2 and (to_int(pair[0]) or 0) > 0 and (to_int(pair[1]) or 0) > 0:
            reagents[to_int(pair[0])] = to_int(pair[1])
    if reagents:
        record["reagents"] = reagents
    elif "reagents" not in row:
        missing.append("reagents")
    sources = {to_int(code) for code in row.get("source") or []} if isinstance(row.get("source"), list) else set()
    for code, label in RECIPE_SOURCES.items():
        if code in sources:
            record["src"] = label
            break
    return record, missing


def trainer_spells(spell_rows: list[dict]) -> tuple[dict[int, list[int]], str]:
    """{level: [spellIDs]} of the trainer-taught spells among class spell rows, and the field that decided it:
    "source" (trainer code), "trainingcost", or "none" (neither field present: every spell with a level is kept).
    Rows outside the class-ability category are dropped when the rows carry a category."""
    candidates = [row for row in spell_rows if (to_int(row.get("id")) or 0) > 0 and (to_int(row.get("level")) or 0) > 0]
    abilities = [row for row in candidates if to_int(row.get("cat")) == CLASS_ABILITY_CATEGORY]
    if abilities:
        candidates = abilities
    if any(isinstance(row.get("source"), list) for row in candidates):
        basis = "source"
        candidates = [
            row
            for row in candidates
            if isinstance(row.get("source"), list) and SOURCE_TRAINER in {to_int(code) for code in row["source"]}
        ]
    elif any("trainingcost" in row for row in candidates):
        basis = "trainingcost"
        candidates = [row for row in candidates if (to_int(row.get("trainingcost")) or 0) > 0]
    else:
        basis = "none"
    by_level: dict[int, set[int]] = {}
    for row in candidates:
        by_level.setdefault(to_int(row["level"]), set()).add(to_int(row["id"]))  # type: ignore[arg-type]
    return {level: sorted(ids) for level, ids in sorted(by_level.items())}, basis


# Structural diagnostics (safe to share: no page text) ------------------------------------------------------------------

_MARKERS = {
    "listview": "new Listview(",
    "gatherer": "WH.Gatherer.addData(",
    "mapper": "g_mapperData",
    "infobox": "infobox-contents",
    "markup_printHtml": "printHtml(",
    "series_table": 'class="series"',
    "setPageData": "WH.setPageData(",
    "dataEnv": "dataEnv",
    "flavor_links": f"/{FLAVOR}/",
}
# Row fields the parsers rely on; describe() reports the shape of their values (never the values).
_SHAPE_KEYS = (
    "cat",
    "category",
    "colors",
    "creates",
    "learnedat",
    "level",
    "location",
    "maxlevel",
    "minlevel",
    "react",
    "reagents",
    "reqclass",
    "reqlevel",
    "reqrace",
    "side",
    "skill",
    "source",
    "tag",
    "trainingcost",
)
_ROW_KEYS_LIMIT = 60


def shape(value: object) -> str:
    """A value's shape without its content: null, bool, int, float, str, dict[n], or list[n]<item shapes> (the
    shapes of up to 8 items, e.g. list[2]<list[2]<int>> for [[itemID, count], ...])."""
    if value is None:
        return "null"
    if isinstance(value, bool):
        return "bool"
    if isinstance(value, (int, float, str)):
        return type(value).__name__
    if isinstance(value, dict):
        return f"dict[{len(value)}]"
    if isinstance(value, list):
        inner = sorted({shape(item) for item in value[:8]})
        return f"list[{len(value)}]" + (f"<{'|'.join(inner)}>" if inner else "")
    return type(value).__name__


def _describe_listview(view: dict) -> dict:
    data = view["data"]
    row_dicts = [row for row in data if isinstance(row, dict)]
    shapes = {}
    for key in _SHAPE_KEYS:
        holder = next((row for row in row_dicts if key in row), None)
        if holder is not None:
            shapes[key] = shape(holder[key])
    return {
        "template": view["template"],
        "id": view["id"],
        "rows": len(data),
        "row_keys": sorted(data[0]) if data and isinstance(data[0], dict) else [],
        "row_keys_all": sorted(set().union(*row_dicts))[:_ROW_KEYS_LIMIT] if row_dicts else [],
        "shapes": shapes,
    }


def describe(page: Page) -> dict:
    """What a page contains, by structure only: markers, listview templates, row keys and value shapes, how many NPC
    rows each role pattern matches, mapper shape, infobox fact keys and link kinds."""
    text = page.text
    report: dict = {"url": page.url, "status": page.status, "bytes": len(text), "from_cache": page.from_cache}
    report["markers"] = {name: marker in text for name, marker in _MARKERS.items()}
    views = listviews(text)
    report["listviews"] = [_describe_listview(view) for view in views]
    roles: dict[str, int] = {}
    for row in (row for view in views if view["template"] == "npc" for row in view["data"] if isinstance(row, dict)):
        role = npc_role(row.get("tag"))
        if role:
            roles[role] = roles.get(role, 0) + 1
    report["npc_roles"] = dict(sorted(roles.items()))
    report["gatherer_types"] = {str(kind): len(entries) for kind, entries in gatherer(text).items()}
    data = mapper(text)
    first_floor = next((f for floors in data.values() if isinstance(floors, dict) for f in floors.values()), None)
    report["mapper"] = {
        "zones": len(data),
        "floor_keys": sorted(first_floor) if isinstance(first_floor, dict) else [],
        "points": len(coordinates(data)),
    }
    markup = infobox_markup(text)
    if markup is None:
        report["infobox"] = None
    else:
        facts = infobox_facts(markup)
        report["infobox"] = {
            "fact_keys": sorted(facts),
            "tags": sorted(set(re.findall(r"\[([a-z]+)[ =\]]", markup))),
            "link_kinds": sorted({kind for kind, _ in _LINK.findall(markup)}),
        }
    report["series_quests"] = len(series(text))
    report["dataEnv"] = data_env(text)
    report["setPageData_keys"] = sorted(set(re.findall(r"WH\.setPageData\(\s*[\"']([^\"']+)[\"']", text)))[:40]
    return report
