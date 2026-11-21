# ruff: noqa: INP001
"""What a shell command may run, as the OpenTofu hook and the tool of build:live-mutation read it.

findings() reads a command, the commands it hands a shell or eval included, and yields in the order of its text
each program that it may run, each word that names OpenTofu, and each part that it cannot read. The tables say what
an OpenTofu command does: which ones write, and which ones print the values of a plan or a state.
"""

import collections.abc as ct
import dataclasses
import enum
import itertools
import re
import typing as t

import shell_syntax

WRAPPERS = frozenset(
    {
        "aws-vault",
        "command",
        "devenv",
        "env",
        "exec",
        "find",
        "nice",
        "nix",
        "nohup",
        "python",
        "python3",
        "secretspec",
        "setsid",
        "stdbuf",
        "sudo",
        "time",
        "timeout",
        "uv",
        "xargs",
    }
)

XARGS = "xargs"

XARGS_REPLACE = "--replace"

XARGS_DEFAULT_REPLACEMENT = "{}"

XARGS_SHORT_WITH_AN_ARGUMENT = frozenset("adEILnPs")

XARGS_SHORT_WITH_AN_ATTACHED_ARGUMENT = frozenset("eil")

XARGS_LONG_WITH_AN_ARGUMENT = (
    "--arg-file",
    "--delimiter",
    "--max-args",
    "--max-chars",
    "--max-procs",
    "--process-slot-var",
)

IN_EVERY_WORD = ""

SHELL_FLAGS_WITH_AN_ARGUMENT = frozenset("oO")

SHELL_LONG_OPTIONS_WITH_AN_ARGUMENT = frozenset({"--init-file", "--rcfile"})

WRITES_ALWAYS = frozenset(
    {
        "apply",
        "destroy",
        "force-unlock",
        "import",
        "refresh",
        "state mv",
        "state push",
        "state replace-provider",
        "state rm",
        "taint",
        "test",
        "untaint",
        "workspace delete",
        "workspace new",
    }
)

WRITES_WITH_A_FLAG: dict[str, frozenset[str]] = {
    "init": frozenset({"force-copy", "migrate-state"}),
    "workspace select": frozenset({"or-create"}),
}

PRINTS_VALUES = frozenset(
    {
        "apply",
        "console",
        "destroy",
        "output",
        "plan",
        "refresh",
        "show",
        "state pull",
        "state show",
        "test",
    }
)

NESTING = frozenset(
    command.split()[0] for command in [*WRITES_ALWAYS, *WRITES_WITH_A_FLAG, *PRINTS_VALUES] if " " in command
)

HELP = frozenset({"-h", "-help", "--help"})

PRINTS_HELP = "-help"

SHELLS = frozenset({"bash", "dash", "ksh", "sh", "zsh"})

SHELL_COMMAND_OPTION = re.compile(r"-[a-z]*c[a-z]*")

ECHO_OPTIONS = re.compile(r"-[neE]+")

NAMES_TOFU = re.compile(r"(?<![a-z0-9.-])(?:open)?tofu(?![a-z0-9.-])", re.IGNORECASE)

OPENTOFU_FLAKE = re.compile(r"[^#]*#(?:.*\.)?opentofu")

DIALECTS = ("bash", "zsh")


class Origin(enum.StrEnum):
    """Where a word that a reader cannot see comes from, as a sentence says it."""

    EXPANSION = "comes from a variable or a substitution"
    XARGS_INPUT = "comes from the input of xargs"


class Unparsable(enum.Enum):
    """Why a command does not parse: shfmt, which parses it, is not on the PATH, or it is neither bash nor zsh."""

    PARSER_MISSING = enum.auto()
    NO_DIALECT = enum.auto()


@dataclasses.dataclass(frozen=True, slots=True)
class Unparsed:
    """A command, or a command that it hands a shell, that does not parse."""

    cause: Unparsable


@dataclasses.dataclass(frozen=True, slots=True)
class Hidden:
    """A simple command whose program, or the command it hands a shell, an expansion hides: its text, and why."""

    part: str
    why: str


