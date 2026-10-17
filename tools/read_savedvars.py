"""Read Signpost's SavedVariables (the game -> tools return channel) and print the parts asked for.

    python tools/read_savedvars.py                     summary of SignpostDB and each character's SignpostCharDB
    python tools/read_savedvars.py probe errors        sections of SignpostDB (errors and logs as text, rest as JSON)
    python tools/read_savedvars.py --char Name-Realm progress     a section of one character's SignpostCharDB
    python tools/read_savedvars.py --json --out probe.json probe  write JSON to a file instead of the terminal
    python tools/read_savedvars.py --watch errors      print again whenever the client rewrites the file
    python tools/read_savedvars.py --from incoming/play-machine   read the copy synced from the play machine
    python tools/read_savedvars.py --list              list the files found

The client writes SavedVariables only on /reload, logout or exit. Paths come from tools/dev.local.json.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from signpost_tools import devconfig  # noqa: E402
from signpost_tools.savedvars import LuaParseError  # noqa: E402
from signpost_tools.svfiles import ACCOUNT_VAR, SVFile, find_files, load_db  # noqa: E402

LOG_TAIL = 40

def jsonable(value: object) -> object:
    """JSON keys are strings; Lua tables mix integer and string keys (e.g. { n = 2, [1] = ..., [2] = ... })."""
    if isinstance(value, dict):
        return {str(key): jsonable(item) for key, item in value.items()}
    if isinstance(value, list):
        return [jsonable(item) for item in value]
    return value


def to_json(value: object) -> str:
    return json.dumps(jsonable(value), indent=2, ensure_ascii=False, sort_keys=True, default=str)


def when(epoch: object) -> str:
    if not isinstance(epoch, (int, float)):
        return "?"
    return dt.datetime.fromtimestamp(epoch).strftime("%Y-%m-%d %H:%M:%S")


def file_line(sv: SVFile) -> str:
    stat = sv.path.stat()
    age = time.time() - stat.st_mtime
    return f"{sv.variable} ({sv.owner})  {sv.path}\n  written {when(stat.st_mtime)} ({age / 60:.0f} min ago), {stat.st_size / 1024:.1f} KB"


def size_of(value: object) -> str:
    if isinstance(value, (list, dict)):
        return f"{len(value)} entries"
    return repr(value)


def summary(sv: SVFile, data: dict) -> None:
    print(file_line(sv))
    if not data:
        print("  (empty)")
        return
    if sv.variable == ACCOUNT_VAR:
        load = data.get("lastLoad") or {}
        print(
            f"  lastLoad: Signpost {load.get('version')} on client {load.get('client')} build {load.get('build')}, "
            f"interface {load.get('interface')}, TOC {load.get('toc')}, at {when(load.get('time'))}"
        )
        errors = data.get("errors") or []
        ours = sum(1 for e in errors if isinstance(e, dict) and e.get("ours"))
        print(f"  errors: {len(errors)} recorded ({ours} from Signpost)")
        probe = data.get("probe")
        if isinstance(probe, dict):
            failed = [k for k, v in probe.items() if isinstance(v, dict) and "error" in v]
            print(f"  probe: taken {when(probe.get('time'))}; sections with errors: {failed or 'none'}")
        dump = data.get("mapDump")
        if isinstance(dump, dict):
            print(f"  mapDump: {len(dump.get('maps') or [])} maps, taken {when(dump.get('time'))}")
        debug = data.get("debug") or {}
        print(
            f"  debug: {'on' if debug.get('enabled') else 'off'}; eventLog {len(data.get('eventLog') or [])}, "
            f"posLog {len(data.get('posLog') or [])}"
        )
        ping = data.get("ping")
        if isinstance(ping, dict):
            print(f"  ping: {ping.get('text')!r} at {when(ping.get('time'))}")
    shown = {"lastLoad", "errors", "probe", "mapDump", "debug", "eventLog", "posLog", "ping"}
    rest = ", ".join(f"{k} ({size_of(v)})" for k, v in sorted(data.items()) if k not in shown)
    print(f"  other keys: {rest or 'none'}")


def print_errors(errors: list) -> None:
    print(f"{len(errors)} recorded error(s), oldest first:")
    for entry in errors:
        if not isinstance(entry, dict):
            continue
        tag = " (Signpost)" if entry.get("ours") else ""
        print(f"\n[{entry.get('count', 1)}x]{tag} first {when(entry.get('first'))}, last {when(entry.get('last'))}")
        print(f"  {entry.get('msg')}")
        for line in str(entry.get("stack") or "").splitlines()[:12]:
            print(f"    {line}")


def print_event_log(entries: list) -> None:
    print(f"{len(entries)} event(s) shown:")
    for entry in entries:
        if not isinstance(entry, dict):
            continue
        args = entry.get("a") or {}
        values = args if isinstance(args, list) else [args.get(i) for i in range(1, int(args.get("n", 0)) + 1)]
        count = f" x{entry['count']}" if entry.get("count") else ""
        snapshot = entry.get("s")
        extra = f"  [{', '.join(sorted(snapshot))}]" if isinstance(snapshot, dict) else ""
        print(f"{when(entry.get('time'))}  {entry.get('e')}{count}  {json.dumps(values, ensure_ascii=False)}{extra}")


def show(name: str, value: object, as_json: bool, tail: int | None) -> None:
    if isinstance(value, list) and tail:
        value = value[-tail:]
    if not as_json and name == "errors" and isinstance(value, list):
        print_errors(value)
    elif not as_json and name == "eventLog" and isinstance(value, list):
        print_event_log(value if tail else value[-LOG_TAIL:])
    else:
        print(f"== {name}")
        print(to_json(value))


def read(sv: SVFile) -> dict:
    try:
        return load_db(sv)
    except LuaParseError as exc:
        sys.exit(f"{sv.path}: cannot parse: {exc}")


def run_once(options: argparse.Namespace, files: list[SVFile]) -> None:
    if options.char:
        wanted = options.char.replace(" ", "").lower()
        files = [f for f in files if f.owner.replace(" ", "").lower() == wanted or f.owner.lower().startswith(wanted)]
        if not files:
            sys.exit(f"no SignpostCharDB for {options.char!r}; --list shows what exists")
    else:
        files = files[:1] if options.sections else files
    collected: dict[str, object] = {}
    for sv in files:
        if not sv.path.exists():
            print(f"{sv.variable}: {sv.path} does not exist yet (log in, then /reload)")
            continue
        data = read(sv)
        if not options.sections:
            if options.json:
                collected[sv.owner] = data
            else:
                summary(sv, data)
            continue
        if not options.json:
            print(file_line(sv))
        for name in options.sections:
            if name not in data:
                print(f"== {name}: not present (keys: {', '.join(sorted(data)) or 'none'})")
                continue
            if options.json:
                collected[name] = data[name]
            else:
                show(name, data[name], False, options.tail)
    if options.json:
        if options.tail:
            collected = {k: (v[-options.tail :] if isinstance(v, list) else v) for k, v in collected.items()}
        text = to_json(collected)
        if options.out:
            Path(options.out).write_text(text + "\n", encoding="utf-8")
            print(f"wrote {options.out}")
        else:
            print(text)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("sections", nargs="*", help="top-level keys to print (default: a summary)")
    parser.add_argument("--from", dest="source", type=Path, help="read a copied SavedVariables folder instead")
    parser.add_argument("--config", type=Path, help="dev config (default tools/dev.local.json)")
    parser.add_argument("--char", help="a character's SignpostCharDB, as 'Name - Realm' (or a prefix)")
    parser.add_argument("--json", action="store_true", help="print JSON")
    parser.add_argument("--out", help="with --json: write to this file")
    parser.add_argument("--tail", type=int, help="only the last N entries of list sections")
    parser.add_argument("--watch", action="store_true", help="print again whenever the file changes")
    parser.add_argument("--list", action="store_true", help="list the SavedVariables files found")
    options = parser.parse_args()

    try:
        files = find_files(options.source, options.config)
    except devconfig.ConfigError as exc:
        sys.exit(str(exc))
    if options.list:
        for sv in files:
            state = "present" if sv.path.exists() else "missing"
            print(f"{sv.variable:15} {sv.owner:30} {state:8} {sv.path}")
        return
    run_once(options, files)
    if not options.watch:
        return
    print("\nwatching for changes (Ctrl+C to stop)...")
    seen = {sv.path: sv.path.stat().st_mtime if sv.path.exists() else 0 for sv in files}
    try:
        while True:
            time.sleep(1)
            files = find_files(options.source, options.config)
            current = {sv.path: sv.path.stat().st_mtime if sv.path.exists() else 0 for sv in files}
            if current != seen:
                seen = current
                print(f"\n==== changed at {dt.datetime.now():%H:%M:%S} ====")
                run_once(options, files)
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
