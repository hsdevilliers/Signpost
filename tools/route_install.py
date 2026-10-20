"""Install a planned route as a guide's chapters (tools/route_planner.py --install; docs/PLANNER.md).

The Route Planner writes a candidate route as chapter files in a project folder: `Guides/Chapters/plan-<label>-NN-<zone>.lua` and
`Guides/Plan.lua`, with the travel steps already inserted and the route checked by the simulator and lint. Installing is the
step the user takes on purpose: it moves those chapters into the repository under stable names (`<guide>-NN-<zone>`), points the
guide file at them (its `#include` and `#skipquest` lines are replaced; every other line of the guide text, such as `#professions`
or a hand-written step, stays), replaces the chapters the guide used before (unless another guide or chapter includes them), keeps
both TOCs in step, and marks the guide `planned` in tools/drafts.json so that tools/rebuild_drafts.py does not draft over it (the
manifest's chapters, with their `--chain` and `--exclude` hints, stay: the planner reads them).

Everything is read and checked first and nothing is written until all of it holds, so a refusal leaves the repository as it was.
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
BUILT_ID = re.compile(r"^plan-.+?-(\d{2})-([a-z0-9-]+)$")
TOC_CHAPTER = re.compile(r"^Guides[\\/]Chapters[\\/](.+?)\.lua$")
TOCS = ("Signpost.toc", "Signpost_Camelot.toc")


@dataclass
class Installed:
    chapters: list = field(default_factory=list)  # the new chapter ids, in order
    removed: list = field(default_factory=list)  # the chapter ids the guide used before and nothing uses now
    files: list = field(default_factory=list)  # every path written or changed
    formatted: bool | None = None  # StyLua: True ran, False failed, None not found


def short_id(guide_id: str, faction: str) -> str:
    prefix = faction.lower() + "-"
    return guide_id[len(prefix):] if guide_id.startswith(prefix) else guide_id


def guide_file(root: Path, guide_id: str) -> Path | None:
    for path in sorted((root / "Guides").glob("*.lua")):
        if re.search(r'\bid\s*=\s*"%s"' % re.escape(guide_id), path.read_text(encoding="utf-8")):
            return path
    return None


def guide_includes(root: Path) -> dict[Path, list[str]]:
    """What every guide file in the repository includes."""
    return {p: INCLUDE.findall(p.read_text(encoding="utf-8")) for p in sorted((root / "Guides").glob("*.lua"))}


def chapter_includes(root: Path, skip: set[str]) -> set[str]:
    """The chapters that other chapters include (an `#include` nests), leaving out the chapter files named in `skip`."""
    found: set[str] = set()
    for path in sorted((root / "Guides" / "Chapters").glob("*.lua")):
        if path.stem not in skip:
            found.update(INCLUDE.findall(path.read_text(encoding="utf-8")))
    return found


def merge_text(old: str, plan: str, names: dict[str, str]) -> str:
    """The guide's text with the plan's `#skipquest` lines and its `#include` lines (renamed) where the old ones were; every other
    line (`#guide`, `#professions`, notes, steps written by hand) is kept as it is."""
    skips = [line for line in plan.splitlines() if line.startswith("#skipquest")]
    includes = [f"#include {names[cid]}" for cid in INCLUDE.findall(plan)]
    out: list[str] = []
    placed = False
    for line in old.splitlines():
        if line.startswith("#include") or line.startswith("#skipquest"):
            if not placed:
                out += skips + includes
                placed = True
            continue
        out.append(line)
    if not placed:
        out += skips + includes
    return "\n".join(out) + "\n"


def toc_with(text: str, drop: set[str], add: list[str]) -> str:
    """A TOC without the chapter lines for `drop` and with `add` where the last chapter line was (the TOC's own path separator)."""
    kept: list[str] = []
    anchor = None
    present: set[str] = set()
    separator = "\\"
    for line in text.split("\n"):
        m = TOC_CHAPTER.match(line.strip())
        if m:
            separator = "/" if "/" in line and "\\" not in line else "\\"
            if m.group(1) in drop:
                anchor = len(kept)
                continue
            present.add(m.group(1))
            kept.append(line)
            anchor = len(kept)
        else:
            kept.append(line)
    if anchor is None:
        raise ValueError("the TOC lists no chapter to put the new ones beside")
    kept[anchor:anchor] = [f"Guides{separator}Chapters{separator}{cid}.lua" for cid in dict.fromkeys(add) if cid not in present]
    return "\n".join(kept)


def find_stylua(root: Path) -> Path | None:
    """StyLua from tools/bin of this checkout or, in a git worktree, of the main one; else the one on the PATH."""
    candidates = [root / "tools" / "bin"]
    try:
        common = subprocess.run(["git", "rev-parse", "--path-format=absolute", "--git-common-dir"], cwd=root, capture_output=True, text=True)
        if common.returncode == 0 and common.stdout.strip():
            candidates.append(Path(common.stdout.strip()).parent / "tools" / "bin")
    except OSError:
        pass  # no git on the PATH
    for folder in candidates:
        for name in ("stylua.exe", "stylua"):
            if (folder / name).is_file():
                return folder / name
    found = shutil.which("stylua")
    return Path(found) if found else None


def format_lua(root: Path, paths: list[Path]) -> bool | None:
    """Run StyLua on the files: True when it ran, False when it failed, None when there is none to run."""
    stylua = find_stylua(root)
    if stylua is None:
        return None
    if not paths:
        return True
    try:
        return subprocess.run([str(stylua.resolve()), *[str(p.resolve()) for p in paths]], cwd=root.resolve()).returncode == 0
    except OSError:
        return False


@dataclass
class Prepared:
    """Everything an install will write, checked, in memory."""

    chapters: dict = field(default_factory=dict)  # path -> text
    other: dict = field(default_factory=dict)  # path -> text: the guide file, the TOCs, the manifest
    delete: list = field(default_factory=list)  # paths
    new_ids: list = field(default_factory=list)
    removed: list = field(default_factory=list)


def prepare(root: Path, built: Path, guide_id: str, faction: str, note: str, cap: int, baseline: str) -> Prepared:
    """Read and check everything an install needs and write nothing: a ValueError leaves the repository as it was."""
    target = guide_file(root, guide_id)
    if target is None:
        raise ValueError(f"no guide file in {root / 'Guides'} has the id {guide_id}")
    plan_text = (built / "Guides" / "Plan.lua").read_text(encoding="utf-8")
    plan_block = GUIDE_TEXT.search(plan_text)
    if plan_block is None:
        raise ValueError("the planned guide has no text block")
    built_ids = INCLUDE.findall(plan_block.group(2))
    if not built_ids:
        raise ValueError("the planned guide includes no chapter")
    short = short_id(guide_id, faction)
    names: dict[str, str] = {}
    for old in built_ids:
        m = BUILT_ID.match(old)
        if m is None:
            raise ValueError(f"unexpected planned chapter id {old}")
        names[old] = f"{short}-{m.group(1)}-{m.group(2)}"

    old_text = target.read_text(encoding="utf-8")
    old_block = GUIDE_TEXT.search(old_text)
    if old_block is None:
        raise ValueError(f"{target.name}: no `text = [[` block on a line of its own to put the chapters in")
    old_ids = INCLUDE.findall(old_block.group(2))
    others = {cid for path, ids in guide_includes(root).items() if path != target for cid in ids}
    for new in names.values():
        if new in others and new not in old_ids:
            raise ValueError(f"{new} is a chapter another guide includes: the install would replace it")
    nested = chapter_includes(root, set(old_ids))
    prepared = Prepared(new_ids=[names[i] for i in built_ids])
    chapter_dir = root / "Guides" / "Chapters"
    for old in built_ids:
        body = CHAPTER_BODY.search((built / "Guides" / "Chapters" / f"{old}.lua").read_text(encoding="utf-8"))
        if body is None:
            raise ValueError(f"{old}: no chapter text found")
        new = names[old]
        prepared.chapters[chapter_dir / f"{new}.lua"] = (
            f"-- PLANNED: {note}\n-- Do not edit by hand: the next install replaces it. Change the route with tools/route_planner.py.\n"
            f'{baseline}\nlocal ADDON_NAME, ns = ...\n\nns.Chapters:Register("{new}", [[\n{body.group(1)}]])\n'
        )
    for cid in old_ids:  # the chapters this guide used and nothing else includes are replaced
        if cid not in names.values() and cid not in others and cid not in nested:
            prepared.removed.append(cid)
            if (chapter_dir / f"{cid}.lua").exists():
                prepared.delete.append(chapter_dir / f"{cid}.lua")

    new_block = merge_text(old_block.group(2), plan_block.group(2), names)
    guide_text = GUIDE_TEXT.sub(lambda m: m.group(1) + new_block + m.group(3), old_text, count=1)
    guide_text, count = LEVELS.subn(f"levels = {{ 1, {cap} }}", guide_text, count=1)
    if count != 1:
        raise ValueError(f"{target.name}: no `levels = {{ a, b }}` to change")
    prepared.other[target] = guide_text

    for toc in TOCS:
        path = root / toc
        if path.exists():
            prepared.other[path] = toc_with(path.read_text(encoding="utf-8"), set(prepared.removed), prepared.new_ids)

    manifest = root / "tools" / "drafts.json"
    if manifest.exists():
        data = json.loads(manifest.read_text(encoding="utf-8"))  # a corrupt manifest is a ValueError here
        for entry in data.get("guides", []):
            if entry.get("guide") == guide_id:
                entry["planned"] = note  # its chapters stay: the planner reads their --chain and --exclude hints
        prepared.other[manifest] = json.dumps(data, indent=2, ensure_ascii=False) + "\n"
    return prepared


def install(root: Path, built: Path, guide_id: str, faction: str, note: str, cap: int, baseline: str) -> Installed:
    """Move the built chapters into `root` as the guide's chapters. `built` is the planner's project folder."""
    prepared = prepare(root, built, guide_id, faction, note, cap, baseline)
    result = Installed(chapters=prepared.new_ids, removed=prepared.removed)
    (root / "Guides" / "Chapters").mkdir(parents=True, exist_ok=True)
    for path, text in {**prepared.chapters, **prepared.other}.items():
        path.write_text(text, encoding="utf-8", newline="\n")
        result.files.append(path)
    for path in prepared.delete:  # last: the old chapters go only when the new ones and every reference are in place
        path.unlink()
        result.files.append(path)
    result.formatted = format_lua(root, [p for p in result.files if p.suffix == ".lua" and p.exists()])
    return result
