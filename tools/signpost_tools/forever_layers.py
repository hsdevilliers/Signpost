"""Apply QuestieDB's Forever correction layers to the importer's in-memory records (PLAN §6; CLAUDE.md, Data sources).

QuestieDB's data/Forever tables are a converted Classic Era baseline; its real Forever content is layered on top as
correction providers. In QuestieDB's static order (the inherited legacy corrections are skipped here: large, with runtime
branches):

    raw base -> generated delta-base -> generated traces (beta recordings) -> authored Forever fixes

The providers are read as data by `lua_corrections` (never executed); this module applies their records to
`questie_import.Questie.data` so the importer's one conversion path (side logic, zone mapping, position clustering,
schema) stays the only path. Ordinary assignment replaces a field (an empty table clears it); `_add` and `_remove` on
table fields follow the shape of the field (QuestieDB docs/adr/0016): lists add missing / remove exact values, grouped
fields (startedBy, finishedBy, objectives: positional groups with nil holes; spawns and waypoints: zone-keyed groups)
apply the list rule inside each group they name, pairs and triggers are atomic. Anything else is rejected and counted.
Unknown IDs create records.
"""

from __future__ import annotations

from collections import Counter
from dataclasses import dataclass, field
from pathlib import Path

from . import lua_corrections as lc

PROVIDER_DIR = "src/corrections/Forever"
# (layer name, {kind: provider file under PROVIDER_DIR}), in application order.
LAYERS = (
    (
        "delta-base",
        {
            "quest": "generated/foreverBaseQuest.lua",
            "npc": "generated/foreverBaseNpc.lua",
            "object": "generated/foreverBaseObject.lua",
            "item": "generated/foreverBaseItem.lua",
        },
    ),
    (
        "traces",
        {
            "quest": "traces/foreverQuestTraces.lua",
            "npc": "traces/foreverNpcTraces.lua",
            "object": "traces/foreverObjectTraces.lua",
            "item": "traces/foreverItemTraces.lua",
        },
    ),
    (
        "authored",
        {
            "quest": "foreverQuestFixes.lua",
            "npc": "foreverNPCFixes.lua",
            "object": "foreverObjectFixes.lua",
            "item": "foreverItemFixes.lua",
        },
    ),
)
LIST_SHAPES = {"idarray", "stringarray", "pairs", "extraobjectives"}
GROUP_SHAPES = {"questgivers", "objectives", "spawnlist", "waypointlist"}
ATOMIC_SHAPES = {"pair", "trigger"}
REPUTATION_GROUP = 4  # objectives: a fixed {faction, value} pair, not a list
# Positions inside the grouped quest fields as the providers write them (QuestieDB's canonical questKeys parts). The
# importer reads the same positions from the data file's key table; the two must agree for `{nil, {id}}` to mean the same.
CANONICAL_PARTS = {
    "startedBy": {"creatureStart": 1, "objectStart": 2, "itemStart": 3},
    "finishedBy": {"creatureEnd": 1, "objectEnd": 2},
    "objectives": {
        "creatureObjective": 1,
        "objectObjective": 2,
        "itemObjective": 3,
        "reputationObjective": REPUTATION_GROUP,
        "killCreditObjective": 5,
        "spellObjective": 6,
    },
}


# Table helpers --------------------------------------------------------------------------------------------------------


def slots_of(record: object) -> dict[int, object]:
    """A record (list with nil holes, or dict) as {position: value} without the holes."""
    if isinstance(record, dict):
        return {key: value for key, value in record.items() if isinstance(key, int) and value is not None}
    if isinstance(record, list):
        return {index: value for index, value in enumerate(record, 1) if value is not None}
    return {}


def to_items(value: object) -> list:
    """The entries of a Lua list-like table (nil holes dropped); a scalar is one entry."""
    if value is None:
        return []
    if isinstance(value, list):
        return [item for item in value if item is not None]
    if isinstance(value, dict):
        return [value[key] for key in sorted(k for k in value if isinstance(k, int))]
    return [value]


def group_of(value: object) -> dict:
    """A grouped table as {group key: group}: positions of a positional table, or the zone keys of a spawn table."""
    if isinstance(value, list):
        return {index: item for index, item in enumerate(value, 1) if item is not None}
    if isinstance(value, dict):
        return {key: item for key, item in value.items() if item is not None}
    return {}


def is_empty(value: object) -> bool:
    return value is None or (isinstance(value, (list, dict)) and not value)


def list_operation(current: object, operand: object, op: str) -> list:
    items, wanted = to_items(current), to_items(operand)
    if op == "remove":
        return [item for item in items if item not in wanted]
    result = list(items)
    for item in wanted:
        if item not in result:
            result.append(item)
    return result


def atomic_operation(current: object, operand: object, op: str) -> tuple[object, str | None]:
    """(new value or None, rejection). Add when absent or equal; a different existing value is rejected."""
    if op == "add":
        if is_empty(current) or current == operand:
            return operand, None
        return current, "add to an atomic field that holds a different value"
    return (None if current == operand else current), None


