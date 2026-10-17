"""Build the release zip of the public addon: dist/Signpost-<version>.zip containing one Signpost/ folder.

    python tools/package.py --version v0.1.0 [--out dist]

Ships every file git tracks except dotfiles, .gitkeep placeholders and the `ignore:` list in .pkgmeta; replaces
@project-version@ in the TOCs. The private data pack is a separate addon and is never packaged.
"""

from __future__ import annotations

import argparse
import subprocess
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ADDON = "Signpost"


def pkgmeta_ignores(text: str) -> list[str]:
    """The `ignore:` list of a .pkgmeta file (only the simple `  - item` form is used here)."""
    ignores, inside = [], False
    for line in text.splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if not line.startswith((" ", "\t")):
            inside = line.split(":")[0].strip() == "ignore"
            continue
        if inside and line.strip().startswith("- "):
            ignores.append(line.strip()[2:].strip().rstrip("/"))
    return ignores


def shipped_files(files: list[str], ignores: list[str]) -> list[str]:
    def ignored(path: str) -> bool:
        if any(part.startswith(".") for part in path.split("/")):
            return True
        return any(path == item or path.startswith(item + "/") for item in ignores)

    return sorted(path for path in files if not ignored(path))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--version", required=True)
    parser.add_argument("--out", type=Path, default=ROOT / "dist")
    options = parser.parse_args()

    listing = subprocess.run(["git", "ls-files", "-z"], cwd=ROOT, capture_output=True, text=True, check=True).stdout
    files = [path for path in listing.split("\0") if path]
    ignores = pkgmeta_ignores((ROOT / ".pkgmeta").read_text(encoding="utf-8"))
    shipped = shipped_files(files, ignores)
    options.out.mkdir(parents=True, exist_ok=True)
    target = options.out / f"{ADDON}-{options.version}.zip"
    with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED) as archive:
        for path in shipped:
            data = (ROOT / path).read_bytes()
            if path.endswith(".toc"):
                data = data.replace(b"@project-version@", options.version.encode())
            archive.writestr(f"{ADDON}/{path}", data)
    print(f"wrote {target} ({len(shipped)} files)")


if __name__ == "__main__":
    sys.exit(main())
