"""Polite, cached access to Wowhead's WoW: Forever database, and parsers for its pages.

These tools are run by the user on their own machine; Claude Code never runs them against the network (Wowhead's
robots.txt disallows Anthropic's agents) and never reads cached pages (CLAUDE.md). Diagnostics therefore describe page
*structure* only — which markers exist, field names, counts — never page text.

Rules (PLAN §6): at most one request every 2 s, single thread, an honest User-Agent naming the project, robots.txt
honoured for that agent, everything cached on disk and re-fetched only when older than max_age_days (or with force).
Only IDs, names, numbers and coordinates are extracted; never quest or NPC prose. Standard library only.
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

    def url(self, path: str) -> str:
        """`quest=787` -> https://www.wowhead.com/forever/quest=787"""
        return f"{BASE}/{self.flavor}/{path.lstrip('/')}"

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

    def get(self, path: str) -> Page:
        return self.fetch(self.url(path))


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
                    points.append({"zone": _int(zone), "uiMapId": _int(ui_map), "x": pair[0], "y": pair[1]})
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


def _int(value: object) -> int | None:
    try:
        return int(value)  # type: ignore[arg-type]
    except (TypeError, ValueError):
        return None


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


def describe(page: Page) -> dict:
    """What a page contains, by structure only: markers, listview templates and row keys, mapper shape, link kinds."""
    text = page.text
    report: dict = {"url": page.url, "status": page.status, "bytes": len(text), "from_cache": page.from_cache}
    report["markers"] = {name: marker in text for name, marker in _MARKERS.items()}
    report["listviews"] = [
        {
            "template": view["template"],
            "id": view["id"],
            "rows": len(view["data"]),
            "row_keys": sorted(view["data"][0]) if view["data"] and isinstance(view["data"][0], dict) else [],
        }
        for view in listviews(text)
    ]
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
