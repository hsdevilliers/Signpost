"""Install a planned route as a guide's chapters (tools/route_planner.py --install; docs/PLANNER.md).

The Route Planner writes a candidate route as chapter files in a project folder: `Guides/Chapters/plan-<label>-NN-<zone>.lua` and
`Guides/Plan.lua`, with the travel steps already inserted and the route checked by the simulator and lint. Installing is the
step the user takes on purpose: it moves those chapters into the repository under stable names (`<guide>-NN-<zone>`), points the
guide file at them (levels and `#include` list, `#skipquest` lines kept), replaces the chapters the guide used before (unless
another guide includes them), keeps both TOCs in step, and marks the guide in tools/drafts.json as planned so that
tools/rebuild_drafts.py does not draft over it.
"""

from __future__ import annotations

import json
import re
import shutil
import subprocess
from dataclasses import dataclass, field
from pathlib import Path

CHAPTER_BODY = re.compile(r'ns\.Chapters:Register\(\s*"[^"]+",\s*\[\[\n(.*)\]\]\s*\)', re.S)
GUIDE_TEXT = re.compile(r"(\btext\s*=\s*\[\[\n)(.*?)(\]\],)", re.S)
LEVELS = re.compile(r"\blevels\s*=\s*\{\s*\d+\s*,\s*\d+\s*\}")
INCLUDE = re.compile(r"^#include\s+(\S+)", re.M)
BUILT_ID = re.compile(r"^plan-.+?-(\d{2})-(.+)$")
TOC_CHAPTER = "Guides\\Chapters\\"
TOCS = ("Signpost.toc", "Signpost_Camelot.toc")


@dataclass
class Installed:
    chapters: list = field(default_factory=list)  # the new chapter ids, in order
    removed: list = field(default_factory=list)  # the chapter ids the guide used before and no guide uses now
    files: list = field(default_factory=list)  # every path written or changed
    formatted: bool = False


def short_id(guide_id: str, faction: str) -> str:
    prefix = faction.lower() + "-"
    return guide_id[len(prefix):] if guide_id.startswith(prefix) else guide_id


def guide_file(root: Path, guide_id: str) -> Path | None:
    for path in sorted((root / "Guides").glob("*.lua")):
        if re.search(r'\bid\s*=\s*"%s"' % re.escape(guide_id), path.read_text(encoding="utf-8")):
            return path
    return None


def includes_of(root: Path) -> dict[Path, list[str]]:
    """What every guide file in the repository includes."""
    return {p: INCLUDE.findall(p.read_text(encoding="utf-8")) for p in sorted((root / "Guides").glob("*.lua"))}


def toc_with(text: str, drop: set[str], add: list[str]) -> str:
    """A TOC without the chapter lines for `drop` and with `add` after the last chapter line left."""
    lines = text.split("\n")
    kept = [line for line in lines if not (line.startswith(TOC_CHAPTER) and line[len(TOC_CHAPTER):].removesuffix(".lua") in drop)]
    at = max((i for i, line in enumerate(kept) if line.startswith(TOC_CHAPTER)), default=None)
    if at is None:
        raise ValueError("the TOC lists no chapter to put the new ones after")
    kept[at + 1 : at + 1] = [f"{TOC_CHAPTER}{cid}.lua" for cid in dict.fromkeys(add) if f"{TOC_CHAPTER}{cid}.lua" not in kept]
    return "\n".join(kept)


def find_stylua(root: Path) -> Path | None:
    """StyLua from tools/bin of this checkout or, in a git worktree, of the main one; else the one on the PATH."""
    candidates = [root / "tools" / "bin"]
    common = subprocess.run(["git", "rev-parse", "--path-format=absolute", "--git-common-dir"], cwd=root, capture_output=True, text=True)
    if common.returncode == 0 and common.stdout.strip():
        candidates.append(Path(common.stdout.strip()).parent / "tools" / "bin")
    for folder in candidates:
        for name in ("stylua.exe", "stylua"):
            if (folder / name).is_file():
                return folder / name
    found = shutil.which("stylua")
    return Path(found) if found else None


def install(root: Path, built: Path, guide_id: str, faction: str, note: str, cap: int, baseline: str) -> Installed:
    """Move the built chapters into `root` as the guide's chapters. `built` is the planner's project folder."""
    target = guide_file(root, guide_id)
    if target is None:
        raise ValueError(f"no guide file in {root / 'Guides'} has the id {guide_id}")
    plan_text = (built / "Guides" / "Plan.lua").read_text(encoding="utf-8")
    block = GUIDE_TEXT.search(plan_text)
    if block is None:
        raise ValueError("the planned guide has no text block")
    built_ids = INCLUDE.findall(block.group(2))
    if not built_ids:
        raise ValueError("the planned guide includes no chapter")
    short = short_id(guide_id, faction)
    names: dict[str, str] = {}
    for old in built_ids:
        m = BUILT_ID.match(old)
        if m is None:
            raise ValueError(f"unexpected planned chapter id {old}")
        names[old] = f"{short}-{m.group(1)}-{m.group(2)}"

    before = includes_of(root)
    old_ids = before[target]
    others = {cid for path, ids in before.items() if path != target for cid in ids}
    result = Installed(chapters=[names[i] for i in built_ids])
    chapter_dir = root / "Guides" / "Chapters"
    chapter_dir.mkdir(parents=True, exist_ok=True)
    for cid in old_ids:  # the chapters this guide used and no other does are replaced
        if cid not in others and cid not in names.values():
            path = chapter_dir / f"{cid}.lua"
            if path.exists():
                path.unlink()
                result.files.append(path)
            result.removed.append(cid)
    for old in built_ids:
        text = (built / "Guides" / "Chapters" / f"{old}.lua").read_text(encoding="utf-8")
        body = CHAPTER_BODY.search(text)
        if body is None:
            raise ValueError(f"{old}: no chapter text found")
        new = names[old]
        path = chapter_dir / f"{new}.lua"
        path.write_text(
            f"-- PLANNED: {note}\n-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.\n{baseline}\n"
            f'local ADDON_NAME, ns = ...\n\nns.Chapters:Register("{new}", [[\n{body.group(1)}]])\n',
            encoding="utf-8",
            newline="\n",
        )
        result.files.append(path)

    text = target.read_text(encoding="utf-8")
    new_text = GUIDE_TEXT.sub(lambda m: m.group(1) + INCLUDE.sub(lambda i: f"#include {names[i.group(1)]}", block.group(2)) + m.group(3), text, count=1)
    new_text = LEVELS.sub(f"levels = {{ 1, {cap} }}", new_text, count=1)
    target.write_text(new_text, encoding="utf-8", newline="\n")
    result.files.append(target)

    for toc in TOCS:
        path = root / toc
        if path.exists():
            path.write_text(toc_with(path.read_text(encoding="utf-8"), set(result.removed), result.chapters), encoding="utf-8", newline="\n")
            result.files.append(path)

    manifest = root / "tools" / "drafts.json"
    if manifest.exists():
        data = json.loads(manifest.read_text(encoding="utf-8"))
        for entry in data.get("guides", []):
            if entry.get("guide") == guide_id:
                entry["planned"] = note
                entry["chapters"] = []
        manifest.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")
        result.files.append(manifest)

    stylua = find_stylua(root)
    if stylua is not None:
        lua = [str(p) for p in result.files if p.suffix == ".lua" and p.exists()]
        if lua:
            result.formatted = subprocess.run([str(stylua), *lua], cwd=root).returncode == 0
    return result
