# ruff: noqa: INP001  # a module beside the hook scripts that import it, which no package holds
"""The simple commands and redirections of a bash command, read from the syntax tree that shfmt writes.

The hooks of the build plugin that read a shell command import it, from the directory that holds them.
"""

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
    """A word of a shell command: its literal start, up to the first expansion, and whether that is all of it."""

    start: str
    complete: bool = True

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


def word(node: dict[str, object]) -> Word:
    """Return the word that a Word node of the syntax tree stands for."""
    start = ""
    for part in objects(node.get("Parts")):
        match string_field(part, "Type"):
            case "Lit":
                start += re.sub(r"\\(.)", r"\1", string_field(part, "Value"), flags=re.DOTALL)
            case "SglQuoted":
                start += string_field(part, "Value")
            case "DblQuoted":
                for inner in objects(part.get("Parts")):
                    if string_field(inner, "Type") != "Lit":
                        return Word(start, complete=False)
                    start += string_field(inner, "Value")
            case _:
                return Word(start, complete=False)
    return Word(start)


def calls_and_redirections(command: str) -> list[Call | Redirection] | None:
    """Return the simple commands and redirections of a bash command, or None when it does not parse as bash.

    Raises ParserMissingError when shfmt is not on the PATH.
    """
    try:
        parsed = subprocess.run(
            ["shfmt", "--language-dialect", "bash", "--to-json"],
            input=command.encode(),
            capture_output=True,
            check=False,
        )
    except FileNotFoundError as error:
        raise ParserMissingError from error
    if parsed.returncode != 0:
        return None
    source = command.encode()
    found: list[Call | Redirection] = []
    pending = objects(t.cast("object", json.loads(parsed.stdout)))
    while pending:
        node = pending.pop()
        if string_field(node, "Type") == "CallExpr":
            words = tuple(word(argument) for argument in objects(node.get("Args")))
            found.append(Call(words, source[offset(node, "Pos") : offset(node, "End")].decode()))
        for redirect in objects(node.get("Redirs")):
            target = objects(redirect.get("Word"))
            if target:
                operator = source[offset(redirect, "OpPos") : offset(target[0], "Pos")].decode().strip()
                span = source[offset(redirect, "Pos") : offset(redirect, "End")].decode()
                found.append(Redirection(operator, word(target[0]), span))
        pending.extend(reversed([item for value in node.values() for item in objects(value)]))
    return found


def command_name(value: str | None) -> str | None:
    """Return the name of the command that a word names, without its directory."""
    return None if value is None else pathlib.PurePath(value).name
