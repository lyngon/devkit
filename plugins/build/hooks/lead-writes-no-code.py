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
import sys
import typing as t

import shell_syntax

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
class Writer:
    """How a command that writes files takes its options, and which of its operands are the files it writes."""

    writes: t.Literal["every operand", "the last operand"]
    short_with_argument: str = ""
    short_with_attached_argument: str = ""
    long_with_argument: frozenset[str] = frozenset()
    target_options: frozenset[str] = frozenset()
    writes_only_with: frozenset[str] = frozenset()
    script_options: frozenset[str] | None = None

    def targets(self, words: ct.Sequence[shell_syntax.Word]) -> list[shell_syntax.Word]:
        """Return the words of a call's arguments that name the files it writes."""
        options, operands = self.parse(words)
        names = {name for name, _ in options}
        named = [argument for name, argument in options if name in self.target_options]
        if self.writes_only_with and not names & self.writes_only_with:
            return []
        if self.script_options is not None and not names & self.script_options:
            operands = operands[1:]
        if self.writes == "the last operand":
            return named or operands[-1:]
        return named + operands

    def parse(
        self, words: ct.Sequence[shell_syntax.Word]
    ) -> tuple[list[tuple[str, shell_syntax.Word]], list[shell_syntax.Word]]:
        """Return the options of a call's arguments, each with its argument, and its operands."""
        options: list[tuple[str, shell_syntax.Word]] = []
        operands: list[shell_syntax.Word] = []
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

    def options(
        self, value: str, following: shell_syntax.Word | None
    ) -> tuple[list[tuple[str, shell_syntax.Word]], bool]:
        """Return the options that a word starting with - gives, and whether the last takes the following word."""
        if value.startswith("--"):
            name, equals, rest = value.partition("=")
            if not equals and name in self.long_with_argument and following is not None:
                return [(name, following)], True
            return [(name, shell_syntax.Word(rest))], False
        given: list[tuple[str, shell_syntax.Word]] = []
        for position, letter in enumerate(value[1:], start=2):
            rest = value[position:]
            if letter in self.short_with_argument and not rest and following is not None:
                return [*given, (f"-{letter}", following)], True
            given.append((f"-{letter}", shell_syntax.Word(rest)))
            if letter in self.short_with_argument or letter in self.short_with_attached_argument:
                break
        return given, False


TARGET_DIRECTORY = frozenset({"-t", "--target-directory"})

WRITERS: dict[str, Writer] = {
    "cp": Writer(
        "the last operand",
        short_with_argument="St",
        long_with_argument=frozenset({"--suffix", "--target-directory"}),
        target_options=TARGET_DIRECTORY,
    ),
    "mv": Writer(
        "every operand",
        short_with_argument="St",
        long_with_argument=frozenset({"--suffix", "--target-directory"}),
        target_options=TARGET_DIRECTORY,
    ),
    "perl": Writer(
        "every operand",
        short_with_argument="eE",
        short_with_attached_argument="CDdFIiMmVx",
        writes_only_with=frozenset({"-i"}),
        script_options=frozenset({"-e", "-E"}),
    ),
    "rm": Writer("every operand"),
    "sed": Writer(
        "every operand",
        short_with_argument="efl",
        short_with_attached_argument="i",
        long_with_argument=frozenset({"--expression", "--file", "--line-length"}),
        writes_only_with=frozenset({"-i", "--in-place"}),
        script_options=frozenset({"-e", "-f", "--expression", "--file"}),
    ),
    "tee": Writer("every operand"),
    "touch": Writer(
        "every operand", short_with_argument="drt", long_with_argument=frozenset({"--date", "--reference"})
    ),
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


def written(part: shell_syntax.Call | shell_syntax.Redirection) -> list[shell_syntax.Word]:
    """Return the words that name the files a part of a command writes, UNSEEN for files it cannot name."""
    if isinstance(part, shell_syntax.Redirection):
        return [part.target] if part.operator in REDIRECTIONS_THAT_WRITE else []
    if not part.words:
        return []
    name, *arguments = part.words
    if shell_syntax.command_name(name.value) in RUNNERS:
        for index, argument in enumerate(arguments):
            writer = WRITERS.get(shell_syntax.command_name(argument.value) or "")
            if writer is not None:
                run = arguments[index + 1 :]
                ended = next((end for end, ran in enumerate(run) if ran.value in {";", "+"}), len(run))
                return writer.targets([*run[:ended], shell_syntax.UNSEEN])
        return []
    writer = WRITERS.get(shell_syntax.command_name(name.value) or "")
    return [] if writer is None else writer.targets(arguments)


def shell_write(command: str, cwd: pathlib.Path) -> str | None:
    """Return the text of the first part of a command that writes a file of the change, or None.

    Exits 1 when shfmt, which parses it, is not on the PATH.
    """
    try:
        parts = shell_syntax.calls_and_redirections(command)
    except shell_syntax.ParserMissingError:
        sys.exit("lead-writes-no-code.py: shfmt, which parses a command of the lead, is not on the PATH")
    for part in parts or []:
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
