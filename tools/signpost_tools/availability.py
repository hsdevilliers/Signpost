"""When a character can take a quest: the rules the game applies, from the fields the data pack carries (docs/AVAILABILITY.md).

    rules = Rules(pack_quests, Character("Horde", race_bit("Troll", "Horde"), CLASS_BITS["HUNTER"]))
    rules.never(794)                                          # None, or why this character can never take it
    rules.unmet(794, level=1, done=set(), active=set())       # [] when the game offers it, else every reason it does not

The checks, as the game makes them (each is a field of the pack's quest record; QuestieDB's names in brackets):
  - who: `side` (faction), `races` (requiredRaces), `classes` (requiredClasses, or the class sort of a class quest);
  - level: `r` (requiredLevel) and `maxLevel` (requiredMaxLevel);
  - `skill`: a profession skill line;
  - prerequisites: `preGroup` (preQuestGroup: all of them done first) and `preSingle` (preQuestSingle: at least one of them
    done first). A prerequisite that is another race's or class's quest (the Warlock's "Vile Familiars" beside everyone
    else's) can never be done by this character: it does not count as an alternative;
  - `exclusive` (exclusiveTo): doing or holding one of them closes this one;
  - `parent` (parentQuest): the parent must be in the quest log;
  - `next` (nextQuestInChain) of another quest: that quest hands this one over when it is turned in, and this one is not
    offered while that quest is in the log (seen in play: Gornek stops offering Cutting Teeth while Your Place in the
    World is in the log, and offers it as the turn-in completes).
What the pack does not carry (reputation, spells, items that start or unlock a quest, world events, phasing) is not checked
here; QuestieDB's Forever layers do not supply complete restrictions either, so tools/validate_availability.py compares
these rules with what the game offered in recorded sessions.
"""

from __future__ import annotations

from collections.abc import Iterable
from dataclasses import dataclass

# The data pack's masks are bit (id - 1) of the client's race and class IDs; Forever's Skyborne races are bits 32 (Alliance)
# and 33 (Horde) (docs/FOREVER-API-NOTES.md).
RACE_BITS = {
    "human": 1, "orc": 2, "dwarf": 4, "nightelf": 8, "scourge": 16, "undead": 16, "tauren": 32, "gnome": 64, "troll": 128
}  # fmt: skip
SKYBORNE_BITS = {"Horde": 1 << 33, "Alliance": 1 << 32}
CLASS_BITS = {
    "WARRIOR": 1, "PALADIN": 2, "HUNTER": 4, "ROGUE": 8, "PRIEST": 16, "SHAMAN": 64, "MAGE": 128, "WARLOCK": 256, "DRUID": 1024
}  # fmt: skip
# A class quest the pack gives no class mask is filed under its class's quest sort (the client's quest categories with the
# sign dropped); the Forever layers do this for new class chains (Windshaper Cat Form).
CLASS_SORTS = {
    61: "WARLOCK", 81: "WARRIOR", 82: "SHAMAN", 141: "PALADIN", 161: "MAGE", 162: "ROGUE", 261: "HUNTER", 262: "PRIEST", 263: "DRUID"
}  # fmt: skip
# The pack's `sort` values of seasonal and event quests (the client's quest categories with the sign dropped): Seasonal 22,
# Special 284, Darkmoon Faire 364, Ahn'Qiraj War Effort 365, Lunar Festival 366, Invasion 368, Midsummer 369.
EVENT_SORTS = {22, 284, 364, 365, 366, 368, 369}

# Reasons that are worth a warning, not an error: the route may still work.
WARNING_CODES = {"unknown-prerequisite", "event", "repeatable", "level-ungated"}


def race_bit(race: str | None, faction: str) -> int | None:
    """The mask bit of a raceFile token, or None for a race this table does not know (no race checks then)."""
    if not race:
        return None
    key = race.lower()
    if key == "skyborne":
        return SKYBORNE_BITS.get(faction)
    return RACE_BITS.get(key)


def class_bit(token: str | None) -> int | None:
    return CLASS_BITS.get(token.upper()) if token else None


@dataclass(frozen=True)
class Character:
    faction: str  # Horde or Alliance
    race_bit: int | None = None  # None: the race is not known, so no race check is made
    class_bit: int | None = None
    skills: frozenset = frozenset()  # profession skill lines the character has (ranks are not tracked)


@dataclass(frozen=True)
class Unmet:
    """One reason the game does not offer a quest."""

    code: str
    text: str
    quests: tuple = ()  # the quests the reason is about (prerequisites, the quest that locks it, ...)

    @property
    def severity(self) -> str:
        return "warning" if self.code in WARNING_CODES else "error"


def _ids(value: object) -> list[int]:
    if isinstance(value, int) and not isinstance(value, bool):
        return [value]
    return [item for item in value or [] if isinstance(item, int) and not isinstance(item, bool)]


