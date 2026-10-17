"""Deterministic Python -> Lua literal writer for generated files (sorted keys, LF line endings, stable formatting).

Tables nested less than `expand_depth` deep get one entry per line, so regenerated data diffs line by line.
"""

from __future__ import annotations

import math
import re
from pathlib import Path

__all__ = ["lua_string", "to_lua", "write_lua"]

_IDENTIFIER = re.compile(r"[A-Za-z_][A-Za-z0-9_]*\Z")
_KEYWORDS = frozenset(
    "and break do else elseif end false for function if in local nil not or repeat return then true until while".split()
)


def lua_string(text: str) -> str:
    out = ['"']
    for char in text:
        code = ord(char)
        if char == '"':
            out.append('\\"')
        elif char == "\\":
            out.append("\\\\")
        elif char == "\n":
            out.append("\\n")
        elif char == "\r":
            out.append("\\r")
        elif char == "\t":
            out.append("\\t")
        elif code < 32 or code == 127:
            out.append(f"\\{code:03d}")
        else:
            out.append(char)
    out.append('"')
    return "".join(out)


def _number(value: int | float) -> str:
    if isinstance(value, int):
        return str(value)
    if math.isnan(value) or math.isinf(value):
        raise ValueError("Lua literals cannot hold NaN or infinity")
    if value == int(value) and abs(value) < 1e15:
        return str(int(value))
    return repr(value)


def _key(key: object) -> str:
    if isinstance(key, bool):
        raise TypeError("boolean table keys are not supported")
    if isinstance(key, (int, float)):
        return f"[{_number(key)}]"
    if isinstance(key, str):
        if _IDENTIFIER.match(key) and key not in _KEYWORDS:
            return key
        return f"[{lua_string(key)}]"
    raise TypeError(f"unsupported table key type {type(key).__name__}")


def _sort_key(key: object) -> tuple[int, float, str]:
    if isinstance(key, (int, float)) and not isinstance(key, bool):
        return (0, float(key), "")
    return (1, 0.0, str(key))


def to_lua(value: object, expand_depth: int = 1, indent: str = "\t", _level: int = 0) -> str:
    if value is None:
        return "nil"
    if value is True:
        return "true"
    if value is False:
        return "false"
    if isinstance(value, (int, float)):
        return _number(value)
    if isinstance(value, str):
        return lua_string(value)
    if isinstance(value, (list, tuple)):
        if any(item is None for item in value):
            raise ValueError("lists must not contain None (a Lua array cannot have holes)")
        entries = [to_lua(item, expand_depth, indent, _level + 1) for item in value]
    elif isinstance(value, dict):
        entries = [
            f"{_key(key)} = {to_lua(item, expand_depth, indent, _level + 1)}"
            for key, item in sorted(value.items(), key=lambda pair: _sort_key(pair[0]))
            if item is not None
        ]
    else:
        raise TypeError(f"cannot write {type(value).__name__} as a Lua literal")
    if not entries:
        return "{}"
    if _level < expand_depth:
        pad = indent * (_level + 1)
        return "{\n" + "".join(f"{pad}{entry},\n" for entry in entries) + indent * _level + "}"
    return "{ " + ", ".join(entries) + " }"


def write_lua(path: Path, header: list[str], assignments: list[tuple[str, object]], expand_depth: int = 1) -> None:
    """Write `-- header` lines followed by `target = <value>` statements."""
    lines = [f"-- {line}" for line in header]
    lines += [f"{target} = {to_lua(value, expand_depth)}" for target, value in assignments]
    Path(path).write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