@dataclasses.dataclass(frozen=True, slots=True)
class ReadsStandardInput:
    """A simple command that runs a shell on commands from standard input that a reader does not see."""

    part: str


@dataclasses.dataclass(frozen=True, slots=True)
class Run:
    """A word of a simple command that names OpenTofu or that it may run as a program, with what it may run with.

    The part is the text of the simple command, and the origin is where a word of the arguments that an expansion
    hides comes from.
    """

    program: shell_syntax.Word
    arguments: tuple[shell_syntax.Word, ...]
    part: str
    origin: Origin


type Finding = Unparsed | Hidden | ReadsStandardInput | Run


@dataclasses.dataclass(frozen=True, slots=True)
class TofuCommand:
    """The command of an OpenTofu run: the global options before it, its name and the arguments after it.

    The name is PRINTS_HELP for a run with a help flag or without a subcommand, and None when an expansion hides it.
    """

    options: tuple[shell_syntax.Word, ...]
    name: str | None
    arguments: tuple[shell_syntax.Word, ...]


def names_tofu(word: shell_syntax.Word) -> bool:
    """Return whether a word names the OpenTofu program, by its name, its path or the flake output that nix runs."""
    value = word.value
    if value is None:
        return False
    return shell_syntax.command_name(value) == "tofu" or OPENTOFU_FLAKE.fullmatch(value) is not None


def flag_name(word: shell_syntax.Word) -> str | None:
    """Return the name of the flag that a word sets, "" when it sets none, or None when an expansion hides which."""
    if not word.start:
        return "" if word.complete else None
    if not word.start.startswith("-"):
        return ""
    name, equals, _ = word.start.lstrip("-").partition("=")
    return name if word.complete or equals else None


def passed_over(word: shell_syntax.Word) -> bool:
    """Return whether tofu passes over a word in search of its subcommand: a global option, or an empty word."""
    return word.start.startswith("-") or word.value == ""


def tofu_command(arguments: ct.Sequence[shell_syntax.Word]) -> TofuCommand:
    """Return the command that an OpenTofu run with these arguments runs."""
    if any(word.value in HELP for word in itertools.takewhile(lambda word: word.value != "--", arguments)):
        return TofuCommand((), PRINTS_HELP, ())
    position = next((index for index, word in enumerate(arguments) if not passed_over(word)), None)
    if position is None:
        return TofuCommand(tuple(arguments), PRINTS_HELP, ())
    options, command, rest = tuple(arguments[:position]), arguments[position].value, tuple(arguments[position + 1 :])
    if command in NESTING and rest and not passed_over(rest[0]):
        nested = rest[0].value
        return TofuCommand(options, None if nested is None else f"{command} {nested}", rest[1:])
    return TofuCommand(options, command, rest)


def script(operand: shell_syntax.Word) -> str | None:
    """Return the command that a shell runs from a word, or None when an expansion hides it."""
    return operand.unexpanded if operand.value is None else operand.value


def command_option(arguments: ct.Sequence[shell_syntax.Word]) -> int | None:
    """Return the position of a shell's -c option among its arguments, or None when it has none."""
    return next(
        (at for at, argument in enumerate(arguments) if SHELL_COMMAND_OPTION.fullmatch(argument.value or "")), None
    )


def shell_command(arguments: ct.Sequence[shell_syntax.Word]) -> shell_syntax.Word | None:
    """Return the word that a shell with these arguments runs as a command, the operand of its -c, or None."""
    option = command_option(arguments)
    return None if option is None else next((word for word in arguments[option + 1 :] if not passed_over(word)), None)


def evaluated(arguments: ct.Sequence[shell_syntax.Word]) -> str | None:
    """Return the command that eval joins from these arguments, or None when an expansion hides it."""
    scripts = [script(argument) for argument in arguments]
    return None if None in scripts else " ".join(t.cast("list[str]", scripts))


