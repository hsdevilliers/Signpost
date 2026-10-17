"""Step 0 of the Wowhead export (PLAN §6): check how Wowhead serves WoW: Forever and print a STRUCTURE report.

    python tools/wowhead_env.py [--cache DIR] [--force]

Run this on your own machine (Claude Code does not access Wowhead). It fetches about ten sample pages — one request
every 2 seconds, cached under ../Signpost_Data/cache/wowhead — and prints, for each, only what the parsers need to
know: HTTP status, which page markers exist, listview templates and field names, mapper and infobox shape, dataEnv
candidates. No page text is printed, so the report can be pasted to Claude Code to adapt the parsers.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from signpost_tools import devconfig, wowhead  # noqa: E402

DEFAULT_CACHE = devconfig.REPO_ROOT.parent / "Signpost_Data" / "cache" / "wowhead"

# Classic-era pages that should exist in any Forever database: Durotar, its first quest and quest giver, a copper
# vein, Light Shot, the zone list, and the Hunter class-quest category.
SAMPLES = [
    ("landing", ""),
    ("zones", "zones"),
    ("zone Durotar", "zone=14"),
    ("quests in Durotar", "quests=1.14"),
    ("quests in The Barrens", "quests=1.17"),
    ("hunter class quests", "quests=4.-261"),
    ("quest 4641", "quest=4641"),
    ("npc 3143", "npc=3143"),
    ("object 1731", "object=1731"),
    ("item 2516", "item=2516"),
    ("item 2516 xml", "item=2516&xml"),
]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--cache", type=Path, default=DEFAULT_CACHE, help="page cache (default ../Signpost_Data/cache/wowhead)")
    parser.add_argument("--force", action="store_true", help="re-fetch even if cached")
    options = parser.parse_args()

    client = wowhead.Wowhead(options.cache, force=options.force)
    report = {"user_agent": wowhead.USER_AGENT, "base": client.url(""), "pages": {}}
    for label, path in SAMPLES:
        try:
            page = client.get(path)
        except wowhead.WowheadError as error:
            report["pages"][label] = {"error": str(error)}
            continue
        entry = wowhead.describe(page)
        if path.endswith("&xml"):
            entry["xml_tags"] = sorted(set(re.findall(r"<([a-zA-Z]+)[ >]", page.text)))[:40]
        report["pages"][label] = entry
        print(f"{label}: HTTP {page.status}{' (cached)' if page.from_cache else ''}", file=sys.stderr)
    report["requests"] = client.requests
    print(json.dumps(report, indent=1, sort_keys=True))
    print(
        "\nPaste the JSON above to Claude Code. It contains page structure only (markers, field names, counts).",
        file=sys.stderr,
    )


if __name__ == "__main__":
    main()
