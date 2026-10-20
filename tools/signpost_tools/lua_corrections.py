"""A static, safe reader for QuestieDB's Forever correction providers (Lua files read as data, never executed).

A provider is `function Module:Load() local questKeys = QuestieDB.questKeys ... return { [id] = { [questKeys.name] = "..",
[questKeys.requiredRaces] = raceIDs.ALL_HORDE + raceIDs.TROLL, [questKeys.finishedBy_add] = {nil, {630696}} } } end`.
This module tokenizes the file, parses the table constructors (comments, strings, numbers, nil holes, `a + b`), resolves the
named constants from QuestieDB's own enum and meta files (read the same way), and returns {id: {FieldRef: value}}.

Never guessed, never executed: anything that is not a literal or a named constant it can resolve (a function value, a call,
a conditional, an unknown name) is skipped and COUNTED by reason in `skipped`. The one call it evaluates is `l10n("text")`,
the identity on its literal argument (the text is never kept anywhere). A `Load` is read for its static return table only;
other functions (`LoadDynamic`: faction and class branches) and top-level runtime statements are counted, not read.

A Lua table with only positional entries becomes a list (nil holes are None); any other table a dict.
"""

from __future__ import annotations

import re
from collections import Counter
from dataclasses import dataclass, field
from pathlib import Path

__all__ = [
    "CorrectionsFormatError",
    "Environment",
    "FieldRef",
    "LuaSyntax",
    "ProviderResult",
    "Unresolved",
    "load_environment",
    "read_provider",
]

ENUM_DIR = "src/corrections/enum"
META_FILE = "src/meta/{}Meta.lua"
KINDS = ("quest", "npc", "object", "item")
OPERATIONS = (("_add", "add"), ("_remove", "remove"))


class CorrectionsFormatError(RuntimeError):
    """The QuestieDB files do not have the layout the reader relies on."""


class LuaSyntax(ValueError):
    """A construct the parser does not understand."""


class Unresolved(Exception):
    """A value that is not a literal or a resolvable named constant."""

    def __init__(self, reason: str) -> None:
        super().__init__(reason)
        self.reason = reason


@dataclass(frozen=True)
class FieldRef:
    """A record field named by a provider key, e.g. `questKeys.finishedBy_add` -> (quest, finishedBy, add)."""

    kind: str
    name: str
    op: str = "set"  # set, add or remove


class FieldNamespace:
    """`questKeys`, `npcKeys`, ...: the field names of one kind (positions come from the importer's own key tables)."""

    def __init__(self, kind: str, names: set[str]) -> None:
        self.kind = kind
        self.names = names

    def field(self, name: str) -> FieldRef:
        base, op = name, "set"
        for suffix, operation in OPERATIONS:
            if name.endswith(suffix):
                base, op = name[: -len(suffix)], operation
        if base not in self.names:
            raise Unresolved(f"unknown {self.kind} field {base}")
        return FieldRef(self.kind, base, op)


# Tokens ---------------------------------------------------------------------------------------------------------------

_NAME = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
_NUMBER = re.compile(r"0[xX][0-9a-fA-F]+|(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?")
_STRING = re.compile(r'"((?:[^"\\\n]|\\.)*)"|\'((?:[^\'\\\n]|\\.)*)\'', re.S)
_LONG = re.compile(r"\[(=*)\[(.*?)\]\1\]", re.S)
_LONG_COMMENT = re.compile(r"--\[(=*)\[.*?\]\1\]", re.S)
_ESCAPE = re.compile(r"\\(\d{1,3}|x[0-9a-fA-F]{2}|z\s*|[\s\S])")
_ESCAPES = {"n": "\n", "t": "\t", "r": "\r", "a": "\a", "b": "\b", "f": "\f", "v": "\v", "\n": "\n"}
_TWO_CHAR = ("..", "==", "~=", "<=", ">=")
_ONE_CHAR = "{}[]()=+-*/%^#,;:.<>"

Token = tuple  # (kind, value, column): kind is name, number, string, op or eof; column is 0-based in its line


def _unescape(raw: str) -> str:
    def replace(match: re.Match) -> str:
        code = match.group(1)
        if code[0].isdigit():
            return chr(int(code) & 0xFF)
        if code[0] == "x" and len(code) == 3:
            return chr(int(code[1:], 16))
        if code[0] == "z":
            return ""
        return _ESCAPES.get(code, code)

    return _ESCAPE.sub(replace, raw)


