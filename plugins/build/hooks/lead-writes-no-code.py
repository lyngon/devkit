#!/usr/bin/env python3
"""PreToolUse hook of build:auto on Edit, Write, NotebookEdit and Bash: the lead writes no code.

Of a shell command it refuses the writes that it can name before the command runs: a redirection
that writes, and a command of WRITERS, also when find or xargs runs it. Any other program may
write files as well, an interpreter or git among them, and the hook cannot tell that from a read.
"""

import collections.abc as ct
import dataclasses
import json
import pathlib
import re
import subprocess
import sys
import typing as t

LEADS_DIRECTORIES: tuple[tuple[str, ...], ...] = (("tmp",), ("docs", "plans"), ("docs", "mistakes"))

DELEGATE = (
    'Start a build:implementer delegate (subagent_type "build:implementer") with a brief that names the file, '
    "and review its diff. "
    "The lead writes, by any tool, only under tmp/, docs/plans/ and docs/mistakes/ of the repository, and outside it"
)

BY_ITS_PATH = "and its command names such a file by a path without a variable or a substitution"

REDIRECTIONS_THAT_WRITE = frozenset({">", ">>", ">|", "&>", "&>>", "<>"})

RUNNERS = frozenset({"find", "xargs"})


@dataclasses.dataclass(frozen=True, slots=True)
class Word:
    """A word of a shell command, with its value, or None when an expansion decides it as the command runs."""

    value: str | None


UNSEEN = Word(None)


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


@dataclasses.dataclass(frozen=True, slots=True)
class Writer:
    """How a command that writes files takes its options, and which of its operands are the files it writes."""

    writes: t.Literal["every operand", "the last operand"]
    arguments: str = ""
    """Its short options whose argument is the rest of the word, or else the next word."""
    attached: str = ""
    """Its short options whose argument, if any, is the rest of the word."""
    long_arguments: frozenset[str] = frozenset()
    """Its long options whose argument is the next word, unless = joins it."""
    target_options: frozenset[str] = frozenset()
    """Its options whose argument is the file it writes, in place of its last operand."""
    only_with: frozenset[str] = frozenset()
    """The options without one of which it writes nothing, or none when it always writes."""
    script_options: frozenset[str] | None = None
    """The options that give it its script, without one of which its first operand is the script."""

    def targets(self, words: ct.Sequence[Word]) -> list[Word]:
        """Return the words of a call's arguments that name the files it writes."""
        options, operands = self.parse(words)
        names = {name for name, _ in options}
        named = [argument for name, argument in options if name in self.target_options]
        if self.only_with and not names & self.only_with:
            return []
        if self.script_options is not None and not names & self.script_options:
            operands = operands[1:]
        if self.writes == "the last operand":
            return named or operands[-1:]
        return named + operands

    def parse(self, words: ct.Sequence[Word]) -> tuple[list[tuple[str, Word]], list[Word]]:
        """Return the options of a call's arguments, each with its argument, and its operands."""
        options: list[tuple[str, Word]] = []
        operands: list[Word] = []
        index = 0
        while index < len(words):
            value = words[index].value
            if value == "--":
                operands.extend(words[index + 1 :])
                break
            if value is None or value == "-" or not value.startswith("-"):
                operands.append(words[index])
                index += 1
                continue
            following = words[index + 1] if index + 1 < len(words) else None
            given, takes_the_next = self.options(value, following)
            options.extend(given)
            index += 2 if takes_the_next else 1
        return options, operands

    def options(self, value: str, following: Word | None) -> tuple[list[tuple[str, Word]], bool]:
        """Return the options that a word starting with - gives, and whether the last takes the following word."""
        if value.startswith("--"):
            name, equals, rest = value.partition("=")
            if not equals and name in self.long_arguments and following is not None:
                return [(name, following)], True
            return [(name, Word(rest))], False
        given: list[tuple[str, Word]] = []
        for position, letter in enumerate(value[1:], start=2):
            rest = value[position:]
            if letter in self.arguments and not rest and following is not None:
                return [*given, (f"-{letter}", following)], True
            given.append((f"-{letter}", Word(rest)))
            if letter in self.arguments or letter in self.attached:
                break
        return given, False


TARGET_DIRECTORY = frozenset({"-t", "--target-directory"})

WRITERS: dict[str, Writer] = {
    "cp": Writer(
        "the last operand",
        arguments="St",
        long_arguments=frozenset({"--suffix", "--target-directory"}),
        target_options=TARGET_DIRECTORY,
    ),
    "mv": Writer(
        "every operand",
        arguments="St",
        long_arguments=frozenset({"--suffix", "--target-directory"}),
        target_options=TARGET_DIRECTORY,
    ),
    "perl": Writer(
        "every operand",
        arguments="eE",
        attached="CDdFIiMmVx",
        only_with=frozenset({"-i"}),
        script_options=frozenset({"-e", "-E"}),
    ),
    "rm": Writer("every operand"),
    "sed": Writer(
        "every operand",
        arguments="efl",
        attached="i",
        long_arguments=frozenset({"--expression", "--file", "--line-length"}),
        only_with=frozenset({"-i", "--in-place"}),
        script_options=frozenset({"-e", "-f", "--expression", "--file"}),
    ),
    "tee": Writer("every operand"),
    "touch": Writer("every operand", arguments="drt", long_arguments=frozenset({"--date", "--reference"})),
}


