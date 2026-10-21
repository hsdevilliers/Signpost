"""Audit the quests the game offered in recorded play against the data pack and the guides (docs/AVAILABILITY.md).

    python tools/audit_quests.py                           the dev client's SavedVariables
    python tools/audit_quests.py --from incoming/play-machine
    python tools/audit_quests.py --guide horde-windshaper-druid
    python tools/audit_quests.py --strict                  exit 1 when the pack lacks a quest the game offered

The recorder (`/signpost debug on`, Core/Debug.lua) logs every quest giver visit (GOSSIP_SHOW and QUEST_GREETING list the quests offered
and the quests already in the log), every quest dialog opened (QUEST_DETAIL) and every quest accepted or turned in, and Core/Learn.lua
links the quests the player accepted or handed in to the NPC or object that gave them (SignpostDB.learned.quests). Each quest seen this
way is looked up:
  - in the data pack: a quest the pack does not know is a DATA GAP (a Forever-new quest, or one the importer dropped). It is listed with
    the title the game gave, who offered it and where the player stood;
  - in each guide: a quest the pack knows, that the guide's character can take, in a zone the guide's route visits, and that neither the
    route accepts nor a `#skipquest` names is a gap in the ROUTE. The reason the rules give is printed (repeatable, a world event, a
    profession, a level above the guide's last chapter, a closed prerequisite); a quest nothing explains was left out by the planner or the
    drafter, whose report says why (docs/PLANNER.md).
The account file mixes the characters that played, and the pack's Forever quests often carry no race or class limit, so a quest is judged
against a guide only when that guide's character (faction, race, class) could take it AND the route goes to the quest's zone; the rest
are counted as other characters' or as elsewhere.
"""

from __future__ import annotations

import argparse
import sys
from argparse import Namespace
from dataclasses import dataclass, field
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import guide_lint  # noqa: E402
import guide_sim  # noqa: E402
import guide_travel  # noqa: E402
from signpost_tools import availability, guidefile, svfiles  # noqa: E402

REPO_ROOT = Path(__file__).resolve().parent.parent
Spot = tuple[int, float, float]


@dataclass
class Seen:
    """One quest the recorder saw, and what it knows about it."""

    quest: int
    titles: set[str] = field(default_factory=set)
    how: set[str] = field(default_factory=set)  # offered, opened, accepted, turned in, in the log, learned
    givers: set[str] = field(default_factory=set)  # "Gornek (3143)": who offered it, took it back, or was linked to it
    spot: Spot | None = None  # where the player first stood when it was seen (uiMapID, x, y)

    @property
    def title(self) -> str:
        return sorted(self.titles)[0] if self.titles else ""


@dataclass
class GuideAudit:
    """What one guide does with the quests that were seen and that its character can take."""

    guide: str
    name: str
    top: int  # the guide's last chapter level
    covered: list[int] = field(default_factory=list)  # the route accepts them
    skipped: dict[int, str] = field(default_factory=dict)  # `#skipquest`, with its reason
    out_of_scope: dict[int, str] = field(default_factory=dict)  # the rules explain why a route does not take them
    missing: list[int] = field(default_factory=list)  # nothing explains it: the planner or the drafter left them out
    others: list[int] = field(default_factory=list)  # for another faction, race or class
    elsewhere: list[int] = field(default_factory=list)  # in a zone the route never goes to


@dataclass
class Audit:
    seen: dict[int, Seen]
    data_gaps: list[int]
    guides: list[GuideAudit]
    events: int = 0
    learned: int = 0


# What was seen ---------------------------------------------------------------------------------------------------------


def _id(value: object) -> int | None:
    return value if isinstance(value, int) and not isinstance(value, bool) and value > 0 else None


def _listed(value: object) -> list:
    """A Lua array as a list (an empty table parses as a dict; a table keyed 1..n as a list)."""
    if isinstance(value, dict):
        return [value[key] for key in sorted(k for k in value if isinstance(k, int))] or list(value.values())
    return list(value) if isinstance(value, list) else []