def tokenize(text: str) -> list[Token]:
    tokens: list[Token] = []
    pos, line_start, size = 0, 0, len(text)
    while pos < size:
        char = text[pos]
        if char == "\n":
            pos += 1
            line_start = pos
            continue
        if char in " \t\r\f\v":
            pos += 1
            continue
        column = pos - line_start
        if text.startswith("--", pos):
            match = _LONG_COMMENT.match(text, pos)
            if match:
                newline = text.rfind("\n", pos, match.end())
                if newline >= 0:
                    line_start = newline + 1
                pos = match.end()
            else:
                end = text.find("\n", pos)
                pos = size if end < 0 else end
            continue
        if char == "[" and (match := _LONG.match(text, pos)):
            tokens.append(("string", match.group(2).removeprefix("\n"), column))
            newline = text.rfind("\n", pos, match.end())
            if newline >= 0:
                line_start = newline + 1
            pos = match.end()
            continue
        if char in "\"'":
            match = _STRING.match(text, pos)
            if not match:  # an unterminated string: a token no rule accepts, so the entry holding it is skipped
                tokens.append(("op", char, column))
                pos += 1
                continue
            raw = match.group(1) if match.group(1) is not None else match.group(2)
            tokens.append(("string", _unescape(raw), column))
            pos = match.end()
            continue
        if char.isdigit() or (char == "." and pos + 1 < size and text[pos + 1].isdigit()):
            match = _NUMBER.match(text, pos)
            assert match  # noqa: S101 - the guard above guarantees a digit
            tokens.append(("number", match.group(0), column))
            pos = match.end()
            continue
        if char.isalpha() or char == "_":
            match = _NAME.match(text, pos)
            assert match  # noqa: S101
            tokens.append(("name", match.group(0), column))
            pos = match.end()
            continue
        if text.startswith("...", pos):
            tokens.append(("op", "...", column))
            pos += 3
        elif text[pos : pos + 2] in _TWO_CHAR:
            tokens.append(("op", text[pos : pos + 2], column))
            pos += 2
        elif char in _ONE_CHAR:
            tokens.append(("op", char, column))
            pos += 1
        else:  # a character Lua does not use (an `@`, `!`, ...): a token no rule accepts, so its entry is skipped
            tokens.append(("op", char, column))
            pos += 1
    tokens.append(("eof", "", 0))
    return tokens


def number_value(text: str) -> int | float:
    if text[:2] in ("0x", "0X"):
        return int(text, 16)
    if text.isdigit():
        return int(text)
    value = float(text)
    return value


# Parser ---------------------------------------------------------------------------------------------------------------

# (left, right) binding powers, as in Lua's own grammar.
_BINARY = {
    "or": (1, 1),
    "and": (2, 2),
    "<": (3, 3),
    ">": (3, 3),
    "<=": (3, 3),
    ">=": (3, 3),
    "~=": (3, 3),
    "==": (3, 3),
    "..": (9, 8),
    "+": (10, 10),
    "-": (10, 10),
    "*": (11, 11),
    "/": (11, 11),
    "%": (11, 11),
    "^": (14, 13),
}
_UNARY_POWER = 12
_BLOCK_OPEN = ("function", "if", "do")
_BLOCK_KEYWORDS = ("function", "if", "do", "for", "while")


