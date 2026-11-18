# ruff: noqa: INP001  # a module beside the hook scripts that import it, which no package holds
"""The files that a shell command writes, where it names them before it runs.

A redirection that writes, and a command of WRITERS, also when find or xargs runs it. Any other program may write
files as well, an interpreter or git among them, and nothing here can tell that from a read.
"""

import collections.abc as ct
import dataclasses
import pathlib
import re
import typing as t

import shell_syntax

REDIRECTIONS_THAT_WRITE = frozenset({">", ">>", ">|", "&>", "&>>", "<>"})

DUPLICATES_OR_CLOSES_IN_BASH_AND_ZSH = re.compile(r"[0-9]+|-")

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


def writes_its_file(redirection: shell_syntax.Redirection) -> bool:
    """Return whether a redirection writes the file that its word names."""
    if redirection.operator == ">&":
        return DUPLICATES_OR_CLOSES_IN_BASH_AND_ZSH.fullmatch(redirection.target.value or "") is None
    return redirection.operator in REDIRECTIONS_THAT_WRITE


def written(part: shell_syntax.Call | shell_syntax.Redirection) -> list[shell_syntax.Word]:
    """Return the words that name the files a part of a command writes, UNSEEN for files it cannot name."""
    if isinstance(part, shell_syntax.Redirection):
        return [part.target] if writes_its_file(part) else []
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


def first_write(command: str, cwd: pathlib.Path, guarded: ct.Callable[[pathlib.Path], bool]) -> str | None:
    """Return the text of the first part of a command that may write a guarded file, or None.

    A file that a path with a variable or a substitution names counts as guarded.
    Raises shell_syntax.UnreadableError for a command that the hook cannot read.
    """
    for part in shell_syntax.may_run(command):
        for target in written(part):
            if target.value is None or guarded((cwd / target.value).resolve()):
                return part.text
    return None
