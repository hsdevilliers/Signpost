"""The backlog: what is left over, one Markdown file per item in backlog/ (backlog/README.md has the rules).

    python tools/backlog.py                          the open items, by priority
    python tools/backlog.py list --all               every item; --kind, --area, --source, --status narrow it
    python tools/backlog.py show ID                  one item (ID: the file name without .md, or any part of it that is unique)
    python tools/backlog.py add "Title" --kind finding --source claude --area planner --body-file notes.md
    python tools/backlog.py status ID doing          open or doing
    python tools/backlog.py close ID --resolution "PR #36: what was done"
    python tools/backlog.py drop ID --reason "why" [--agreed "the user, date: what they said"]
    python tools/backlog.py check                    the rules; the tool tests run it on the real backlog, so CI does

An item is a file `backlog/YYYY-MM-DD-slug.md`: front matter (`key: value` lines between two `---` lines) and a Markdown body that says
what it is, why, and when it is done. Items are never deleted; a closed one stays with its resolution.
"""

from __future__ import annotations

import argparse
import datetime
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
BACKLOG = REPO_ROOT / "backlog"

KINDS = ("feature", "bug", "finding", "question", "task", "verify")
STATUSES = ("open", "doing", "done", "dropped")
PRIORITIES = ("high", "normal", "low")
SOURCES = ("user", "claude")
FIELDS = ("title", "kind", "status", "priority", "area", "source", "raised", "raised_in", "closed", "resolution")
REQUIRED = ("title", "kind", "status", "priority", "source", "raised")
NAME = re.compile(r"^(\d{4}-\d{2}-\d{2})-([a-z0-9]+(?:-[a-z0-9]+)*)\.md$")
TAG = re.compile(r"^[a-z0-9][a-z0-9-]*$")
TITLE_LENGTH = 110
SLUG_LENGTH = 60
WIDTH = 112


@dataclass
class Item:
    id: str
    path: Path
    meta: dict
    body: str
    error: str | None = None

    @property
    def status(self) -> str:
        return self.meta.get("status", "")

    @property
    def is_open(self) -> bool:
        return self.status in ("open", "doing")

    @property
    def tags(self) -> list[str]:
        return [t.strip() for t in self.meta.get("area", "").split(",") if t.strip()]


# reading and writing ------------------------------------------------------------------------------------------------------


def parse(text: str) -> tuple[dict, str]:
    """The `key: value` lines between the two `---` lines at the top, and the Markdown after them."""
    lines = text.replace("\r\n", "\n").split("\n")
    if not lines or lines[0].strip() != "---":
        raise ValueError("the file must start with a --- line")
    try:
        end = lines.index("---", 1)
    except ValueError:
        raise ValueError("the front matter has no closing --- line") from None
    meta: dict = {}
    for number, line in enumerate(lines[1:end], 2):
        if not line.strip():
            continue
        key, colon, value = line.partition(":")
        key = key.strip()
        if not colon or not key:
            raise ValueError(f"line {number}: expected 'key: value'")
        if key in meta:
            raise ValueError(f"line {number}: {key} is given twice")
        meta[key] = value.strip()
    return meta, "\n".join(lines[end + 1 :]).strip("\n")


def render(meta: dict, body: str) -> str:
    """The file text: known fields in a fixed order (empty optional ones left out), then any others, then the body."""
    lines = ["---"]
    for key in FIELDS:
        if key in meta and (meta[key] or key in REQUIRED):
            lines.append(f"{key}: {meta[key]}")
    lines += [f"{key}: {value}" for key, value in meta.items() if key not in FIELDS]
    lines += ["---", "", body.strip("\n"), ""]
    return "\n".join(lines)


def load(root: Path = BACKLOG) -> list[Item]:
    items = []
    for path in sorted(root.glob("*.md")) if root.is_dir() else []:
        if path.name.lower() == "readme.md":
            continue
        text = path.read_text(encoding="utf-8")
        try:
            meta, body = parse(text)
            items.append(Item(path.stem, path, meta, body))
        except ValueError as error:
            items.append(Item(path.stem, path, {}, text, str(error)))
    return items