class Parser:
    """Recursive-descent parser for Lua expressions (as tuples) over a token list."""

    def __init__(self, tokens: list[Token], pos: int = 0, skipped: Counter | None = None) -> None:
        self.tokens = tokens
        self.pos = pos
        self.skipped: Counter = skipped if skipped is not None else Counter()

    def peek(self, offset: int = 0) -> Token:
        return self.tokens[min(self.pos + offset, len(self.tokens) - 1)]

    def at_op(self, value: str, offset: int = 0) -> bool:
        token = self.peek(offset)
        return token[0] == "op" and token[1] == value

    def at_name(self, value: str, offset: int = 0) -> bool:
        token = self.peek(offset)
        return token[0] == "name" and token[1] == value

    def expect_op(self, value: str) -> None:
        if not self.at_op(value):
            raise LuaSyntax(f"expected {value}")
        self.pos += 1

    def skip_block(self) -> None:
        """Past the `end` that closes the block opened just before (a function, if or do body)."""
        depth = 1
        while depth:
            kind, value, _ = self.peek()
            if kind == "eof":
                raise LuaSyntax("unterminated block")
            self.pos += 1
            if kind == "name" and value in _BLOCK_OPEN:
                depth += 1
            elif kind == "name" and value == "end":
                depth -= 1

    def skip_statement_block(self, keyword: str) -> None:
        """Past a whole `function`, `if`, `do`, `for` or `while` statement whose keyword was just consumed."""
        if keyword == "function":
            while self.peek()[0] == "name" or self.at_op(".") or self.at_op(":"):
                self.pos += 1
            self.skip_function()
            return
        if keyword in ("for", "while"):
            while not self.at_name("do"):
                if self.peek()[0] == "eof":
                    raise LuaSyntax("unterminated loop header")
                self.pos += 1
            self.pos += 1
        self.skip_block()

    def expr(self, limit: int = 0) -> tuple:
        token = self.peek()
        if token[0] == "op" and token[1] == "-":
            self.pos += 1
            left: tuple = ("neg", self.expr(_UNARY_POWER))
        elif (token[0] == "op" and token[1] == "#") or (token[0] == "name" and token[1] == "not"):
            self.pos += 1
            left = ("unary", token[1], self.expr(_UNARY_POWER))
        else:
            left = self.simple()
        while True:
            token = self.peek()
            operator = token[1] if token[0] == "op" or (token[0] == "name" and token[1] in ("and", "or")) else None
            if operator not in _BINARY:
                return left
            left_power, right_power = _BINARY[operator]
            if left_power <= limit:
                return left
            self.pos += 1
            left = ("bin", operator, left, self.expr(right_power))

    def simple(self) -> tuple:
        kind, value, _ = self.peek()
        self.pos += 1
        if kind == "number":
            node: tuple = ("num", number_value(value))
        elif kind == "string":
            node = ("str", value)
        elif kind == "name":
            if value in ("nil", "true", "false"):
                node = ("nil",) if value == "nil" else ("bool", value == "true")
            elif value == "function":
                self.skip_function()
                node = ("func",)
            else:
                node = ("name", value)
        elif kind == "op" and value == "{":
            self.pos -= 1
            node = self.table()
        elif kind == "op" and value == "(":
            node = self.expr()
            self.expect_op(")")
        elif kind == "op" and value == "...":
            node = ("vararg",)
        else:
            raise LuaSyntax("unexpected token in an expression")
        return self.suffixes(node)

    def skip_function(self) -> None:
        self.expect_op("(")
        depth = 1
        while depth:
            kind, value, _ = self.peek()
            if kind == "eof":
                raise LuaSyntax("unterminated parameter list")
            self.pos += 1
            if kind == "op" and value == "(":
                depth += 1
            elif kind == "op" and value == ")":
                depth -= 1
        self.skip_block()

    def suffixes(self, node: tuple) -> tuple:
        while True:
            kind, value, _ = self.peek()
            if kind == "op" and value == ".":
                name = self.peek(1)
                if name[0] != "name":
                    raise LuaSyntax("expected a field name")
                self.pos += 2
                node = ("field", node, name[1])
            elif kind == "op" and value == "[":
                self.pos += 1
                key = self.expr()
                self.expect_op("]")
                node = ("index", node, key)
            elif kind == "op" and value == ":" and self.peek(1)[0] == "name":
                self.pos += 2
                node = ("call", ("field", node, self.tokens[self.pos - 1][1]), self.call_arguments())
            elif (kind == "op" and value in ("(", "{")) or kind == "string":
                node = ("call", node, self.call_arguments())
            else:
                return node

    def call_arguments(self) -> list[tuple]:
        kind, value, _ = self.peek()
        if kind == "string":
            self.pos += 1
            return [("str", value)]
        if kind == "op" and value == "{":
            return [self.table()]
        self.expect_op("(")
        arguments: list[tuple] = []
        while not self.at_op(")"):
            arguments.append(self.expr())
            if self.at_op(","):
                self.pos += 1
            elif not self.at_op(")"):
                raise LuaSyntax("expected , or ) in call arguments")
        self.pos += 1
        return arguments

    def table(self, recover: int = 0) -> tuple:
        """A table constructor. With `recover` > 0, an entry that does not parse is skipped and counted (that many table
        levels deep), instead of failing the whole table."""
        self.expect_op("{")
        entries: list[tuple] = []
        while not self.at_op("}"):
            if self.peek()[0] == "eof":
                raise LuaSyntax("unterminated table")
            start = self.pos
            try:
                entries.append(self.entry(recover))
                if self.at_op(",") or self.at_op(";"):
                    self.pos += 1
                elif not self.at_op("}"):
                    raise LuaSyntax("expected , or } between table entries")
            except LuaSyntax as exc:
                if not recover:
                    raise
                self.skipped[f"unparsable entry ({exc})"] += 1
                self.pos = start
                self.skip_entry()
        self.pos += 1
        return ("table", entries)

    def entry(self, recover: int) -> tuple:
        if self.at_op("["):
            self.pos += 1
            key = self.expr()
            self.expect_op("]")
            self.expect_op("=")
            return key, self.value(recover)
        token = self.peek()
        if token[0] == "name" and self.at_op("=", 1):
            self.pos += 2
            return ("str", token[1]), self.value(recover)
        return None, self.value(recover)

    def value(self, recover: int) -> tuple:
        if recover > 0 and self.at_op("{"):
            return self.table(recover - 1)
        return self.expr()

    def skip_entry(self) -> None:
        depth = 0
        while True:
            kind, value, _ = self.peek()
            if kind == "eof":
                return
            if kind == "op" and value in "{[(":
                depth += 1
            elif kind == "op" and value in "}])":
                if depth == 0:
                    return
                depth -= 1
            elif kind == "op" and value in ",;" and depth == 0:
                self.pos += 1
                return
            self.pos += 1


