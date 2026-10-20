"""Rebuild the drafted guide chapters from the data pack, reproducibly (tools/drafts.json is the manifest).

    python tools/rebuild_drafts.py                       every guide in the manifest
    python tools/rebuild_drafts.py --guide horde-tauren-druid
    python tools/rebuild_drafts.py --pack ../Signpost_Data

For each guide: run tools/guide_draft.py for each of its chapters, in the order the guide includes them, each chapter starting
from the level, experience, finished quests and `.level` gates the one before ended with (the walk is one walk, as in the
game); write Guides/Chapters/<id>.lua, drop each draft's own "travel to" `.todo` steps, then insert the steps
tools/guide_travel.py proposes for every uncovered zone change (until none is left: a travel step can open the next gap),
and apply the manifest's text rewrites. A guide is drafted with --hardcore only if the manifest says so ("hardcore": true):
a HARDCORE guide leaves out elite quests and the sourced dangerous ones, a normal guide tags group quests `.optional`.
Chapters are GENERATED: a hand edit to one is lost at the next rebuild, so changes go into the manifest (arguments, rewrites),
the HARDCORE rules or the tools, or into the guide file (Guides/<Guide>.lua), which this script never touches.
A guide the manifest marks "planned" was installed from the Route Planner (tools/route_planner.py --install): it is skipped here, and its
chapter entries stay because the planner reads their --chain and --exclude hints.

The manifest, per guide: { "guide": id, "faction", "hardcore": true|false, "chapters": [ { "id", "name", "race", "class",
"zones": [uiMapID, ...], "levels": "N-M", "args": [extra guide_draft.py arguments] } ], "rewrites": [ { "match": regex,
"with": replacement } ] }.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
ROOT = TOOLS.parent
sys.path.insert(0, str(TOOLS))

import guide_draft  # noqa: E402
import guide_travel  # noqa: E402

DRAFT_TRAVEL = re.compile(r'step\n  \.todo "travel to [^"\n]*"\n')
PROPOSAL = re.compile(r"-- insert after (\S+?):(\d+);.*?\n(step\n(?:  .*\n)+)")
TRAVEL_PASSES = 12


def chapter_path(chapter_id: str, root: Path = ROOT) -> Path:
    return root / "Guides" / "Chapters" / f"{chapter_id}.lua"


def guide_includes(guide_id: str) -> list[str] | None:
    """The chapter ids a guide file includes, in order (None: no guide file has that id)."""
    for path in sorted((ROOT / "Guides").glob("*.lua")):
        text = path.read_text(encoding="utf-8")
        if re.search(r'\bid\s*=\s*"%s"' % re.escape(guide_id), text):
            return re.findall(r"^#include\s+(\S+)", text, re.M)
    return None


def draft_chapter(guide: dict, chapter: dict, pack: Path, carry: dict) -> int:
    args = ["--race", chapter["race"], "--class", chapter["class"], "--faction", guide.get("faction", "Horde")]
    for zone in chapter["zones"]:
        args += ["--zone", str(zone)]
    args += ["--levels", chapter["levels"], "--id", chapter["id"], "--name", chapter["name"]]
    if guide.get("hardcore", True):
        args += ["--hardcore"]
    args += [str(a) for a in chapter.get("args", [])]
    args += ["--pack", str(pack), "--out", str(chapter_path(chapter["id"]))]
    return guide_draft.main(args, carry=carry)


def proposals(guide_id: str, pack: Path, root: Path = ROOT) -> list[tuple[str, int, str]]:
    import io
    from contextlib import redirect_stdout

    out = io.StringIO()
    with redirect_stdout(out):
        guide_travel.main(["--guide", guide_id, "--pack", str(pack), "--root", str(root)])
    return [(f, int(after), text) for f, after, text in PROPOSAL.findall(out.getvalue())]


def insert_proposals(found: list[tuple[str, int, str]], root: Path = ROOT) -> int:
    by_file: dict[str, list[tuple[int, str]]] = {}
    for name, after, text in found:
        by_file.setdefault(name, []).append((after, text))
    for name, items in by_file.items():
        path = root / name
        lines = path.read_text(encoding="utf-8").split("\n")
        for after, text in sorted(items, reverse=True):
            lines[after:after] = text.rstrip("\n").split("\n")
        path.write_text("\n".join(lines), encoding="utf-8", newline="\n")
    return sum(len(items) for items in by_file.values())


def rebuild(guide: dict, pack: Path) -> bool:
    if guide.get("planned"):
        print(f"rebuild_drafts: {guide['guide']}: planned, not drafted ({guide['planned']}); tools/route_planner.py --install replaces it")
        return True
    ids = [chapter["id"] for chapter in guide["chapters"]]
    included = guide_includes(guide["guide"])
    if included is not None and [i for i in included if i in ids] != ids:
        print(
            f"rebuild_drafts: {guide['guide']}: the manifest drafts {', '.join(ids)} but the guide file includes "
            f"{', '.join(included)}: the walk is one walk, so the orders must match",
            file=sys.stderr,
        )
        return False
    carry: dict = {"done": set(), "level": None, "xp": 0.0, "gated": 0}
    for chapter in guide["chapters"]:
        if draft_chapter(guide, chapter, pack, carry) != 0:
            print(f"rebuild_drafts: {chapter['id']}: guide_draft failed", file=sys.stderr)
            return False
        result, _ = guide_draft.LAST
        carry = {"done": set(result.done), "level": result.level, "xp": result.xp, "gated": result.gated}
        path = chapter_path(chapter["id"])
        path.write_text(DRAFT_TRAVEL.sub("", path.read_text(encoding="utf-8")), encoding="utf-8", newline="\n")
    inserted = 0
    for _ in range(TRAVEL_PASSES):  # a travel step can open the next gap (Stonetalon -> Barrens -> Ashenvale): until none is left
        found = proposals(guide["guide"], pack)
        if not found:
            break
        inserted += insert_proposals(found)
    for rewrite in guide.get("rewrites", []):
        for chapter in guide["chapters"]:
            path = chapter_path(chapter["id"])
            text = path.read_text(encoding="utf-8")
            path.write_text(re.sub(rewrite["match"], rewrite["with"], text), encoding="utf-8", newline="\n")
    left = len(proposals(guide["guide"], pack))
    kind = "HARDCORE" if guide.get("hardcore", True) else "normal"
    print(
        f"rebuild_drafts: {guide['guide']} ({kind}): {len(guide['chapters'])} chapters, ends at level {carry['level']}, "
        f"{inserted} travel steps inserted, {left} still uncovered"
    )
    return left == 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--guide", action="append", help="only this guide id (repeatable)")
    parser.add_argument("--manifest", type=Path, default=TOOLS / "drafts.json")
    parser.add_argument("--pack", type=Path, help="the data pack folder (default ../Signpost_Data)")
    options = parser.parse_args(argv)
    guide_travel.safe_stdout()
    pack = options.pack or guide_travel.default_pack_dir(ROOT)
    if pack is None:
        print("rebuild_drafts: no data pack found (../Signpost_Data)", file=sys.stderr)
        return 1
    manifest = json.loads(options.manifest.read_text(encoding="utf-8"))
    ok = True
    for guide in manifest["guides"]:
        if options.guide and guide["guide"] not in options.guide:
            continue
        ok = rebuild(guide, Path(pack)) and ok
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