def _offers(entries: object, greeting: bool) -> list[tuple[int, str | None]]:
    """(quest, title) of an `available` or `active` list: a gossip entry carries `questID`; a greeting entry carries the values of
    GetAvailableQuestInfo in `info` (isTrivial, frequency, isRepeatable, isLegendary, questID)."""
    found = []
    for entry in _listed(entries):
        if not isinstance(entry, dict):
            continue
        quest = _id(entry.get("questID"))
        if quest is None and greeting:
            info = _listed(entry.get("info"))
            quest = _id(info[4]) if len(info) >= 5 else None
        if quest is not None:
            title = entry.get("title")
            found.append((quest, title if isinstance(title, str) and title else None))
    return found


def _spot(pos: object) -> Spot | None:
    if not isinstance(pos, dict):
        return None
    map_id, x, y = _id(pos.get("map")), pos.get("x"), pos.get("y")
    numbers = all(isinstance(v, (int, float)) and not isinstance(v, bool) for v in (x, y))
    return (map_id, float(x), float(y)) if map_id and numbers else None


def collect(events: list, learned: dict | None = None) -> dict[int, Seen]:
    """Every quest the recorded events and the learned records mention, with how it was seen."""
    found: dict[int, Seen] = {}

    def note(quest: int | None, how: str, title: str | None = None, npc: object = None) -> None:
        if quest is None:
            return
        seen = found.setdefault(quest, Seen(quest))
        seen.how.add(how)
        if title:
            seen.titles.add(title)
        if isinstance(npc, dict):
            who, name = _id(npc.get("id")), npc.get("name")
            if who:
                seen.givers.add(f"{name} ({who})" if isinstance(name, str) and name else f"npc {who}")
            if seen.spot is None:
                seen.spot = _spot(npc.get("pos"))

    for event in events:
        if not isinstance(event, dict):
            continue
        name = event.get("e")
        state = event.get("s") if isinstance(event.get("s"), dict) else {}
        npc = state.get("npc")
        if name in ("GOSSIP_SHOW", "QUEST_GREETING"):
            greeting = name == "QUEST_GREETING"
            for quest, title in _offers(state.get("available"), greeting):
                note(quest, "offered", title, npc)
            for quest, title in _offers(state.get("active"), greeting):
                note(quest, "in the log", title, npc)
        elif name == "QUEST_DETAIL":
            note(_id(state.get("questID")), "opened", state.get("title"), npc)
        elif name in ("QUEST_ACCEPTED", "QUEST_TURNED_IN"):
            info = (state.get("quest") or {}).get("info") if isinstance(state.get("quest"), dict) else None
            title = info.get("title") if isinstance(info, dict) else None
            note(_id(svfiles.event_arg(event.get("a"), 1)), "accepted" if name == "QUEST_ACCEPTED" else "turned in", title, npc)

    for quest, record in learned_quests(learned).items():
        note(quest, "learned")
        npcs = (learned or {}).get("npcs") if isinstance((learned or {}).get("npcs"), dict) else {}
        for part in ("start", "finish"):
            who = record.get(part) if isinstance(record.get(part), dict) else {}
            if _id(who.get("npc")):
                ident = who["npc"]
                known = npcs.get(ident, {}).get("n") if isinstance(npcs.get(ident), dict) else None
                found[quest].givers.add(f"{known} ({ident})" if known else f"npc {ident}")
            if _id(who.get("obj")):
                found[quest].givers.add(f"object {who['obj']}")
    return found


def learned_quests(learned: object) -> dict[int, dict]:
    """SignpostDB.learned.quests as {quest: {start = {npc|obj = id}, finish = ..., t = time}}, whatever the parser made of the table."""
    records = learned.get("quests") if isinstance(learned, dict) else None
    if isinstance(records, list):  # a table keyed exactly 1..n
        records = {index + 1: item for index, item in enumerate(records)}
    if not isinstance(records, dict):
        return {}
    return {quest: (record if isinstance(record, dict) else {}) for key, record in records.items() if (quest := _id(key))}