# Evaluating -----------------------------------------------------------------------------------------------------------


def describe(node: tuple) -> str:
    """A node as dotted text, for the skip reasons (names only, no values)."""
    if node[0] == "name":
        return node[1]
    if node[0] == "field":
        return f"{describe(node[1])}.{node[2]}"
    if node[0] == "index":
        return f"{describe(node[1])}[]"
    if node[0] == "call":
        return f"{describe(node[1])}()"
    return "expression"


class Scope:
    """Variables: roots (known tables), plus local aliases (`local questKeys = QuestieDB.questKeys`), evaluated lazily."""

    def __init__(self, roots: dict[str, object], aliases: dict[str, tuple] | None = None) -> None:
        self.vars: dict[str, object] = dict(roots)
        self.aliases = aliases or {}
        self._evaluating: set[str] = set()

    def lookup(self, name: str) -> object:
        if name in self.aliases:
            if name in self._evaluating:
                raise Unresolved(f"circular alias {name}")
            self._evaluating.add(name)
            try:
                self.vars[name] = evaluate(self.aliases.pop(name), self)
            finally:
                self._evaluating.discard(name)
        if name in self.vars:
            return self.vars[name]
        raise Unresolved(f"unresolved name {name}")


def _number(value: object) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def evaluate(node: tuple, scope: Scope) -> object:
    """The value of an expression node, or Unresolved. Nothing is executed."""
    kind = node[0]
    if kind in ("num", "str", "bool"):
        return node[1]
    if kind == "nil":
        return None
    if kind == "name":
        return scope.lookup(node[1])
    if kind == "field":
        base = evaluate(node[1], scope)
        if isinstance(base, FieldNamespace):
            return base.field(node[2])
        if isinstance(base, dict) and node[2] in base:
            return base[node[2]]
        raise Unresolved(f"unresolved constant {describe(node)}")
    if kind == "index":
        base, key = evaluate(node[1], scope), evaluate(node[2], scope)
        if isinstance(base, dict) and isinstance(key, (int, str)) and key in base:
            return base[key]
        if isinstance(base, list) and isinstance(key, int) and 0 < key <= len(base) and base[key - 1] is not None:
            return base[key - 1]
        raise Unresolved(f"unresolved constant {describe(node)}")
    if kind == "neg":
        value = evaluate(node[1], scope)
        if _number(value):
            return -value
        raise Unresolved("operator - on a non-number")
    if kind == "bin":
        if node[1] not in ("+", "-", "*"):
            raise Unresolved(f"operator {node[1]}")
        left, right = evaluate(node[2], scope), evaluate(node[3], scope)
        if not (_number(left) and _number(right)):
            raise Unresolved(f"operator {node[1]} on non-numbers")
        return left + right if node[1] == "+" else left - right if node[1] == "-" else left * right
    if kind == "table":
        return evaluate_table(node, scope)
    if kind == "call":
        callee, arguments = node[1], node[2]
        if callee == ("name", "l10n") and len(arguments) == 1 and arguments[0][0] == "str":
            return arguments[0][1]  # the identity on its text; text is never kept
        raise Unresolved(f"call to {describe(callee)}")
    if kind == "func":
        raise Unresolved("function value")
    raise Unresolved(f"unsupported expression ({kind})")