def in_the_change(path: pathlib.Path) -> bool:
    """Return whether the path is a file of a repository that the lead may not write."""
    repository = next((directory for directory in path.parents if (directory / ".git").exists()), None)
    if repository is None:
        return False
    parts = path.relative_to(repository).parts
    return not any(parts[: len(directory)] == directory for directory in LEADS_DIRECTORIES)


def json_object(value: object, name: str) -> dict[str, object]:
    """Return the value as a JSON object, whose keys are strings. Exits 1, naming it, when it is no object."""
    if not isinstance(value, dict):
        sys.exit(f"lead-writes-no-code.py: {name} is no JSON object")
    return t.cast("dict[str, object]", value)


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
    value = ""
    for part in objects(node.get("Parts")):
        match string_field(part, "Type"):
            case "Lit":
                value += re.sub(r"\\(.)", r"\1", string_field(part, "Value"), flags=re.DOTALL)
            case "SglQuoted":
                value += string_field(part, "Value")
            case "DblQuoted" if all(string_field(inner, "Type") == "Lit" for inner in objects(part.get("Parts"))):
                value += "".join(string_field(inner, "Value") for inner in objects(part.get("Parts")))
            case _:
                return UNSEEN
    return Word(value)


def calls_and_redirections(command: str) -> list[Call | Redirection] | None:
    """Return the simple commands and redirections of a bash command, or None when it does not parse as bash.

    Exits 1 when shfmt, which parses it, is not on the PATH.
    """
    try:
        parsed = subprocess.run(
            ["shfmt", "--language-dialect", "bash", "--to-json"],
            input=command.encode(),
            capture_output=True,
            check=False,
        )
    except FileNotFoundError:
        sys.exit("lead-writes-no-code.py: shfmt, which parses a command of the lead, is not on the PATH")
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


def written(part: Call | Redirection) -> list[Word]:
    """Return the words that name the files a part of a command writes, UNSEEN for files it cannot name."""
    if isinstance(part, Redirection):
        return [part.target] if part.operator in REDIRECTIONS_THAT_WRITE else []
    if not part.words:
        return []
    name, *arguments = part.words
    if command_name(name.value) in RUNNERS:
        for index, argument in enumerate(arguments):
            writer = WRITERS.get(command_name(argument.value) or "")
            if writer is not None:
                run = arguments[index + 1 :]
                ended = next((end for end, ran in enumerate(run) if ran.value in {";", "+"}), len(run))
                return writer.targets([*run[:ended], UNSEEN])
        return []
    writer = WRITERS.get(command_name(name.value) or "")
    return [] if writer is None else writer.targets(arguments)


def shell_write(command: str, cwd: pathlib.Path) -> str | None:
    """Return the text of the first part of a command that writes a file of the change, or None."""
    for part in calls_and_redirections(command) or []:
        for target in written(part):
            if target.value is None or in_the_change((cwd / target.value).resolve()):
                return part.text
    return None


def refusal(reason: str) -> dict[str, object]:
    """Return the hook's output that refuses the call for the reason."""
    return {
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": reason,
        }
    }


def answer(hook_input: dict[str, object]) -> dict[str, object] | None:
    """Return the hook's output for a call, or None to let it run as it is.

    Exits 1 when the call names no file or no command.
    """
    if "agent_id" in hook_input:
        return None
    tool_input = json_object(hook_input.get("tool_input"), "its tool_input")
    cwd = pathlib.Path(str(hook_input.get("cwd", "")))
    if hook_input.get("tool_name") == "Bash":
        command = tool_input.get("command")
        if not isinstance(command, str):
            sys.exit("lead-writes-no-code.py: its tool_input names no command")
        part = shell_write(command, cwd)
        if part is None:
            return None
        return refusal(
            f"In /build:auto the lead writes no code, so it may not write through `{part}`. {DELEGATE}, {BY_ITS_PATH}."
        )
    target = tool_input.get("file_path", tool_input.get("notebook_path"))
    if not isinstance(target, str):
        sys.exit("lead-writes-no-code.py: its tool_input names no file")
    if not in_the_change((cwd / target).resolve()):
        return None
    return refusal(f"In /build:auto the lead writes no code, so it may not write {target}. {DELEGATE}.")


def main() -> None:
    """Read the hook input on stdin and print the output, if any."""
    output = answer(json_object(t.cast("object", json.load(sys.stdin)), "the hook input"))
    if output is not None:
        json.dump(output, sys.stdout)


if __name__ == "__main__":
    main()
