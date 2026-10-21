"""Re-runs the placement simulation: how well Engine/Placement.lua finds a character in each shipped guide (docs/ENGINE.md).

    python tools/placement_report.py                  the tables of docs/ENGINE.md, for the guides as they are now
    python tools/placement_report.py --full           the long tables instead, one per guide and scenario
    python tools/placement_report.py -- --tune        everything after -- goes to tools/placement_report.lua as it is

It needs a Lua 5.1: the test toolchain's (.venv/lua51 of this checkout or of the main checkout) or `lua`, `lua5.1`, `luajit`
on the path. With the private data pack it also writes the levels tools/guide_sim.py walks (tools/placement_levels.py, to
plans/, never committed) and runs the guides against them as a second table; the pack is read, never changed.
Rerun it after a guide is regenerated and paste the tables into docs/ENGINE.md.
"""

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import guide_travel  # noqa: E402
import placement_levels  # noqa: E402

REPO_ROOT = Path(__file__).resolve().parent.parent
REPORT = Path("tools") / "placement_report.lua"
PATH_NAMES = ("lua5.1", "lua", "luajit")


def checkouts(root: Path) -> list[Path]:
    """This checkout and, in a git worktree, the main one (the toolchain is gitignored, so only the main one has it)."""
    found = [root]
    try:
        common = subprocess.run(
            ["git", "rev-parse", "--path-format=absolute", "--git-common-dir"],
            cwd=root,
            capture_output=True,
            text=True,
            check=True,
        ).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        return found
    main = Path(common).parent if common else None
    if main is not None and main.resolve() != root.resolve():
        found.append(main)
    return found


def find_lua(root: Path, which=shutil.which, roots: list[Path] | None = None) -> str | None:
    """The Lua to run the simulation with: the test toolchain's first, then the first on the path."""
    for checkout in roots if roots is not None else checkouts(root):
        for name in ("lua.exe", "lua"):
            candidate = checkout / ".venv" / "lua51" / "bin" / name
            if candidate.is_file():
                return str(candidate)
    for name in PATH_NAMES:
        found = which(name)
        if found:
            return found
    return None


def run_report(lua: str, root: Path, arguments: list[str]) -> int:
    sys.stdout.flush()  # what this script printed so far comes before what Lua prints
    return subprocess.run([lua, str(REPORT), *arguments], cwd=root).returncode


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--root", type=Path, default=REPO_ROOT)
    parser.add_argument("--pack", type=Path)
    parser.add_argument("--full", action="store_true", help="the long tables instead of the compact ones")
    parser.add_argument("--no-sim", action="store_true", help="skip the run against the simulator's levels")
    parser.add_argument("rest", nargs=argparse.REMAINDER, help="after --: arguments for tools/placement_report.lua")
    options = parser.parse_args(argv)
    guide_travel.safe_stdout()
    root = options.root.resolve()
    lua = find_lua(root)
    if lua is None:
        print("no Lua 5.1 found: set up the test toolchain (README, 'Development') or put lua on the path")
        return 1
    passthrough = [item for item in options.rest if item != "--"]
    if passthrough:
        return run_report(lua, root, passthrough)
    shape = [] if options.full else ["--docs"]
    code = run_report(lua, root, shape)
    if code != 0 or options.no_sim:
        return code
    pack_dir = options.pack or guide_travel.default_pack_dir(root)
    if pack_dir is None:
        print()
        print("(no data pack: the run against the simulator's levels is skipped)")
        return 0
    out = root / "plans" / "placement_levels.lua"
    try:
        placement_levels.write_levels(root, pack_dir, out)
    except ValueError as exc:
        print()
        print(f"(the run against the simulator's levels is skipped: {exc})")
        return 0
    print()
    print("Against the levels the simulator walks (tools/guide_sim.py, quest experience from the data pack):")
    print()
    return run_report(lua, root, [*shape, "--truth", "sim", "--levels", str(out)])


if __name__ == "__main__":
    raise SystemExit(main())