def evaluate_table(node: tuple, scope: Scope) -> list | dict:
    positional: list[object] = []
    keyed: dict[object, object] = {}
    for key_node, value_node in node[1]:
        value = evaluate(value_node, scope)
        if key_node is None:
            positional.append(value)
            continue
        key = evaluate(key_node, scope)
        if isinstance(key, float) and key.is_integer():
            key = int(key)
        if not isinstance(key, (int, str, FieldRef)) or isinstance(key, bool):
            raise Unresolved("table key is not a number, string or field")
        if value is not None:
            keyed[key] = value
    if not keyed:
        return positional
    for index, value in enumerate(positional, 1):
        if value is not None:
            keyed.setdefault(index, value)
    return keyed


# Reading Lua files as data --------------------------------------------------------------------------------------------


def _read_text(path: Path) -> str:
    try:
        return path.read_bytes().decode("utf-8", "replace")
    except OSError as exc:
        raise CorrectionsFormatError(f"{path}: {exc}") from exc


def _skip_statement(parser: Parser) -> None:
    """To the next token that starts in column 1 (the top-level statements of QuestieDB's data files do)."""
    parser.pos += 1
    while parser.peek()[0] != "eof" and parser.peek()[2] != 0:
        parser.pos += 1


def read_file_vars(path: Path, preseed: dict[str, object]) -> tuple[dict[str, object], Counter]:
    """The top-level `local x = <expr>` and `a.b.c = <expr>` assignments of a data file (enum or meta), evaluated against
    `preseed` (the shared constants table etc.). Blocks (functions, `if`) are skipped; what cannot be evaluated is counted."""
    parser = Parser(tokenize(_read_text(path)))
    scope = Scope(preseed)
    skipped: Counter = Counter()
    while parser.peek()[0] != "eof":
        kind, value, _ = parser.peek()
        try:
            if kind == "name" and value == "local":
                names = []
                parser.pos += 1
                while parser.peek()[0] == "name":
                    names.append(parser.peek()[1])
                    parser.pos += 1
                    if parser.at_op(","):
                        parser.pos += 1
                if not parser.at_op("="):
                    continue
                parser.pos += 1
                node = parser.expr()
                if len(names) == 1:
                    try:
                        scope.vars[names[0]] = evaluate(node, scope)
                    except Unresolved as exc:
                        skipped[exc.reason] += 1
            elif kind == "name" and value in _BLOCK_KEYWORDS:
                parser.pos += 1
                parser.skip_statement_block(value)
            elif kind == "name" and parser.peek(1)[0] == "op" and parser.peek(1)[1] in ".[=":
                target = _parse_target(parser)
                parser.expect_op("=")
                node = parser.expr()
                try:
                    _assign(scope, target, evaluate(node, scope))
                except Unresolved as exc:
                    skipped[exc.reason] += 1
            else:
                parser.pos += 1
        except LuaSyntax:
            _skip_statement(parser)
    return scope.vars, skipped


def _parse_target(parser: Parser) -> tuple:
    _, value, _ = parser.peek()
    parser.pos += 1
    node: tuple = ("name", value)
    while parser.at_op(".") or parser.at_op("["):
        if parser.at_op("."):
            name = parser.peek(1)
            if name[0] != "name":
                raise LuaSyntax("expected a field name")
            parser.pos += 2
            node = ("field", node, name[1])
        else:
            parser.pos += 1
            key = parser.expr()
            parser.expect_op("]")
            node = ("index", node, key)
    return node


def _assign(scope: Scope, target: tuple, value: object) -> None:
    if target[0] == "name":
        scope.vars[target[1]] = value
        return
    base = evaluate(target[1], scope)
    key = target[2] if target[0] == "field" else evaluate(target[2], scope)
    if not isinstance(base, dict):
        raise Unresolved(f"assignment to {describe(target)}")
    base[key] = value


# The environment: constants from QuestieDB's own files ------------------------------------------------------------------


