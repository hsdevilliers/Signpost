"""Compare the quests the game offered in recorded sessions with what the availability rules predict (docs/AVAILABILITY.md).

    python tools/validate_availability.py                       the dev client's SavedVariables
    python tools/validate_availability.py --from incoming/play-machine
    python tools/validate_availability.py --race Troll --class HUNTER      when no character's guide says who played
    python tools/validate_availability.py --assume-level 1      for sessions recorded before the level was (see below)

Every quest giver visit the recorder logged (`GOSSIP_SHOW` and `QUEST_GREETING` in SignpostDB.eventLog, Core/Debug.lua) lists
the quests the game offered. The same visit is replayed against the rules for the character at the level it had, with the
quests it had turned in (the recorder keeps the level and the completed IDs of each visit; an older log is replayed from
QUEST_ACCEPTED, QUEST_TURNED_IN and an assumed level):
  - a quest the rules offer and the game did not is a data gap: the rules are too generous (the Burning Blade Medallion);
  - a quest the game offered and the rules do not is a wrong rule or a field the pack does not carry.
Exit code 1 when any visit disagrees.
"""

from __future__ import annotations

import argparse
import sys
from dataclasses import dataclass, field
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import guide_travel  # noqa: E402
from signpost_tools import availability, guidefile, svfiles  # noqa: E402

REPO_ROOT = Path(__file__).resolve().parent.parent


@dataclass
class Visit:
    npc: int | None
    name: str
    level: int
    done: int
    observed: set[int]
    predicted: set[int]
    when: int | None = None
    notes: list[str] = field(default_factory=list)

    @property
    def extra(self) -> set[int]:
        """Offered by the game, not predicted."""
        return self.observed - self.predicted

    @property
    def missing(self) -> set[int]:
        """Predicted, not offered by the game."""
        return self.predicted - self.observed

    @property
    def agrees(self) -> bool:
        return not self.extra and not self.missing


def _ints(value: object) -> list[int]:
    if isinstance(value, dict):
        value = list(value.values())
    return [item for item in value or [] if isinstance(item, int) and not isinstance(item, bool)]


def _quest_ids(entries: object, greeting: bool) -> set[int]:
    """The quest IDs of an `available` or `active` list: gossip entries carry `questID`; a greeting entry carries the values
    of GetAvailableQuestInfo in `info` (isTrivial, frequency, isRepeatable, isLegendary, questID) or `questID`."""
    found: set[int] = set()
    items = list(entries.values()) if isinstance(entries, dict) else entries or []
    for entry in items:
        if not isinstance(entry, dict):
            continue
        quest = entry.get("questID")
        if not isinstance(quest, int) and greeting:
            info = entry.get("info")
            info = list(info.values()) if isinstance(info, dict) else info
            quest = info[4] if isinstance(info, list) and len(info) >= 5 else None
        if isinstance(quest, int) and not isinstance(quest, bool):
            found.add(quest)
    return found


def predicted_offers(rules: availability.Rules, npc: int, level: int, done: set[int], active: set[int]) -> set[int]:
    """The quests this NPC starts that the rules offer now (a quest done or in the log is not offered again)."""
    return {
        qid
        for qid, record in rules.quests.items()
        if isinstance(record, dict)
        and npc in _ints((record.get("s") or {}).get("npc"))
        and qid not in done
        and qid not in active
        and rules.offered(qid, level, done, active)
    }


def replay(events: list, rules: availability.Rules, assume_level: int = 1) -> list[Visit]:
    """Walk the event log in order, keeping what the character turned in and holds, and compare each quest giver visit."""
    done: set[int] = set()
    active: set[int] = set()
    level = assume_level
    visits: list[Visit] = []
    for event in events:
        if not isinstance(event, dict):
            continue
        name = event.get("e")
        args = event.get("a") if isinstance(event.get("a"), dict) else {}
        state = event.get("s") if isinstance(event.get("s"), dict) else {}
        if name == "QUEST_ACCEPTED" and isinstance(args.get("1"), int):
            active.add(args["1"])
        elif name == "QUEST_TURNED_IN" and isinstance(args.get("1"), int):
            done.add(args["1"])
            active.discard(args["1"])
        elif name == "QUEST_REMOVED" and isinstance(args.get("1"), int):
            active.discard(args["1"])
        elif name == "PLAYER_LEVEL_UP" and isinstance(args.get("1"), int):
            level = args["1"]
        elif name in ("GOSSIP_SHOW", "QUEST_GREETING"):
            standing = state.get("standing") if isinstance(state.get("standing"), dict) else {}
            if isinstance(standing.get("level"), int):
                level = standing["level"]
            completed = standing.get("completed")
            if completed is not None:
                done = set(_ints(completed))
            greeting = name == "QUEST_GREETING"
            npc_record = state.get("npc") if isinstance(state.get("npc"), dict) else {}
            npc = npc_record.get("id")
            if not isinstance(npc, int):
                continue
            active |= _quest_ids(state.get("active"), greeting)
            observed = _quest_ids(state.get("available"), greeting)
            visit = Visit(
                npc,
                str(npc_record.get("name") or npc),
                level,
                len(done),
                observed,
                predicted_offers(rules, npc, level, done, active),
                event.get("time") if isinstance(event.get("time"), int) else None,
            )
            if not isinstance(standing.get("level"), int):
                visit.notes.append(f"level not recorded: assumed {level}")
            if completed is None:
                visit.notes.append("quests turned in not recorded: replayed from the log")
            visits.append(visit)
    return visits