def save(item: Item) -> None:
    item.path.write_text(render(item.meta, item.body), encoding="utf-8", newline="\n")


def find(items: list[Item], ident: str) -> Item:
    """The item with this id, or the only one whose id contains it."""
    exact = [i for i in items if i.id == ident]
    if exact:
        return exact[0]
    part = [i for i in items if ident in i.id]
    if len(part) == 1:
        return part[0]
    if not part:
        raise SystemExit(f"no item matches {ident!r} (python tools/backlog.py list --all)")
    raise SystemExit(f"{ident!r} matches several items: " + ", ".join(i.id for i in part))


# the rules ----------------------------------------------------------------------------------------------------------------


def _date(text: str) -> datetime.date | None:
    try:
        return datetime.date.fromisoformat(text)
    except ValueError:
        return None


def problems(item: Item) -> list[str]:
    """What is wrong with one item (empty when it follows the rules in backlog/README.md)."""
    if item.error:
        return [item.error]
    found: list[str] = []
    meta = item.meta
    named = NAME.match(item.path.name)
    if not named:
        found.append("the file name must be YYYY-MM-DD-slug.md (the date, then lower-case words joined by -)")
    for key in meta:
        if key not in FIELDS:
            found.append(f"{key}: not a field (fields: {', '.join(FIELDS)})")
    for key in REQUIRED:
        if not meta.get(key):
            found.append(f"{key}: missing")
    for key, allowed in (("kind", KINDS), ("status", STATUSES), ("priority", PRIORITIES), ("source", SOURCES)):
        if meta.get(key) and meta[key] not in allowed:
            found.append(f"{key}: {meta[key]!r} is not one of {', '.join(allowed)}")
    if len(meta.get("title", "")) > TITLE_LENGTH:
        found.append(f"title: longer than {TITLE_LENGTH} characters (put the detail in the body)")
    for tag in item.tags:
        if not TAG.match(tag):
            found.append(f"area: {tag!r} is not a lower-case tag (letters, digits and -)")
    raised = _date(meta.get("raised", ""))
    if meta.get("raised") and raised is None:
        found.append("raised: not a date (YYYY-MM-DD)")
    if named and raised is not None and named.group(1) != raised.isoformat():
        found.append(f"raised: {raised} does not match the date in the file name")
    closing = meta.get("status") in ("done", "dropped")
    if closing:
        closed = _date(meta.get("closed", ""))
        if closed is None:
            found.append("closed: a closed item needs the date it was closed (YYYY-MM-DD)")
        elif raised is not None and closed < raised:
            found.append("closed: before it was raised")
        if not meta.get("resolution"):
            found.append("resolution: a closed item says what was done, or why it was dropped")
        agreed = meta.get("resolution", "").lower().startswith("the user agreed")
        if meta.get("status") == "dropped" and meta.get("source") == "user" and not agreed:
            found.append("resolution: an item the user raised is dropped only with their agreement ('the user agreed ...')")
    else:
        for key in ("closed", "resolution"):
            if meta.get(key):
                found.append(f"{key}: only a done or dropped item has one")
    if not any(line.strip() and not line.lstrip().startswith("#") for line in item.body.splitlines()):
        found.append("body: empty (say what it is, why, and when it is done)")
    return found


def check(root: Path = BACKLOG) -> list[str]:
    return [f"{item.path.name}: {text}" for item in load(root) for text in problems(item)]


# commands -----------------------------------------------------------------------------------------------------------------


def slugify(title: str) -> str:
    words = re.sub(r"[^a-z0-9]+", "-", title.lower()).strip("-")
    if len(words) > SLUG_LENGTH:
        cut = words[:SLUG_LENGTH]
        words = cut if words[SLUG_LENGTH] == "-" else cut.rsplit("-", 1)[0]  # whole words only
    return words or "item"


def today() -> datetime.date:
    return datetime.date.today()