@dataclass
class Environment:
    """What a provider's names resolve to, read from a QuestieDB checkout."""

    roots: dict[str, object]
    skipped: Counter = field(default_factory=Counter)  # constants the enum and meta files could not give
    sources: list[str] = field(default_factory=list)
    shapes: dict[str, dict[str, str]] = field(default_factory=dict)  # kind -> field -> meta shape (idarray, questgivers ...)

    def scope(self, aliases: dict[str, tuple] | None = None) -> Scope:
        return Scope(self.roots, aliases)


def load_environment(root: Path) -> Environment:
    """Read the enum and meta files of a QuestieDB checkout (src/corrections/enum, src/meta) as data."""
    enum_dir = root / ENUM_DIR
    if not enum_dir.is_dir():
        raise CorrectionsFormatError(f"{enum_dir} is missing")
    shared: dict[str, object] = {}
    skipped: Counter = Counter()
    sources = []
    # expansions.lua refers to raceMaskById (constants.lua / expansions.lua itself): read it after the others.
    files = sorted(enum_dir.glob("*.lua"), key=lambda path: (path.name == "expansions.lua", path.name))
    for path in files:
        preseed: dict[str, object] = {"LibQuestieDB": {"Enum": shared}, "constants": shared}
        _, file_skipped = read_file_vars(path, preseed)
        skipped.update(file_skipped)
        sources.append(path.name)
    by_expansion = shared.get("byExpansion")
    if not isinstance(by_expansion, dict) or not isinstance(by_expansion.get("Forever"), dict):
        raise CorrectionsFormatError(f"{enum_dir / 'expansions.lua'}: no byExpansion.Forever")
    forever, classic = by_expansion["Forever"], by_expansion.get("Classic") or {}

    def pick(name: str) -> object:
        # QuestieDB's compat layer: a flavor's own table, else its rules flavor's whole table (Forever falls back to Classic).
        return forever.get(name) if name in forever else classic.get(name)

    namespaces: dict[str, object] = {}
    shapes: dict[str, dict[str, str]] = {}
    for kind in KINDS:
        meta_path = root / META_FILE.format(kind)
        meta_vars, meta_skipped = read_file_vars(meta_path, {"LibQuestieDB": {"Meta": {}}})
        skipped.update(meta_skipped)
        meta = meta_vars.get("meta")
        keys = meta.get("keys") if isinstance(meta, dict) else None
        if not isinstance(keys, dict) or not keys:
            raise CorrectionsFormatError(f"{meta_path}: no keys table")
        namespaces[f"{kind}Keys"] = FieldNamespace(kind, set(keys))
        structures = meta.get("structures") if isinstance(meta, dict) else None
        by_index = {index: name for name, index in keys.items()}
        shapes[kind] = {
            by_index[index]: shape
            for index, shape in (structures if isinstance(structures, dict) else {}).items()
            if index in by_index and isinstance(shape, str)
        }
        sources.append(meta_path.name)
    questie_db: dict[str, object] = dict(namespaces)
    for name, value in (
        ("raceKeys", pick("raceKeys")),
        ("classKeys", pick("classKeys")),
        ("npcFlags", pick("npcFlags")),
        ("sortKeys", shared.get("sortKeys")),
        ("specialFlags", shared.get("specialFlags")),
        ("questFlags", shared.get("questFlags")),
        ("factionIDs", shared.get("factionIDs")),
        ("itemClasses", shared.get("itemClasses")),
        ("waypointPresets", shared.get("waypointPresets")),
    ):
        if isinstance(value, dict):
            questie_db[name] = value
    roots: dict[str, object] = {
        "QuestieDB": questie_db,
        "ZoneDB": {"zoneIDs": shared.get("zoneIDs") or {}},
        "QuestieProfessions": {
            name: shared.get(name) or {} for name in ("professionKeys", "specializationKeys", "rankNames")
        },
        "Phasing": {"phases": shared.get("phases") or {}},
        "Questie": shared.get("iconTypes") or {},
    }
    if not roots["ZoneDB"]["zoneIDs"]:  # type: ignore[index]
        raise CorrectionsFormatError(f"{enum_dir / 'zones.lua'}: no zoneIDs")
    return Environment(roots, skipped, sources, shapes)


# Providers ------------------------------------------------------------------------------------------------------------


@dataclass
class ProviderResult:
    records: dict[int, dict[FieldRef, object]] = field(default_factory=dict)
    skipped: Counter = field(default_factory=Counter)  # reason -> count (constructs, fields, records skipped)
    fields_read: int = 0
    found_load: bool = False


