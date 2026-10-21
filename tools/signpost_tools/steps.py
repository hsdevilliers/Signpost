"""Activity steps (user, 2026-10-20): a step is built around what the player does there, not around one NPC.

A chapter's steps are lists of directive lines. Their kind is read from the directives, no new syntax:
  place  a step with `.accept` or `.turnin`: where quests are picked up and handed in (one step may do both, at one NPC or in one
         area). The guide marks it on the map.
  do     a step with `.complete` and nothing that sends the player to a place: quests whose objectives are close to each other.
         The step only knows which of its quests are complete; the quest log shows the progress and marks the objectives, so
         the guide draws no marker for it.
  other  everything else (travel, `.level`, `.todo`, profession and class steps, a step with a gate or `.hub` line of its own): never
         merged.

`group` joins neighbouring steps of one kind that stand near each other: three NPCs of a camp who give a quest each become one
pick-up step (with the position of each, for the player who has no data pack), and the kill areas of five quests within a few
hundred yards one doing step. The tools (the drafter and the Route Planner) write the steps one place at a time and call it last.
docs/GUIDE-FORMAT.md ("Step kinds").
"""

from __future__ import annotations

import re
from collections.abc import Callable

from .guidefile import GATES, Coord

PLACE, DO, OTHER = "place", "do", "other"
GROUP_YARDS = 250.0  # steps whose first positions are this near each other are one area
STEP_LINES = frozenset({*GATES, "hub"})  # lines that belong to a whole step: a step that has one cannot share it with another

_GOTO = re.compile(r"^\s*\.goto\s+(\d+)\s*,\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)")
_DIRECTIVE = re.compile(r"^\s*\.([a-z][a-z0-9]*)\b")
_OBJECTIVE = re.compile(r"^(\s*)\.complete\s+(\d+)\s*,\s*(\d+)(.*)$")

Step = list[str]


def names(step: Step) -> set[str]:
    return {m.group(1) for m in (_DIRECTIVE.match(line) for line in step) if m}


def kind(step: Step) -> str:
    """place, do or other (see the module's docstring)."""
    found = names(step)
    if "todo" in found:
        return OTHER  # a step that says something is missing stays a step of its own
    if found & STEP_LINES:
        return OTHER  # a gate on its own line gates the whole step, and a step has one `.hub`: joined, they would cover its neighbour
    if found & {"accept", "turnin"}:
        return PLACE
    if "complete" in found:
        return DO
    return OTHER


def goto(step: Step) -> Coord | None:
    """The position the step's first `.goto` gives."""
    for line in step:
        m = _GOTO.match(line)
        if m:
            return Coord(int(m.group(1)), float(m.group(2)), float(m.group(3)))
    return None


def _joins(a: Step, b: Step, near: Callable[[Coord, Coord], bool]) -> bool:
    here, there = goto(a), goto(b)
    return here is not None and there is not None and near(here, there)


def is_goto(line: str) -> bool:
    """Whether the line is a `.goto` directive."""
    return _GOTO.match(line) is not None


def group(
    steps: list[Step], near: Callable[[Coord, Coord], bool], objectives: Callable[[int], list[int] | None] | None = None
) -> list[Step]:
    """The steps with neighbours of one kind that are near each other joined into one; every line is kept in order. A pick-up and
    hand-in step keeps the `.goto` of each place (they are its pins when there is no data pack, and the walk between them is
    priced); a doing step keeps the first only (it draws no markers: the quest log shows where the objectives are).
    `objectives(questID)`, when given, lists a quest's objective numbers: a doing step that finishes all of them says
    `.complete <quest>` once instead of one line per objective."""
    return [step for step, _first, _last in group_spans(steps, near, objectives)]


def group_spans(
    steps: list[Step], near: Callable[[Coord, Coord], bool], objectives: Callable[[int], list[int] | None] | None = None
) -> list[tuple[Step, int, int]]:
    """`group`, and for each step it writes the positions of the first and the last of the steps it was made of (a step that joined
    nothing has the same one twice), so that what the caller knows about the steps it gave (a zone, a level) can follow them."""
    out: list[list] = []  # [step, first input, last input]
    for index, step in enumerate(steps):
        k = kind(step)
        if out and k != OTHER and kind(out[-1][0]) == k and _joins(out[-1][0], step, near):
            seen = {line.strip() for line in out[-1][0] if _GOTO.match(line)}
            joined = list(out[-1][0])
            for line in step:
                if _GOTO.match(line):
                    if k == PLACE and line.strip() not in seen:
                        seen.add(line.strip())
                        joined.append(line)
                else:
                    joined.append(line)
            out[-1][0], out[-1][2] = joined, index
        else:
            out.append([list(step), index, index])
    return [(whole_quests(step, objectives) if objectives and kind(step) == DO else step, first, last) for step, first, last in out]


def whole_quests(step: Step, objectives: Callable[[int], list[int] | None]) -> Step:
    """`.complete Q,1` and `.complete Q,2` of a quest with exactly those two objectives become `.complete Q` (the quest-level form
    is done when every objective is finished, which is what the two lines mean together)."""
    seen: dict[int, list[int]] = {}
    for line in step:
        m = _OBJECTIVE.match(line)
        if m:
            seen.setdefault(int(m.group(2)), []).append(int(m.group(3)))
    whole = {q for q, found in seen.items() if (all_of := objectives(q)) and sorted(set(found)) == sorted(all_of)}
    out: Step = []
    written: set[int] = set()
    for line in step:
        m = _OBJECTIVE.match(line)
        if m and int(m.group(2)) in whole:
            quest = int(m.group(2))
            if quest not in written:
                written.add(quest)
                out.append(f"{m.group(1)}.complete {quest}{m.group(4)}")
            continue
        out.append(line)
    return out