def echoed(arguments: ct.Sequence[shell_syntax.Word]) -> str | None:
    """Return the text that echo writes with these arguments, or None when an expansion hides it."""
    return evaluated(list(itertools.dropwhile(lambda word: ECHO_OPTIONS.fullmatch(word.value or ""), arguments)))


def program_positions(words: ct.Sequence[shell_syntax.Word]) -> range:
    """Return the positions of the words that a simple command may run as a program.

    The first word is the program. When it is a wrapper, which runs a command that its arguments give, or when an
    expansion hides it, any later word may be a program too, since the reader does not read each wrapper's options.
    """
    if not words:
        return range(0)
    if words[0].value is None or shell_syntax.command_name(words[0].value) in WRAPPERS:
        return range(len(words))
    return range(1)


def xargs_options(words: ct.Sequence[shell_syntax.Word], position: int) -> ct.Sequence[shell_syntax.Word] | None:
    """Return the words between the xargs that runs the program at a position of a simple command and that program.

    None means that no xargs runs it.
    """
    runs = [at for at in program_positions(words)[:position] if shell_syntax.command_name(words[at].value) == XARGS]
    return words[runs[-1] + 1 : position] if runs else None


def long_option_replacement(option: str, remaining: ct.Iterator[shell_syntax.Word]) -> str | None:
    """Return the string that a long option of xargs names for its input to replace, or None when it names none."""
    name, equals, argument = option.partition("=")
    if XARGS_REPLACE.startswith(name):
        return argument if equals else XARGS_DEFAULT_REPLACEMENT
    if not equals and any(long.startswith(name) for long in XARGS_LONG_WITH_AN_ARGUMENT):
        _ = next(remaining, None)
    return None


def short_options_replacement(options: str, remaining: ct.Iterator[shell_syntax.Word]) -> str | None:
    """Return the string that a word of short options of xargs names for its input to replace, or None."""
    for at, letter in enumerate(options[1:], start=1):
        attached = options[at + 1 :]
        if letter in XARGS_SHORT_WITH_AN_ATTACHED_ARGUMENT:
            return (attached or XARGS_DEFAULT_REPLACEMENT) if letter == "i" else None
        if letter in XARGS_SHORT_WITH_AN_ARGUMENT:
            argument = attached or next(remaining, shell_syntax.UNSEEN).value
            if letter != "I":
                return None
            return IN_EVERY_WORD if argument is None else argument
    return None


def xargs_replacement(options: ct.Sequence[shell_syntax.Word]) -> str | None:
    """Return the string that xargs with these options puts its input in place of, or None when it adds its input."""
    replacement = None
    remaining = iter(options)
    for option in remaining:
        value = option.value
        if value is None:
            return IN_EVERY_WORD
        if value == "--":
            break
        if value.startswith("--"):
            named = long_option_replacement(value, remaining)
        elif value.startswith("-"):
            named = short_options_replacement(value, remaining)
        else:
            named = None
        replacement = replacement if named is None else named
    return replacement


def put_in_place(word: shell_syntax.Word, replacement: str) -> shell_syntax.Word:
    """Return the word that xargs hands on, hidden from the first place where it holds the replacement on."""
    at = word.start.find(replacement)
    return word if at < 0 else shell_syntax.Word(word.start[:at], complete=False, text=word.text)


def readings(
    words: ct.Sequence[shell_syntax.Word], position: int
) -> list[tuple[ct.Sequence[shell_syntax.Word], Origin]]:
    """Return the arguments that the program at a position of a simple command may run with, each with their origin.

    Behind xargs, the program also runs with the words of its input: after its own arguments, or in place of the
    string that -I, -i or --replace names.
    """
    arguments = words[position + 1 :]
    found: list[tuple[ct.Sequence[shell_syntax.Word], Origin]] = [(arguments, Origin.EXPANSION)]
    options = xargs_options(words, position)
    if options is not None:
        replacement = xargs_replacement(options)
        if replacement is None:
            found.append(([*arguments, shell_syntax.UNSEEN], Origin.XARGS_INPUT))
        else:
            found.append(([put_in_place(argument, replacement) for argument in arguments], Origin.XARGS_INPUT))
    return found