# The pack and the guides -----------------------------------------------------------------------------------------------


def why_not_routed(record: dict, rules: availability.Rules, qid: int, top: int) -> str | None:
    """A reason the rules give for a route not taking this quest (None: nothing explains it)."""
    if record.get("repeatable"):
        return "repeatable (a daily or a repeat)"
    if record.get("sort") in availability.EVENT_SORTS:
        return "a seasonal or world event"
    if record.get("skill"):
        return "needs a profession skill"
    if (record.get("r") or 0) > top:
        return f"needs level {record['r']}; the guide's last chapter is level {top}"
    if rules.never(qid):
        return "a prerequisite is closed to this character"
    return None


def audit_guide(
    project: guidefile.Project, pack: guide_travel.Pack, guide: guidefile.Guide, seen: set[int], world_for
) -> GuideAudit:
    quests = pack.table("quests")
    skill_lines = {key: module.skill_line for key, module in project.professions.items() if module.skill_line}
    options = Namespace(faction=None, race=None, cls=None, profession=[], no_tracks=False)
    routes = guide_travel.guide_routes(project, guide, options, world_for)
    accepted = {d.args["quest"] for route in routes for rs in route.steps for d in rs.all_directives() if d.name == "accept"}
    skips = {quest: reason for route in routes for quest, (reason, _, _) in route.skip_quests.items()}
    rules = [availability.Rules(quests, guide_sim.character_of(route, skill_lines)) for route in routes]
    top = max([route.max_level() for route in routes] or [0]) or guide.levels[1]
    zones = {
        world_for(route.variant.faction).zone(ident)
        for route in routes
        for rs in route.steps
        for d in rs.all_directives()
        for kind, ident in guide_lint.ids_in(d)
        if kind == "map"
    }
    world = world_for(routes[0].variant.faction) if routes else None
    audit = GuideAudit(guide.id, guide.name, top)
    for qid in sorted(seen):
        record = quests.get(qid)
        if not isinstance(record, dict):
            continue
        if qid in accepted:
            audit.covered.append(qid)
        elif all(r.mask_block(qid) for r in rules):
            audit.others.append(qid)
        elif qid in skips:
            audit.skipped[qid] = skips[qid]
        elif reason := next((why for r in rules if (why := why_not_routed(record, r, qid, top))), None):
            audit.out_of_scope[qid] = reason
        elif world is not None and (zone := quest_zone(world, qid, record)) is not None and zone not in zones:
            audit.elsewhere.append(qid)
        else:
            audit.missing.append(qid)
    return audit


def quest_zone(world: guide_travel.World, qid: int, record: dict) -> int | None:
    """The zone a quest belongs to: its log header's map, else where its giver stands; None for a quest filed by class or profession."""
    if isinstance(record.get("zone"), int):
        return world.zone(record["zone"])
    starts = world.quest_coords(qid, "s")
    return world.zone(starts[0].map) if starts else None


def audit(events: list, learned: dict | None, project: guidefile.Project, pack: guide_travel.Pack, guide_ids=None) -> Audit:
    seen = collect(events, learned)
    quests = pack.table("quests")
    worlds: dict[str, guide_travel.World] = {}

    def world_for(faction: str) -> guide_travel.World:
        if faction not in worlds:
            worlds[faction] = guide_travel.World(pack, project.borders, faction)
        return worlds[faction]

    guides = [
        audit_guide(project, pack, guide, set(seen), world_for)
        for gid, guide in sorted(project.guides.items())
        if not guide_ids or gid in guide_ids
    ]
    gaps = sorted(qid for qid in seen if qid not in quests)
    return Audit(seen, gaps, guides, len(events), len(learned_quests(learned)))


# The report ------------------------------------------------------------------------------------------------------------