def add(
    root: Path,
    title: str,
    kind: str,
    source: str,
    body: str,
    priority: str = "normal",
    area: str = "",
    raised_in: str = "",
    date: datetime.date | None = None,
) -> Item:
    date = date or today()
    name = f"{date.isoformat()}-{slugify(title)}"
    candidate, n = name, 1
    while (root / f"{candidate}.md").exists():
        n += 1
        candidate = f"{name}-{n}"
    meta = {
        "title": title.strip(),
        "kind": kind,
        "status": "open",
        "priority": priority,
        "area": ", ".join(t.strip() for t in area.split(",") if t.strip()),
        "source": source,
        "raised": date.isoformat(),
        "raised_in": raised_in.strip(),
    }
    root.mkdir(parents=True, exist_ok=True)
    item = Item(candidate, root / f"{candidate}.md", meta, body.strip("\n"))
    wrong = problems(item)
    if wrong:
        raise SystemExit("not added: " + "; ".join(wrong))
    save(item)
    return item


def close(item: Item, resolution: str, date: datetime.date | None = None) -> None:
    if not item.is_open:
        raise SystemExit(f"{item.id} is already {item.status}")
    item.meta.update(status="done", closed=(date or today()).isoformat(), resolution=resolution.strip())
    wrong = problems(item)
    if wrong:
        raise SystemExit("not closed: " + "; ".join(wrong))
    save(item)


def drop(item: Item, reason: str, agreed: str = "", date: datetime.date | None = None) -> None:
    if not item.is_open:
        raise SystemExit(f"{item.id} is already {item.status}")
    if item.meta.get("source") == "user" and not agreed.strip():
        raise SystemExit(f'{item.id} was raised by the user: drop it only after they agree (--agreed "the user, date: what they said")')
    resolution = f"the user agreed ({agreed.strip()}): {reason.strip()}" if agreed.strip() else reason.strip()
    item.meta.update(status="dropped", closed=(date or today()).isoformat(), resolution=resolution)
    wrong = problems(item)
    if wrong:
        raise SystemExit("not dropped: " + "; ".join(wrong))
    save(item)


def set_status(item: Item, status: str) -> None:
    if not item.is_open:
        raise SystemExit(f"{item.id} is {item.status}: it is closed (items are not reopened; add a new one that points to it)")
    item.meta["status"] = status
    save(item)


def select(items: list[Item], args: argparse.Namespace) -> list[Item]:
    chosen = []
    for item in items:
        if args.status and item.status != args.status:
            continue
        if not args.status and not args.all and not item.is_open:
            continue
        if args.kind and item.meta.get("kind") != args.kind:
            continue
        if args.source and item.meta.get("source") != args.source:
            continue
        if args.area and args.area not in item.tags:
            continue
        chosen.append(item)
    order = {name: n for n, name in enumerate(PRIORITIES)}
    # open first, by priority, what the user raised before what Claude found, then by id (the date it was raised)
    return sorted(chosen, key=lambda i: (not i.is_open, order.get(i.meta.get("priority", ""), 9), i.meta.get("source") != "user", i.id))


def listing(items: list[Item], everything: bool) -> list[str]:
    if not items:
        return ["nothing here" + ("" if everything else " (python tools/backlog.py list --all shows the closed items too)")]
    lines = []
    heading = None
    for item in items:
        group = item.meta.get("priority", "?") if item.is_open else "closed"
        if group != heading:
            heading = group
            lines += ["", f"{group}" + (" priority" if group in PRIORITIES else "")]
        meta = item.meta
        status = "" if item.status == "open" else f" [{item.status}]"
        lines.append(f"  {item.id}{status}")
        detail = f"{meta.get('kind', '?')}, {meta.get('source', '?')}" + (f"; {meta['area']}" if meta.get("area") else "")
        title = meta.get("title", "(no title)")
        text = f"{title}  ({detail})"
        lines += ["    " + line for line in _wrap(text, WIDTH - 4)]
    return lines[1:] if lines and not lines[0] else lines