def reads_standard_input(arguments: ct.Sequence[shell_syntax.Word]) -> bool:
    """Return whether a shell run with these arguments and without -c may read commands from standard input.

    It does with -s, and when no operand follows its options, since the first operand names the file it runs. An
    operand that an expansion hides may name standard input, as a process substitution does.
    """
    remaining = iter(arguments)
    for argument in remaining:
        value = argument.value
        if value is None:
            return True
        if value in {"-", "--"}:
            operand = next(remaining, None)
            return operand is None or operand.value is None
        if not value.startswith(("-", "+")):
            return False
        letters = "" if value.startswith("--") else value[1:]
        if "s" in letters:
            return True
        if value in SHELL_LONG_OPTIONS_WITH_AN_ARGUMENT or SHELL_FLAGS_WITH_AN_ARGUMENT & set(letters):
            _ = next(remaining, None)
    return True


def findings(command: str) -> ct.Iterator[Finding]:
    """Yield what a shell command may run, and each part of it that a reader cannot read, in the order of its text.

    It yields lazily, so a reader that stops at its first verdict parses no command that the rest hands a shell.
    """
    try:
        parts = shell_syntax.calls_and_redirections(command, DIALECTS, resolve_variables=True)
    except shell_syntax.ParserMissingError:
        yield Unparsed(Unparsable.PARSER_MISSING)
        return
    if parts is None:
        yield Unparsed(Unparsable.NO_DIALECT)
        return
    for part in parts:
        if isinstance(part, shell_syntax.Call):
            yield from call_findings(part)


def call_findings(call: shell_syntax.Call) -> ct.Iterator[Finding]:
    """Yield what a simple command may run: the commands it hands a shell first, then its programs and OpenTofu words.

    OpenTofu counts at any word, since a wrapper whose options the reader does not read may run it from there.
    """
    words = call.words
    if words and words[0].value is None:
        yield Hidden(call.text, f"its program {Origin.EXPANSION}")
        return
    yield from shell_findings(call)
    programs = program_positions(words)
    for index, word in enumerate(words):
        if index in programs or names_tofu(word):
            for arguments, origin in readings(words, index):
                yield Run(word, tuple(arguments), call.text, origin)


def shell_findings(call: shell_syntax.Call) -> ct.Iterator[Finding]:
    """Yield what the commands that a simple command hands a shell or eval may run."""
    words = call.words
    if words and words[0].value == "eval":
        yield from handed(evaluated(words[1:]), call)
        return
    programs = program_positions(words)
    for index, word in enumerate(words):
        if shell_syntax.command_name(word.value) not in SHELLS:
            continue
        operand = shell_command(words[index + 1 :])
        if operand is not None:
            yield from handed(script(operand), call)
        elif index in programs and reads_standard_input(words[index + 1 :]):
            yield from input_findings(call)


def handed(command: str | None, call: shell_syntax.Call) -> ct.Iterator[Finding]:
    """Yield what a command that a simple command hands a shell may run, or that an expansion hides it."""
    if command is None:
        yield Hidden(call.text, f"the command it hands a shell {Origin.EXPANSION}")
    else:
        yield from findings(command)


def input_findings(call: shell_syntax.Call) -> ct.Iterator[Finding]:
    """Yield what the commands that a shell of a simple command reads on standard input may run.

    A reader sees a here-document, a here-string and the text of an echo, but not an echo with a backslash, which
    the echo of zsh may turn into a line break.
    """
    source = call.standard_input
    if isinstance(source, shell_syntax.Word):
        yield from handed(script(source), call)
        return
    if (
        isinstance(source, shell_syntax.Call)
        and source.words
        and shell_syntax.command_name(source.words[0].value) == "echo"
    ):
        command = echoed(source.words[1:])
        if command is None or "\\" not in command:
            yield from handed(command, call)
            return
    yield ReadsStandardInput(call.text)
