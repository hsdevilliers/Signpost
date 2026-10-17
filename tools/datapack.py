"""Maintain the private data pack addon (../Signpost_Data).

    python tools/datapack.py init --out ../Signpost_Data    write the empty stub (TOC, _meta.lua, empty tables)

The Phase 1 exporters (tools/wowhead_*.py) fill the same files through signpost_tools.datapack.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from signpost_tools import datapack  # noqa: E402


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)
    init = sub.add_parser("init", help="write an empty stub pack")
    init.add_argument("--out", type=Path, default=Path(__file__).resolve().parents[2] / "Signpost_Data")
    init.add_argument("--force", action="store_true", help="replace a pack that holds exported data")
    options = parser.parse_args()

    if options.command == "init":
        try:
            written = datapack.init_stub(options.out, options.force)
        except RuntimeError as exc:
            sys.exit(str(exc))
        for path in written:
            print(f"wrote {path}")


if __name__ == "__main__":
    main()