def character_of_guide(project: guidefile.Project, guide_id: str) -> availability.Character | None:
    guide = project.guides.get(guide_id)
    if guide is None or not guide.races or not guide.classes:
        return None
    race, cls = guide.races[0], guide.classes[0]
    return availability.Character(guide.faction, availability.race_bit(race, guide.faction), availability.class_bit(cls))


def report(visits: list[Visit], quests: dict, who: str) -> list[str]:
    def label(qid: int) -> str:
        record = quests.get(qid)
        name = record.get("n") if isinstance(record, dict) else None
        return f'{qid} "{name}"' if name else str(qid)

    out = [f"== {who}: {len(visits)} quest giver visit(s) compared"]
    for visit in visits:
        mark = "ok  " if visit.agrees else "DIFF"
        offered = ", ".join(label(q) for q in sorted(visit.observed)) or "nothing"
        out.append(f"   {mark} {visit.name} ({visit.npc}) at level {visit.level}, {visit.done} quest(s) turned in: the game offered {offered}")
        for qid in sorted(visit.missing):
            out.append(f"        the rules offer {label(qid)} and the game did not: a data gap")
        for qid in sorted(visit.extra):
            reasons = visit_reasons(quests, qid)
            out.append(f"        the game offered {label(qid)} and the rules do not{reasons}")
        for note in visit.notes:
            out.append(f"        note: {note}")
    agree = sum(1 for visit in visits if visit.agrees)
    out.append(f"   {agree} of {len(visits)} agree")
    return out


def visit_reasons(quests: dict, qid: int) -> str:
    return "" if qid in quests else " (the pack does not know it)"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--root", type=Path, default=REPO_ROOT)
    parser.add_argument("--pack", type=Path, help="the data pack folder (default: ../Signpost_Data)")
    parser.add_argument("--from", dest="source", type=Path, help="a copied SavedVariables folder instead of the dev client's")
    parser.add_argument("--faction", default=None, help="Horde or Alliance, when no guide names the character")
    parser.add_argument("--race", help="raceFile token, when no guide names the character")
    parser.add_argument("--class", dest="cls", help="classFile token, when no guide names the character")
    parser.add_argument("--assume-level", type=int, default=1, help="the level of visits recorded without one (default 1)")
    options = parser.parse_args(argv)
    guide_travel.safe_stdout()

    pack = guide_travel.load_pack(options.pack or guide_travel.default_pack_dir(options.root))
    if not pack.present:
        print("validate_availability needs the data pack: " + pack.describe())
        return 1
    quests = pack.table("quests")
    project = guidefile.load_project(options.root)
    files = svfiles.find_files(options.source)
    account = next((sv for sv in files if sv.variable == svfiles.ACCOUNT_VAR and sv.path.is_file()), None)
    events = svfiles.load_db(account).get("eventLog") if account else None
    events = list(events.values()) if isinstance(events, dict) else events
    if not events:
        print("no event log recorded: play with a development build (or /signpost debug on), then /reload")
        return 0
    who = "the played character"
    character = None
    if options.race and options.cls:
        faction = options.faction or "Horde"
        character = availability.Character(faction, availability.race_bit(options.race, faction), availability.class_bit(options.cls))
        who = f"{faction} {options.race} {options.cls}"
    else:
        for sv in files:
            if sv.variable != svfiles.CHAR_VAR or not sv.path.is_file():
                continue
            progress = svfiles.load_db(sv).get("progress")
            for guide_id in progress if isinstance(progress, dict) else []:
                character = character_of_guide(project, guide_id)
                if character:
                    who = f"{sv.owner} ({guide_id})"
                    break
            if character:
                break
    if character is None:
        print("no character to check: pass --race and --class (and --faction)")
        return 1
    visits = replay(events, availability.Rules(quests, character), options.assume_level)
    print("\n".join(report(visits, quests, who)))
    return 0 if all(visit.agrees for visit in visits) else 1


if __name__ == "__main__":
    sys.exit(main())
