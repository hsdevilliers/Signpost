"""Run Lua 5.1 code locally without a Lua toolchain, using the lupa runtime from the repo's .venv.

    python tools/lua.py test [PATTERN]     run tests/*_spec.lua (optionally only files containing PATTERN)
    python tools/lua.py run FILE [ARGS]    run a Lua file with `arg` set, like `lua5.1 FILE ARGS`

The test runner (tests/run.lua) is a small busted stand-in that uses luassert, the assertion library busted itself
uses; CI runs real busted. One-time setup (all under the gitignored .venv):

    python -m venv .venv
    .venv/Scripts/python -m pip install lupa
    git clone --depth 1 --branch v1.9.0 https://github.com/lunarmodules/luassert .venv/lua-src/luassert
    git clone --depth 1 --branch v1.4.1 https://github.com/lunarmodules/say .venv/lua-src/say
    copy .venv/lua-src/luassert/src -> .venv/lua/luassert, .venv/lua-src/say/src/say -> .venv/lua/say
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def lua_runtime():
    try:
        from lupa import lua51
    except ImportError:
        sys.exit("lupa is not installed: run tools/lua.py with .venv/Scripts/python (see the docstring for setup)")
    runtime = lua51.LuaRuntime()
    runtime.execute("package.path = '.venv/lua/?.lua;.venv/lua/?/init.lua;./?.lua;./?/init.lua;' .. package.path")
    return runtime


def run_file(path: str, args: list[str]) -> None:
    runtime = lua_runtime()
    runtime.globals().arg = runtime.table_from({i: a for i, a in enumerate([path, *args])})
    runtime.execute("local f = assert(loadfile(arg[0])); f(unpack(arg))")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)
    test = sub.add_parser("test", help="run tests/*_spec.lua")
    test.add_argument("pattern", nargs="?", default="")
    run = sub.add_parser("run", help="run a Lua file")
    run.add_argument("file")
    run.add_argument("args", nargs="*")
    options = parser.parse_args()

    os.chdir(ROOT)
    if options.command == "test":
        specs = sorted(str(p.relative_to(ROOT).as_posix()) for p in (ROOT / "tests").rglob("*_spec.lua"))
        specs = [s for s in specs if options.pattern in s]
        if not specs:
            sys.exit(f"no spec files match {options.pattern!r}")
        run_file("tests/run.lua", specs)
    else:
        run_file(options.file, options.args)


if __name__ == "__main__":
    main()
