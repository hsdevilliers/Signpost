"""Activity steps (user, 2026-10-20): a step is built around what the player does there, not around one NPC.

A chapter's steps are lists of directive lines. Their kind is read from the directives, no new syntax:
  place  a step with `.accept` or `.turnin`: where quests are picked up and handed in (one step may do both, at one NPC or in one
         area). The guide marks it on the map.
  do     a step with `.complete` and nothing that sends the player to a place: quests whose objectives are close to each other.
         The step only knows which of its quests are complete; the quest log shows the progress and marks the objectives, so
         the guide draws no marker for it.
  other  everything else (travel, `.level`, `.todo`, profession and class steps): never merged.

`group` joins neighbouring steps of one kind that stand near each other: three NPCs of a camp who give a quest each become one
pick-up step, and the kill areas of five quests within a few hundred yards one doing step. The tools (the drafter and the Route
Planner) write the steps one place at a time and call it last. docs/GUIDE-FORMAT.md ("Step kinds").
"""

from __future__ import annotations

import re
from collections.abc import Callable

from .guidefile import Coord

PLACE, DO, OTHER = "place", "do", "other"
GROUP_YARDS = 250.0  # steps whose first positions are this near each other are one area

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


def group(
    steps: list[Step], near: Callable[[Coord, Coord], bool], objectives: Callable[[int], list[int] | None] | None = None
) -> list[Step]:
    """The steps with neighbours of one kind that are near each other joined into one. The joined step keeps the first
    `.goto` (the other places are in the data pack's pins and the quest log); every other line is kept in order.
    `objectives(questID)`, when given, lists a quest's objective numbers: a doing step that finishes all of them says
    `.complete <quest>` once instead of one line per objective."""
    out: list[Step] = []
    for step in steps:
        k = kind(step)
        if out and k != OTHER and kind(out[-1]) == k and _joins(out[-1], step, near):
            out[-1] = out[-1] + [line for line in step if not _GOTO.match(line)]
        else:
            out.append(list(step))
    return [whole_quests(step, objectives) if objectives and kind(step) == DO else step for step in out]


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