def _function_name(parser: Parser) -> str:
    """After `function`: Module:Load( ... ) -> "Module:Load"; the parser is left after the parameter list."""
    parts = []
    while parser.peek()[0] == "name":
        parts.append(parser.peek()[1])
        parser.pos += 1
        if parser.at_op(".") or parser.at_op(":"):
            parts.append(parser.peek()[1])
            parser.pos += 1
    parser.expect_op("(")
    depth = 1
    while depth and parser.peek()[0] != "eof":
        if parser.at_op("("):
            depth += 1
        elif parser.at_op(")"):
            depth -= 1
        parser.pos += 1
    return "".join(parts)


def _read_load_body(parser: Parser, result: ProviderResult) -> tuple[dict[str, tuple], tuple | None]:
    """Aliases and the returned table (as a node) of a `Load` body; leaves the parser after the function's `end`."""
    aliases: dict[str, tuple] = {}
    returned: tuple | None = None
    while True:
        kind, value, _ = parser.peek()
        if kind == "eof":
            raise LuaSyntax("unterminated function")
        if kind == "name" and value == "end":
            parser.pos += 1
            return aliases, returned
        if kind == "name" and value == "local":
            parser.pos += 1
            names = []
            while parser.peek()[0] == "name":
                names.append(parser.peek()[1])
                parser.pos += 1
                if parser.at_op(","):
                    parser.pos += 1
            if parser.at_op("="):
                parser.pos += 1
                node = parser.expr()
                if len(names) == 1:
                    aliases[names[0]] = node
            continue
        if kind == "name" and value == "return":
            parser.pos += 1
            if parser.at_op("{") and returned is None:
                returned = parser.table(recover=2)
            else:
                result.skipped["return that is not a literal table"] += 1
                parser.expr()
            continue
        result.skipped[f"statement in Load that is not a local or return ({value})"] += 1
        parser.pos += 1
        if value in _BLOCK_KEYWORDS:
            parser.skip_statement_block(value)


def read_provider(path: Path, env: Environment, kind: str) -> ProviderResult:
    """The static records of a provider file: {id: {FieldRef: value}}, with what was skipped counted by reason."""
    result = ProviderResult()
    parser = Parser(tokenize(_read_text(path)), skipped=result.skipped)
    aliases: dict[str, tuple] = {}
    returned: tuple | None = None
    while parser.peek()[0] != "eof":
        kind_token, value, column = parser.peek()
        if kind_token == "name" and value == "function":
            parser.pos += 1
            name = _function_name(parser)
            if name.replace(":", ".").split(".")[-1] == "Load" and not result.found_load:
                result.found_load = True
                aliases, returned = _read_load_body(parser, result)
            else:
                parser.skip_block()  # after the parameter list that _function_name consumed
                result.skipped[f"runtime function {name.split(':')[-1].split('.')[-1]} (not read)"] += 1
        elif kind_token == "name" and value == "local" and column == 0:
            _skip_statement(parser)
        elif kind_token == "name" and value == "return":
            parser.pos += 1
        elif kind_token == "name" and column == 0:
            result.skipped["top-level runtime statement (not read)"] += 1
            _skip_statement(parser)
        else:
            parser.pos += 1
    if returned is None:
        result.skipped["no static return table in Load"] += 1
        return result
    scope = env.scope(aliases)
    for key_node, value_node in returned[1]:
        try:
            record_id = evaluate(key_node, scope) if key_node is not None else None
        except Unresolved as exc:
            result.skipped[f"record key: {exc.reason}"] += 1
            continue
        if isinstance(record_id, float) and record_id.is_integer():
            record_id = int(record_id)
        if not (isinstance(record_id, int) and not isinstance(record_id, bool) and record_id > 0):
            result.skipped["record key that is not a positive integer"] += 1
            continue
        if value_node[0] != "table":
            result.skipped["record that is not a table constructor"] += 1
            continue
        fields = result.records.setdefault(record_id, {})
        for field_key, field_value in value_node[1]:
            if field_key is None:
                result.skipped["positional entry in a record"] += 1
                continue
            try:
                reference = evaluate(field_key, scope)
                if not (isinstance(reference, FieldRef) and reference.kind == kind):
                    raise Unresolved(f"key that is not a {kind} field")
                value_found = evaluate(field_value, scope)
            except Unresolved as exc:
                result.skipped[exc.reason] += 1
                continue
            fields[reference] = value_found
            result.fields_read += 1
    return result