class Rules:
    """The availability rules for one character over the pack's quest table."""

    def __init__(self, quests: dict, character: Character) -> None:
        self.quests = quests
        self.me = character
        self.parents: dict[int, list[int]] = {}  # quest -> the quests whose `next` it is
        for qid, record in quests.items():
            following = record.get("next") if isinstance(record, dict) else None
            if isinstance(following, int):
                self.parents.setdefault(following, []).append(qid)
        self._never: dict[int, Unmet | None] = {}
        self._visiting: set[int] = set()

    # who -------------------------------------------------------------------------------------------------------------

    def class_mask(self, record: dict) -> int | None:
        classes = record.get("classes")
        if isinstance(classes, int):
            return classes
        token = CLASS_SORTS.get(record.get("sort"))
        return CLASS_BITS[token] if token else None

    def mask_block(self, qid: int) -> Unmet | None:
        """Why this character's faction, race or class never gets the quest, or None."""
        record = self.quests.get(qid)
        if not isinstance(record, dict):
            return None
        side = record.get("side")
        if side in ("Horde", "Alliance") and side != self.me.faction:
            return Unmet("faction", f"quest {qid} is a {side} quest", (qid,))
        races = record.get("races")
        if isinstance(races, int) and self.me.race_bit is not None and not races & self.me.race_bit:
            return Unmet("race", f"quest {qid} is not open to this race", (qid,))
        classes = self.class_mask(record)
        if classes is not None and self.me.class_bit is not None and not classes & self.me.class_bit:
            return Unmet("class", f"quest {qid} is not open to this class", (qid,))
        return None

    def never(self, qid: int) -> Unmet | None:
        """Why this character can never take the quest (who it is, or a prerequisite it can never do), or None. A quest
        the pack does not know is not called impossible: the pack keeps Horde and neutral quests only."""
        if qid in self._never:
            return self._never[qid]
        record = self.quests.get(qid)
        if not isinstance(record, dict) or qid in self._visiting:
            return None
        self._visiting.add(qid)
        try:
            reason = self.mask_block(qid)
            if reason is None:
                for earlier in _ids(record.get("preGroup")):
                    if self.never(earlier):
                        reason = Unmet("impossible", f"it needs quest {earlier}, which is closed to this character", (earlier,))
                        break
            if reason is None:
                alternatives = _ids(record.get("preSingle"))
                if alternatives and all(earlier in self.quests and self.never(earlier) for earlier in alternatives):
                    listed = ", ".join(map(str, alternatives))
                    reason = Unmet("impossible", f"every quest it needs ({listed}) is closed to this character", tuple(alternatives))
        finally:
            self._visiting.discard(qid)
        self._never[qid] = reason
        return reason

    # now -------------------------------------------------------------------------------------------------------------

    def unmet(
        self,
        qid: int,
        level: int,
        done: Iterable[int] = (),
        active: Iterable[int] = (),
        skills: Iterable[int] | None = None,
    ) -> list[Unmet]:
        """Every reason the game does not offer this quest to the character now (empty: it is offered). `done` is what the
        character has turned in, `active` what is in the quest log."""
        record = self.quests.get(qid)
        if not isinstance(record, dict):
            return [Unmet("unknown", f"quest {qid} is not in the data", (qid,))]
        done, active = set(done), set(active)
        reasons: list[Unmet] = []
        block = self.mask_block(qid)
        if block:
            reasons.append(block)
        if record.get("sort") in EVENT_SORTS:
            reasons.append(Unmet("event", f"quest {qid} belongs to a seasonal or world event", (qid,)))
        if record.get("repeatable"):
            reasons.append(Unmet("repeatable", f"quest {qid} is repeatable (a daily or a repeat)", (qid,)))
        need = record.get("r") or 0
        if need > level:
            reasons.append(Unmet("level", f"it needs level {need} and the character is level {level}"))
        top = record.get("maxLevel")
        if isinstance(top, int) and top and level > top:
            reasons.append(Unmet("level", f"it is not offered above level {top} and the character is level {level}"))
        skill = record.get("skill")
        line = skill[0] if isinstance(skill, list) and skill else skill if isinstance(skill, int) else None
        have = set(self.me.skills if skills is None else skills)
        if line and line not in have:
            reasons.append(Unmet("skill", f"it needs the profession skill line {line}"))
        pending_all = [p for p in _ids(record.get("preGroup")) if p not in done]
        if pending_all:
            closed = [p for p in pending_all if self.never(p)]
            if closed:
                reasons.append(Unmet("impossible", f"it needs quest {closed[0]} done, which is closed to this character", tuple(closed)))
            else:
                reasons.append(Unmet("prerequisite", f"it needs all of {', '.join(map(str, pending_all))} turned in first", tuple(pending_all)))
        alternatives = _ids(record.get("preSingle"))
        if alternatives and not any(p in done for p in alternatives):
            possible = [p for p in alternatives if p not in self.quests or not self.never(p)]
            if not possible:
                reasons.append(Unmet("impossible", f"every quest it needs ({', '.join(map(str, alternatives))}) is closed to this character", tuple(alternatives)))
            else:
                unknown = [p for p in possible if p not in self.quests]
                if len(unknown) == len(possible):
                    reasons.append(Unmet("unknown-prerequisite", f"it needs one of {', '.join(map(str, possible))} first, which the data does not know", tuple(possible)))
                else:
                    reasons.append(Unmet("prerequisite", f"it needs one of {', '.join(map(str, possible))} turned in first", tuple(possible)))
        locked = [p for p in _ids(record.get("exclusive")) if p in done or p in active]
        if locked:
            reasons.append(Unmet("locked", f"quest {locked[0]} closes it (they exclude each other)", tuple(locked)))
        parent = record.get("parent")
        if isinstance(parent, int) and parent not in active:
            reasons.append(Unmet("parent", f"quest {parent} must be in the quest log", (parent,)))
        holding = [p for p in self.parents.get(qid, ()) if p in active]
        if holding:
            reasons.append(Unmet("chain", f"quest {holding[0]} hands it over when it is turned in", tuple(holding)))
        return reasons

    def offered(self, qid: int, level: int, done: Iterable[int] = (), active: Iterable[int] = ()) -> bool:
        """Whether the game offers the quest now, counting only reasons that are errors."""
        return not [r for r in self.unmet(qid, level, done, active) if r.severity == "error"]
