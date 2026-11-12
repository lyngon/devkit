# ruff: noqa: INP001  # a module beside the hook scripts that import it, which no package holds
"""The simple commands and redirections of a shell command, read from the syntax tree that shfmt writes.

The hooks of the build plugin that read a shell command import it, from the directory that holds them.
"""

import collections
import collections.abc as ct
import dataclasses
import json
import pathlib
import re
import subprocess
import typing as t


class ParserMissingError(Exception):
    """shfmt, which parses a command, is not on the PATH."""


@dataclasses.dataclass(frozen=True, slots=True)
class Word:
    """A word of a shell command: its literal start, up to the first expansion, whether that is all, and its text."""

    start: str
    complete: bool = True
    text: str = dataclasses.field(default="", kw_only=True)

    @property
    def value(self) -> str | None:
        """Return the whole word, or None when an expansion decides part of it as the command runs."""
        return self.start if self.complete else None


UNSEEN = Word("", complete=False)


@dataclasses.dataclass(frozen=True, slots=True)
class Call:
    """A simple command: its words, the first its name, and its text in the command."""

    words: tuple[Word, ...]
    text: str


@dataclasses.dataclass(frozen=True, slots=True)
class Redirection:
    """A redirection: its operator, the word it redirects to, and its text in the command."""

    operator: str
    target: Word
    text: str


SIMPLE_EXPANSION = frozenset({"Type", "Pos", "End", "Dollar", "Rbrace", "Short", "Param"})


def objects(value: object) -> list[dict[str, object]]:
    """Return the JSON objects that a value of the syntax tree holds: itself, or the items of a list."""
    items = t.cast("list[object]", value) if isinstance(value, list) else [value]
    return [t.cast("dict[str, object]", item) for item in items if isinstance(item, dict)]


def offset(node: dict[str, object], key: str) -> int:
    """Return the byte offset of a position of a node of the syntax tree."""
    position = objects(node.get(key))
    value = position[0].get("Offset") if position else None
    return value if isinstance(value, int) else 0


def string_field(node: dict[str, object], key: str) -> str:
    """Return a string field of a node of the syntax tree, or an empty one."""
    value = node.get(key)
    return value if isinstance(value, str) else ""


def name_of(node: dict[str, object]) -> str:
    """Return the name that a node of the syntax tree gives in its Name or Param field, or an empty one."""
    names = objects(node.get("Name", node.get("Param")))
    return string_field(names[0], "Value") if names else ""


def expanded(part: dict[str, object], variables: ct.Mapping[str, str]) -> str | None:
    """Return the value of a part of a word that expands a variable of variables plainly, as $T or ${T}, or None."""
    if string_field(part, "Type") != "ParamExp" or not part.keys() <= SIMPLE_EXPANSION:
        return None
    return variables.get(name_of(part))


def word(node: dict[str, object], source: bytes, variables: ct.Mapping[str, str]) -> Word:
    """Return the word that a Word node of the syntax tree stands for, with the variables of variables expanded."""
    text = source[offset(node, "Pos") : offset(node, "End")].decode()
    start = ""
    for part in objects(node.get("Parts")):
        match string_field(part, "Type"):
            case "Lit":
                start += re.sub(r"\\(.)", r"\1", string_field(part, "Value"), flags=re.DOTALL)
            case "SglQuoted":
                start += string_field(part, "Value")
            case "DblQuoted":
                for inner in objects(part.get("Parts")):
                    value = string_field(inner, "Value") if string_field(inner, "Type") == "Lit" else None
                    value = expanded(inner, variables) if value is None else value
                    if value is None:
                        return Word(start, complete=False, text=text)
                    start += value
            case _ if (value := expanded(part, variables)) is not None:
                start += value
            case _:
                return Word(start, complete=False, text=text)
    return Word(start, text=text)


def nodes_in_order(tree: object) -> ct.Iterator[dict[str, object]]:
    """Yield the nodes of the syntax tree in the order of their text in the command."""
    pending = objects(tree)
    while pending:
        node = pending.pop()
        yield node
        pending.extend(reversed([item for value in node.values() for item in objects(value)]))


def literal_variables(nodes: ct.Sequence[dict[str, object]], source: bytes) -> dict[str, str]:
    """Return the variables that a command assigns once, each to a value without an expansion, with their values.

    A loop variable, a variable assigned twice and an array take more than one value, so none of them is returned.
    """
    assignments = [node for node in nodes if "Name" in node and "Type" not in node]
    loops = [node for node in nodes if string_field(node, "Type") == "WordIter"]
    counts = collections.Counter(name_of(node) for node in [*assignments, *loops, *loops])
    variables: dict[str, str] = {}
    for assignment in assignments:
        values = objects(assignment.get("Value"))
        if counts[name_of(assignment)] == 1 and values and not assignment.get("Append"):
            value = word(values[0], source, variables).value
            if value is not None:
                variables[name_of(assignment)] = value
    return variables


def calls_and_redirections(
    command: str, dialects: ct.Sequence[str] = ("bash",), *, resolve_variables: bool = False
) -> list[Call | Redirection] | None:
    """Return the simple commands and redirections of a shell command, or None when it parses in none of the dialects.

    Each dialect is a language of shfmt, tried in turn. With resolve_variables, a plain expansion of a variable that
    the command assigns once, to a value without an expansion, stands for that value.
    Raises ParserMissingError when shfmt is not on the PATH.
    """
    parsed = None
    for dialect in dialects:
        try:
            parsed = subprocess.run(
                ["shfmt", "--language-dialect", dialect, "--to-json"],
                input=command.encode(),
                capture_output=True,
                check=False,
            )
        except FileNotFoundError as error:
            raise ParserMissingError from error
        if parsed.returncode == 0:
            break
    if parsed is None or parsed.returncode != 0:
        return None
    source = command.encode()
    nodes = list(nodes_in_order(t.cast("object", json.loads(parsed.stdout))))
    variables = literal_variables(nodes, source) if resolve_variables else {}
    found: list[Call | Redirection] = []
    for node in nodes:
        if string_field(node, "Type") == "CallExpr":
            words = tuple(word(argument, source, variables) for argument in objects(node.get("Args")))
            found.append(Call(words, source[offset(node, "Pos") : offset(node, "End")].decode()))
        for redirect in objects(node.get("Redirs")):
            target = objects(redirect.get("Word"))
            if target:
                operator = source[offset(redirect, "OpPos") : offset(target[0], "Pos")].decode().strip()
                span = source[offset(redirect, "Pos") : offset(redirect, "End")].decode()
                found.append(Redirection(operator, word(target[0], source, variables), span))
    return found


def command_name(value: str | None) -> str | None:
    """Return the name of the command that a word names, without its directory."""
    return None if value is None else pathlib.PurePath(value).name