def apply_field(slots: dict[int, object], position: int, ref: lc.FieldRef, value: object, shape: str | None) -> tuple[bool, str | None]:
    """Apply one provider field to a record's slots. Returns (changed, rejection reason)."""
    before = slots.get(position)
    if ref.op == "set":
        if is_empty(value):
            slots.pop(position, None)
        else:
            slots[position] = value
        return before != slots.get(position), None
    if shape in LIST_SHAPES:
        result: object = list_operation(before, value, ref.op)
    elif shape in GROUP_SHAPES:
        result = group_of(before)
        for key, operand in group_of(value).items():
            if shape == "objectives" and key == REPUTATION_GROUP:
                new, rejection = atomic_operation(result.get(key), operand, ref.op)
                if rejection:
                    return False, rejection
                result[key] = new
            else:
                result[key] = list_operation(result.get(key), operand, ref.op)
        result = {key: item for key, item in result.items() if not is_empty(item)}
    elif shape in ATOMIC_SHAPES:
        result, rejection = atomic_operation(before, value, ref.op)
        if rejection:
            return False, rejection
    else:
        return False, f"{ref.op} on a field with no table shape"
    if is_empty(result):
        slots.pop(position, None)
    else:
        slots[position] = result
    return before != slots.get(position), None


# Applying the layers --------------------------------------------------------------------------------------------------


@dataclass
class LayerStats:
    name: str
    added: Counter = field(default_factory=Counter)  # kind -> new records
    changed: Counter = field(default_factory=Counter)  # kind -> existing records with at least one changed field
    fields: Counter = field(default_factory=Counter)  # kind -> fields applied
    read: Counter = field(default_factory=Counter)  # kind -> provider records read


@dataclass
class LayerReport:
    applied: bool = False
    layers: list[LayerStats] = field(default_factory=list)
    skipped: Counter = field(default_factory=Counter)  # reason -> count, over every provider and layer
    rejected: Counter = field(default_factory=Counter)
    note: str = ""

    def total(self, what: str, kind: str | None = None) -> int:
        return sum(
            count for layer in self.layers for k, count in getattr(layer, what).items() if kind is None or k == kind
        )

    def summary(self) -> str:
        """One line for the layer origin and the data-gaps report."""
        if not self.applied:
            return self.note or "no Forever layers"
        parts = [
            f"{layer.name} +{sum(layer.added.values())} ~{sum(layer.changed.values())}" for layer in self.layers
        ]
        return "Forever layers (" + ", ".join(parts) + " records added/changed)"


def apply_layers(questie, root: Path, kinds: tuple[str, ...] = lc.KINDS) -> LayerReport:  # noqa: ANN001
    """Apply the Forever providers of the QuestieDB checkout at `root` to `questie.data`, in place."""
    report = LayerReport()
    if not (root / PROVIDER_DIR).is_dir():
        report.note = "no Forever layers in this checkout"
        return report
    for composite, parts in CANONICAL_PARTS.items():
        found = {name: position for name, position in questie.parts.get(composite, {}).items() if name in parts}
        if found != {name: position for name, position in parts.items() if name in found}:
            raise lc.CorrectionsFormatError(
                f"the data file's {composite} part positions {found} differ from the providers' {parts}: "
                "group operands would be misread"
            )
    env = lc.load_environment(root)
    report.skipped.update({f"enum/meta: {reason}": count for reason, count in env.skipped.items()})
    for name, files in LAYERS:
        stats = LayerStats(name)
        for kind in kinds:
            path = root / PROVIDER_DIR / files[kind]
            if not path.is_file():
                report.skipped[f"provider file missing ({files[kind]})"] += 1
                continue
            result = lc.read_provider(path, env, kind)
            for reason, count in result.skipped.items():
                report.skipped[reason] += count
            stats.read[kind] += len(result.records)
            apply_provider(questie, kind, result, env.shapes.get(kind, {}), stats, report)
        report.layers.append(stats)
    report.applied = True
    return report


def apply_provider(questie, kind: str, result: lc.ProviderResult, shapes: dict[str, str], stats: LayerStats, report: LayerReport) -> None:  # noqa: ANN001
    table = questie.data[kind]
    positions = questie.keys[kind]
    for record_id, fields in sorted(result.records.items()):
        existing = record_id in table
        slots = slots_of(table.get(record_id))
        changed = False
        applied = 0
        for ref, value in fields.items():
            position = positions.get(ref.name)
            if position is None:
                report.skipped[f"{kind} field not in the data file's key table ({ref.name})"] += 1
                continue
            did_change, rejection = apply_field(slots, position, ref, value, shapes.get(ref.name))
            if rejection:
                report.rejected[f"{kind} {ref.name}: {rejection}"] += 1
                continue
            applied += 1
            changed = changed or did_change
        if not applied:
            continue
        stats.fields[kind] += applied
        table[record_id] = slots
        if not existing:
            stats.added[kind] += 1
        elif changed:
            stats.changed[kind] += 1