def _label(quests: dict, qid: int, seen: dict[int, Seen]) -> str:
    record = quests.get(qid)
    name = record.get("n") if isinstance(record, dict) else None
    name = name or (seen[qid].title if qid in seen else "")
    level = f" (level {record['l']})" if isinstance(record, dict) and record.get("l") else ""
    return f'{qid} "{name}"{level}' if name else f"{qid}{level}"


def report(result: Audit, quests: dict) -> list[str]:
    out = [f"== {len(result.seen)} distinct quest(s) seen in {result.events} recorded event(s) and {result.learned} learned record(s)"]
    out.append(f"== data gaps: {len(result.data_gaps)} of them are not in the data pack")
    for qid in result.data_gaps:
        seen = result.seen[qid]
        where = f" at map {seen.spot[0]} {seen.spot[1]:g},{seen.spot[2]:g}" if seen.spot else ""
        who = f", given by {', '.join(sorted(seen.givers))}" if seen.givers else ""
        title = f' "{seen.title}"' if seen.title else ""
        out.append(f"   {qid}{title}: {', '.join(sorted(seen.how))}{who}{where}")
    for guide in result.guides:
        mine = len(guide.covered) + len(guide.skipped) + len(guide.out_of_scope) + len(guide.missing)
        out.append(
            f"== {guide.name} ({guide.guide}, last chapter level {guide.top}): {mine} of the quests seen are for this character: "
            f"{len(guide.covered)} in the route, {len(guide.skipped)} skipped on purpose, {len(guide.out_of_scope)} out of scope, "
            f"{len(guide.missing)} NOT in the route; {len(guide.others)} are other characters' and {len(guide.elsewhere)} are in zones "
            "the route never visits"
        )
        for qid, reason in guide.skipped.items():
            out.append(f"   skipped      {_label(quests, qid, result.seen)}: {reason}")
        for qid, reason in guide.out_of_scope.items():
            out.append(f"   out of scope {_label(quests, qid, result.seen)}: {reason}")
        for qid in guide.missing:
            seen = result.seen[qid]
            out.append(
                f"   NOT ROUTED   {_label(quests, qid, result.seen)}: {', '.join(sorted(seen.how))}; "
                "left out by the planner or the drafter (its report says why: docs/PLANNER.md)"
            )
    return out


# Command line ----------------------------------------------------------------------------------------------------------


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--root", type=Path, default=REPO_ROOT)
    parser.add_argument("--pack", type=Path, help="the data pack folder (default: ../Signpost_Data)")
    parser.add_argument("--from", dest="source", type=Path, help="a copied SavedVariables folder instead of the dev client's")
    parser.add_argument("--guide", action="append", help="only this guide id (repeatable)")
    parser.add_argument("--strict", action="store_true", help="exit 1 when the pack lacks a quest the game offered")
    options = parser.parse_args(argv)
    guide_travel.safe_stdout()

    pack = guide_travel.load_pack(options.pack or guide_travel.default_pack_dir(options.root))
    if not pack.present:
        print("audit_quests needs the data pack: " + pack.describe())
        return 1
    files = svfiles.find_files(options.source)
    account = next((sv for sv in files if sv.variable == svfiles.ACCOUNT_VAR and sv.path.is_file()), None)
    db = svfiles.load_db(account) if account else {}
    events = _listed(db.get("eventLog"))
    learned = db.get("learned") if isinstance(db.get("learned"), dict) else {}
    if not events and not learned.get("quests"):
        print("no quests recorded: play with a development build (or /signpost debug on), then /reload")
        return 0
    project = guidefile.load_project(options.root)
    unknown = sorted(set(options.guide or ()) - set(project.guides))
    if unknown:
        print(f"no guide with the id {', '.join(unknown)} (have: {', '.join(sorted(project.guides))})")
        return 1
    result = audit(events, learned, project, pack, options.guide)
    print("\n".join(report(result, pack.table("quests"))))
    return 1 if options.strict and result.data_gaps else 0


if __name__ == "__main__":
    sys.exit(main())
