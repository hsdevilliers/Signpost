"""Repository guards run by CI (and before every commit):

1. Nothing Wowhead-derived or machine-local is tracked (tools/cache/, *.generated.lua, the data pack, dev config).
2. The class/race/faction/profession seam: addon code outside Classes/, Professions/ and Guides/ never names a class,
   race, faction or profession.
3. Both TOCs are identical except for X-Flavor-TOC, start with `## Interface:`, list only files that exist and list
   every addon Lua file.

Exit status 1 when anything fails.
"""

from __future__ import annotations

import re
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TOCS = ("Signpost.toc", "Signpost_Camelot.toc")
TOC_DIFFERENCE = "## X-Flavor-TOC:"

FORBIDDEN = [
    (re.compile(r"(^|/)tools/cache/"), "Wowhead cache"),
    (re.compile(r"\.generated\.lua$"), "generated data"),
    (re.compile(r"(^|/)Signpost_Data/"), "the private data pack"),
    (re.compile(r"(^|/)incoming/"), "play-machine SavedVariables"),
    (re.compile(r"(^|/)tools/dev\.local\.json$"), "local dev config"),
    (re.compile(r"(^|/)tools/bin/"), "downloaded tool binaries"),
]

# Addon code that may name classes, races, factions and professions (CLAUDE.md "Class/race/faction/profession seam").
SEAM_EXEMPT = ("Classes/", "Professions/", "Guides/", "tests/", "Libs/", "tools/", "docs/", ".github/")
SEAM_SUFFIXES = (".lua", ".xml", ".toc")
_CLASS = "WARRIOR|PALADIN|HUNTER|ROGUE|PRIEST|DEATHKNIGHT|SHAMAN|MAGE|WARLOCK|MONK|DRUID|DEMONHUNTER|EVOKER"
_CLASS_NAMES = "Warrior|Paladin|Hunter|Rogue|Priest|Death Knight|Shaman|Mage|Warlock|Monk|Druid|Demon Hunter|Evoker"
_RACES = (
    "Human|Orc|Dwarf|NightElf|Night Elf|Scourge|Undead|Tauren|Gnome|Troll|BloodElf|Blood Elf|Draenei|Goblin|"
    "Worgen|Pandaren|Skyborne"
)
_PROFESSIONS = (
    "Alchemy|Blacksmithing|Enchanting|Engineering|Herbalism|Inscription|Jewelcrafting|Leatherworking|Mining|Skinning|"
    "Tailoring|First ?Aid|Cooking|Fishing"
)
SEAM_PATTERNS = [
    re.compile(rf"\b(?:{_CLASS}|{_CLASS_NAMES}|{_RACES})\b"),
    re.compile(r"\b(?:horde|alliance)\b", re.I),
    re.compile(rf"\b(?:{_PROFESSIONS})\b", re.I),
]

ADDON_DIRS = ("Core/", "Engine/", "Classes/", "Professions/", "Data/", "Guides/", "UI/", "Automation/")


def tracked_files(root: Path) -> list[str]:
    """Files git tracks plus untracked files it would add (so problems show up before the commit)."""
    try:
        out = subprocess.run(
            ["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard"],
            cwd=root,
            capture_output=True,
            text=True,
            check=True,
        ).stdout
        return sorted({path for path in out.split("\0") if path and (root / path).exists()})
    except (OSError, subprocess.CalledProcessError):
        return sorted(p.relative_to(root).as_posix() for p in root.rglob("*") if p.is_file() and ".git" not in p.parts)


def check_forbidden(files: list[str]) -> list[str]:
    return [f"{path}: {why} must not be committed" for path in files for rx, why in FORBIDDEN if rx.search(path)]


def seam_violations(path: str, text: str) -> list[str]:
    problems = []
    for number, line in enumerate(text.splitlines(), 1):
        for pattern in SEAM_PATTERNS:
            match = pattern.search(line)
            if match:
                problems.append(
                    f"{path}:{number}: '{match.group()}' outside Classes/, Professions/ and Guides/ "
                    "(use ns.Player or the profession plan)"
                )
                break
    return problems


def check_seam(root: Path, files: list[str]) -> list[str]:
    problems = []
    for path in files:
        if path.endswith(SEAM_SUFFIXES) and not path.startswith(SEAM_EXEMPT):
            problems += seam_violations(path, (root / path).read_text(encoding="utf-8", errors="replace"))
    return problems


def toc_entries(text: str) -> list[str]:
    return [line.strip().replace("\\", "/") for line in text.splitlines() if line.strip() and not line.startswith("#")]


def xml_includes(root: Path, xml_path: str) -> list[str]:
    base = Path(xml_path).parent
    found = []
    for element in ET.parse(root / xml_path).iter():
        if element.tag.split("}")[-1] in ("Script", "Include") and element.get("file"):
            found.append((base / element.get("file").replace("\\", "/")).as_posix())
    return found


def compare_tocs(texts: dict[str, str]) -> list[str]:
    problems = []
    for name, text in texts.items():
        if text.startswith("﻿"):
            problems.append(f"{name}: starts with a byte-order mark")
        if not text.lstrip("﻿").startswith("## Interface:"):
            problems.append(f"{name}: the first line must be '## Interface:' (Forever rejects anything before it)")
    stripped = {
        name: [line for line in text.splitlines() if not line.startswith(TOC_DIFFERENCE)] for name, text in texts.items()
    }
    first, *others = stripped
    for other in others:
        if stripped[other] != stripped[first]:
            problems.append(f"{other} differs from {first} beyond the {TOC_DIFFERENCE} line; keep them in sync")
    return problems


def check_tocs(root: Path, files: list[str]) -> list[str]:
    texts = {}
    for name in TOCS:
        if not (root / name).exists():
            return [f"{name} is missing"]
        texts[name] = (root / name).read_text(encoding="utf-8")
    problems = compare_tocs(texts)
    listed: set[str] = set()
    for entry in toc_entries(texts[TOCS[0]]):
        if not (root / entry).is_file():
            problems.append(f"{TOCS[0]}: lists {entry}, which does not exist")
            continue
        listed.add(entry)
        if entry.endswith(".xml"):
            for included in xml_includes(root, entry):
                if not (root / included).is_file():
                    problems.append(f"{entry}: includes {included}, which does not exist")
    for path in files:
        if path.endswith(".lua") and path.startswith(ADDON_DIRS) and path not in listed:
            problems.append(f"{path} is not listed in the TOCs, so the client never loads it")
    return problems


def main() -> int:
    files = tracked_files(ROOT)
    problems = check_forbidden(files) + check_seam(ROOT, files) + check_tocs(ROOT, files)
    for problem in problems:
        print(problem)
    print(f"check_repo: {len(files)} files, {len(problems)} problem(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
