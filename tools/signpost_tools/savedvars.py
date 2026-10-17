"""Parse World of Warcraft SavedVariables files (Lua table literals) into Python values.

The client writes `Name = <value>` statements. Values are nil, booleans, numbers, strings and tables, and array items
carry a trailing `-- [n]` comment. A table whose keys are exactly 1..n becomes a list; any other table a dict (integer
keys stay integers). The parser also accepts the rest of Lua's literal syntax (single quotes, long strings, block
comments, `name = value` fields), which covers the generated data-pack files too.
"""

from __future__ import annotations

import re
from pathlib import Path

__all__ = ["LuaParseError", "parse_savedvars", "load_savedvars"]


class LuaParseError(ValueError):
    pass


_SKIP = re.compile(r"(?:\s+|--\[(=*)\[.*?\]\1\]|--[^\n]*)*", re.S)
_NAME = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
# Statement targets: `SignpostDB` in SavedVariables, `Signpost_Data.quests` in the generated data pack.
_TARGET = re.compile(r"[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*")
_NUMBER = re.compile(r"-?(?:0[xX][0-9a-fA-F]+|(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?)")
# How C runtimes print infinities and NaN (none of Signpost's own data contains them; other writers might).
_SPECIAL_NUMBER = re.compile(r"(-?)(?:1\.#INF|inf|1\.#IND|1\.#QNAN|nan)(?:\(ind\))?", re.I)
_DOUBLE_QUOTED = re.compile(r'"((?:[^"\\]|\\.)*)"', re.S)
_SINGLE_QUOTED = re.compile(r"'((?:[^'\\]|\\.)*)'", re.S)
_LONG_STRING = re.compile(r"\[(=*)\[\n?(.*?)\]\1\]", re.S)
_LONG_OPEN = re.compile(r"\[=*\[")
_DIGITS = re.compile(r"\d{1,3}")
_ESCAPES = {
    "n": b"\n",
    "t": b"\t",
    "r": b"\r",
    "a": b"\a",
    "b": b"\b",
    "f": b"\f",
    "v": b"\v",
    "\\": b"\\",
    '"': b'"',
    "'": b"'",
    "\n": b"\n",
}


def _unescape(body: str) -> str:
    """Decode Lua escapes. Lua strings are bytes, so \\ddd escapes are collected as bytes and decoded as UTF-8."""
    if "\\" not in body:
        return body.encode("utf-8", "surrogateescape").decode("utf-8", "replace")
    out = bytearray()
    i, end = 0, len(body)
    while i < end:
        slash = body.find("\\", i)
        if slash < 0:
            out += body[i:].encode("utf-8", "surrogateescape")
            break
        out += body[i:slash].encode("utf-8", "surrogateescape")
        i = slash + 1
        if i >= end:
            raise LuaParseError("string ends with a backslash")
        char = body[i]
        digits = _DIGITS.match(body, i)
        if digits:
            code = int(digits.group())
            if code > 255:
                raise LuaParseError(f"escape \\{code} is out of range")
            out.append(code)
            i = digits.end()
        else:
            out += _ESCAPES.get(char, char.encode("utf-8", "surrogateescape"))
            i += 1
    return out.decode("utf-8", "replace")


def _table_value(items: list[tuple[object, object]]) -> object:
    keys = [key for key, _ in items]
    if items and all(type(key) is int for key in keys) and sorted(keys) == list(range(1, len(items) + 1)):
        result: list[object] = [None] * len(items)
        for key, value in items:
            result[key - 1] = value  # type: ignore[index]
        return result
    return {key: value for key, value in items if value is not None}


class _Parser:
    def __init__(self, text: str) -> None:
        self.text = text
        self.pos = 0

    def fail(self, message: str) -> None:
        line = self.text.count("\n", 0, self.pos) + 1
        raise LuaParseError(f"line {line}: {message}")

    def skip(self) -> None:
        self.pos = _SKIP.match(self.text, self.pos).end()  # type: ignore[union-attr]

    def take(self, token: str) -> bool:
        self.skip()
        if self.text.startswith(token, self.pos):
            self.pos += len(token)
            return True
        return False

    def expect(self, token: str) -> None:
        if not self.take(token):
            self.fail(f"expected {token!r}")

    def value(self) -> object:
        self.skip()
        text, pos = self.text, self.pos
        if pos >= len(text):
            self.fail("unexpected end of input")
        char = text[pos]
        if char == "{":
            self.pos += 1
            return self.table()
        if char in "\"'":
            match = (_DOUBLE_QUOTED if char == '"' else _SINGLE_QUOTED).match(text, pos)
            if not match:
                self.fail("unterminated string")
            self.pos = match.end()  # type: ignore[union-attr]
            return _unescape(match.group(1))  # type: ignore[union-attr]
        if char == "[":
            match = _LONG_STRING.match(text, pos)
            if not match:
                self.fail("unterminated long string")
            self.pos = match.end()  # type: ignore[union-attr]
            return match.group(2)  # type: ignore[union-attr]
        special = _SPECIAL_NUMBER.match(text, pos)
        if special and not _NAME.match(text, special.end()):
            self.pos = special.end()
            word = special.group().lower()
            magnitude = float("inf") if "inf" in word else float("nan")
            return -magnitude if special.group(1) else magnitude
        number = _NUMBER.match(text, pos)
        if number:
            self.pos = number.end()
            token = number.group()
            if token.lstrip("-")[:2].lower() == "0x":
                return int(token, 16)
            if any(c in token for c in ".eE"):
                return float(token)
            return int(token)
        name = _NAME.match(text, pos)
        if name and name.group() in ("nil", "true", "false"):
            self.pos = name.end()
            return {"nil": None, "true": True, "false": False}[name.group()]
        self.fail(f"unexpected {text[pos:pos + 20]!r}")
        return None  # unreachable

    def table(self) -> object:
        items: list[tuple[object, object]] = []
        index = 1
        while True:
            self.skip()
            text, pos = self.text, self.pos
            if text.startswith("}", pos):
                self.pos += 1
                return _table_value(items)
            name = _NAME.match(text, pos)
            if text.startswith("[", pos) and not _LONG_OPEN.match(text, pos):
                self.pos += 1
                key = self.value()
                self.expect("]")
                self.expect("=")
                items.append((key, self.value()))
            elif name and re.match(r"\s*=(?!=)", text[name.end() : name.end() + 32]):
                self.pos = name.end()
                self.expect("=")
                items.append((name.group(), self.value()))
            else:
                items.append((index, self.value()))
                index += 1
            if not (self.take(",") or self.take(";")):
                self.skip()
                if not self.text.startswith("}", self.pos):
                    self.fail("expected ',' or '}'")

    def statements(self) -> dict[str, object]:
        result: dict[str, object] = {}
        while True:
            self.skip()
            if self.pos >= len(self.text):
                return result
            name = _TARGET.match(self.text, self.pos)
            if not name:
                self.fail("expected a variable name")
            self.pos = name.end()  # type: ignore[union-attr]
            self.expect("=")
            result[name.group()] = self.value()  # type: ignore[union-attr]


def parse_savedvars(text: str) -> dict[str, object]:
    """Parse the text of a SavedVariables file into {variable name: value} (dotted targets keep their dots)."""
    return _Parser(text.lstrip("﻿")).statements()


def load_savedvars(path: Path) -> dict[str, object]:
    """Read and parse a SavedVariables file; bytes that are not UTF-8 survive until strings are decoded."""
    return parse_savedvars(Path(path).read_bytes().decode("utf-8", "surrogateescape"))