def _wrap(text: str, width: int) -> list[str]:
    lines, line = [], ""
    for word in text.split():
        if line and len(line) + len(word) + 1 > width:
            lines.append(line)
            line = ""
        line = f"{line} {word}".strip()
    return lines + ([line] if line else [])


# the command line ---------------------------------------------------------------------------------------------------------


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--root", type=Path, default=BACKLOG, help="the backlog folder (default backlog/)")
    commands = parser.add_subparsers(dest="command")

    show = commands.add_parser("list", help="the open items, by priority")
    show.add_argument("--all", action="store_true", help="the closed items too")
    show.add_argument("--status", choices=STATUSES)
    show.add_argument("--kind", choices=KINDS)
    show.add_argument("--source", choices=SOURCES)
    show.add_argument("--area", help="one area tag")

    one = commands.add_parser("show", help="one item")
    one.add_argument("id")

    new = commands.add_parser("add", help="write a new item")
    new.add_argument("title")
    new.add_argument("--kind", required=True, choices=KINDS)
    new.add_argument("--source", required=True, choices=SOURCES, help="user: they told you to note it; claude: your own finding")
    new.add_argument("--priority", default="normal", choices=PRIORITIES)
    new.add_argument("--area", default="", help="tags, comma separated: engine, ui, guides, drafter, planner, ...")
    new.add_argument("--raised-in", default="", help="where it came up: a PR, a session, a file")
    new.add_argument("--body", help="the text: what it is, why, when it is done")
    new.add_argument("--body-file", type=Path, help="the same, from a file")
    new.add_argument("--date", type=datetime.date.fromisoformat, help="the date raised (default today)")

    status = commands.add_parser("status", help="mark an item open or doing")
    status.add_argument("id")
    status.add_argument("status", choices=("open", "doing"))

    done = commands.add_parser("close", help="an item is done")
    done.add_argument("id")
    done.add_argument("--resolution", required=True, help="what was done and where (a PR, a commit)")
    done.add_argument("--date", type=datetime.date.fromisoformat)

    dropped = commands.add_parser("drop", help="an item will not be done")
    dropped.add_argument("id")
    dropped.add_argument("--reason", required=True)
    dropped.add_argument("--agreed", default="", help="required for an item the user raised: who agreed, when, what they said")
    dropped.add_argument("--date", type=datetime.date.fromisoformat)

    commands.add_parser("check", help="the rules; exit 1 when an item breaks one")
    return parser


def main(argv: list[str] | None = None) -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    parser = build_parser()
    args = parser.parse_args(argv)
    if args.command is None:  # no command: the open items
        args = parser.parse_args([*(sys.argv[1:] if argv is None else argv), "list"])
    root, command = args.root, args.command
    if command == "list":
        items = load(root)
        chosen = select(items, args)
        print(f"backlog: {sum(1 for i in items if i.is_open)} open, {len(items) - sum(1 for i in items if i.is_open)} closed")
        print("\n".join(listing(chosen, args.all or bool(args.status))))
        return 0
    if command == "check":
        wrong = check(root)
        print("\n".join(wrong))
        print(f"backlog: {len(load(root))} item(s), {len(wrong)} problem(s)")
        return 1 if wrong else 0
    if command == "add":
        body = args.body if args.body is not None else (args.body_file.read_text(encoding="utf-8") if args.body_file else "")
        if not body.strip():
            raise SystemExit("an item needs its text: --body TEXT or --body-file PATH (what it is, why, when it is done)")
        item = add(root, args.title, args.kind, args.source, body, args.priority, args.area, args.raised_in, args.date)
        print(f"added {item.id}")
        return 0
    item = find(load(root), args.id)
    if command == "show":
        print(item.path.read_text(encoding="utf-8").rstrip("\n"))
    elif command == "status":
        set_status(item, args.status)
        print(f"{item.id}: {args.status}")
    elif command == "close":
        close(item, args.resolution, args.date)
        print(f"{item.id}: done")
    elif command == "drop":
        drop(item, args.reason, args.agreed, args.date)
        print(f"{item.id}: dropped")
    return 0


if __name__ == "__main__":
    sys.exit(main())
