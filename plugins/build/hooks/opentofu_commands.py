# ruff: noqa: INP001  # a module beside the hook scripts that import it, which no package holds
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

XARGS = "xargs"

XARGS_REPLACE_OPTIONS = frozenset({"-I", "-i", "--replace"})

XARGS_DEFAULT_REPLACEMENT = "{}"

IN_EVERY_WORD = ""

ASSIGNMENT = re.compile(r"[^=]+=")

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


class Arity(enum.Enum):
    """What an option of a wrapper takes when it takes no number of the words after it."""

    ATTACHED_ONLY = enum.auto()
    EVERY_LATER_WORD = enum.auto()


type Takes = int | Arity


class Missing(enum.Enum):
    """An argument of an option of a wrapper that the reader does not have."""

    NONE_GIVEN = enum.auto()
    UNSEEN = enum.auto()


type Argument = str | Missing

XARGS_REPLACEMENT_WITHOUT_AN_ARGUMENT = {Missing.NONE_GIVEN: XARGS_DEFAULT_REPLACEMENT, Missing.UNSEEN: IN_EVERY_WORD}


class UnreadableOptionError(Exception):
    """An option word of a wrapper names options that its table does not, or an expansion hides which."""


@dataclasses.dataclass(frozen=True, slots=True)
class Taken:
    """An option that a wrapper took, by its name in the wrapper's table, and its argument."""

    name: str
    argument: Argument


@dataclasses.dataclass(frozen=True, slots=True)
class Reading:
    """How a wrapper reads the words of a simple command after it: the options it takes and the programs it runs."""

    options: tuple[Taken, ...] = ()
    programs: tuple[int, ...] = ()
    programs_from: int | None = None


@dataclasses.dataclass(frozen=True, slots=True)
class Wrapper:
    """How a program that runs another program reads its words up to the program it runs."""

    options: ct.Mapping[str, Takes] = dataclasses.field(default_factory=dict[str, Takes])
    operands: int = 0
    assignments: bool = False
    subcommands: ct.Mapping[str, "Wrapper | Exec"] = dataclasses.field(default_factory=dict[str, "Wrapper | Exec"])

    def reading(self, words: ct.Sequence[shell_syntax.Word], position: int) -> Reading:
        """Return how this wrapper, at a position of a simple command, reads the words after it."""
        taken: list[Taken] = []
        operands = self.operands
        in_options = True
        at = position + 1
        while at < len(words):
            word = words[at]
            if in_options and word.value == "--":
                in_options = False
            elif in_options and is_option(word, self.options):
                try:
                    found, following = options_in(word, self.options, words[at + 1 :])
                except UnreadableOptionError:
                    return Reading(tuple(taken), programs_from=at + 1)
                taken.extend(found)
                if self.options[found[-1].name] is Arity.EVERY_LATER_WORD:
                    return Reading(tuple(taken))
                at += following
            elif self.subcommands:
                return subcommand_reading(words, at, self.subcommands, tuple(taken))
            elif not (self.assignments and ASSIGNMENT.match(word.start)):
                if not operands:
                    return Reading(tuple(taken), (at,))
                operands -= 1
            at += 1
        return Reading(tuple(taken))


@dataclasses.dataclass(frozen=True, slots=True)
class Exec:
    """A wrapper whose words are all its own but the command after each of its options, as -exec of find is."""

    options: frozenset[str]
    ends: frozenset[str] = frozenset()

    def reading(self, words: ct.Sequence[shell_syntax.Word], position: int) -> Reading:
        """Return the programs that this wrapper, at a position of a simple command, runs."""
        programs: list[int] = []
        remaining = iter(range(position + 1, len(words)))
        for at in remaining:
            if words[at].value in self.options and (program := next(remaining, None)) is not None:
                programs.append(program)
                if not self.ends:
                    break
                _ = next((end for end in remaining if words[end].value in self.ends), None)
        return Reading((), tuple(programs))


def options(*groups: tuple[str, Takes]) -> dict[str, Takes]:
    """Return the table of options of a wrapper, from groups of names, separated by spaces, that take the same."""
    return {name: takes for names, takes in groups for name in names.split()}


SHELL_OF_NIX = Exec(frozenset({"--command", "-c"}))

PYTHON = Wrapper(
    options(
        ("-b -B -d -E -i -I -O -P -q -s -S -u -v -x", 0),
        ("-W -X --check-hash-based-pycs", 1),
        ("-c -m -h -? -V --help --help-env --help-xoptions --help-all --version", Arity.EVERY_LATER_WORD),
    )
)

WRAPPERS: ct.Mapping[str, Wrapper | Exec] = {
    "aws-vault": Wrapper(subcommands={"exec": Wrapper(operands=1)}),
    "command": Wrapper(options(("-p", 0), ("-v -V", Arity.EVERY_LATER_WORD))),
    "devenv": Wrapper(subcommands={"shell": Wrapper()}),
    "env": Wrapper(
        options(
            ("- -i --ignore-environment -0 --null -v --debug --list-signal-handling", 0),
            ("-a --argv0 -u --unset -C --chdir -S --split-string", 1),
            ("--block-signal --default-signal --ignore-signal", Arity.ATTACHED_ONLY),
        ),
        assignments=True,
    ),
    "exec": Wrapper(options(("-c -l", 0), ("-a", 1))),
    "find": Exec(frozenset({"-exec", "-execdir", "-ok", "-okdir"}), ends=frozenset({";", "+"})),
    "nice": Wrapper(options(("-n --adjustment", 1))),
    "nix": Wrapper(subcommands={"run": Wrapper(), "shell": SHELL_OF_NIX, "develop": SHELL_OF_NIX}),
    "nohup": Wrapper(),
    "python": PYTHON,
    "python3": PYTHON,
    "secretspec": Wrapper(
        subcommands={
            "run": Wrapper(
                options(
                    ("-f --file -p --provider -P --profile -S --scope --reason", 1),
                    ("--caller --caller-version --caller-operation --caller-resource", 1),
                    ("-h --help", Arity.EVERY_LATER_WORD),
                )
            )
        }
    ),
    "setsid": Wrapper(options(("-c --ctty -f --fork -w --wait", 0))),
    "stdbuf": Wrapper(options(("-i --input -o --output -e --error", 1))),
    "sudo": Wrapper(
        options(
            ("-A --askpass -B --bell -b --background -E --preserve-env -H --set-home -i --login", 0),
            ("-k --reset-timestamp -N --no-update -n --non-interactive -P --preserve-groups -S --stdin -s --shell", 0),
            ("-a --auth-type -C --close-from -c --login-class -D --chdir -g --group --host -p --prompt", 1),
            ("-R --chroot -r --role -T --command-timeout -t --type -U --other-user -u --user", 1),
            ("-h", Arity.ATTACHED_ONLY),
            ("-e --edit -K --remove-timestamp -l --list -V --version -v --validate --help", Arity.EVERY_LATER_WORD),
        ),
        assignments=True,
    ),
    "time": Wrapper(
        options(("-a --append -p --portability -q --quiet -v --verbose", 0), ("-f --format -o --output", 1))
    ),
    "timeout": Wrapper(
        options(("-f --foreground -p --preserve-status -v --verbose", 0), ("-k --kill-after -s --signal", 1)),
        operands=1,
    ),
    "uv": Wrapper(subcommands={"run": Wrapper()}),
    XARGS: Wrapper(
        options(
            ("-0 --null -o --open-tty -p --interactive -r --no-run-if-empty -t --verbose -x --exit --show-limits", 0),
            ("-a --arg-file -d --delimiter -E -I -L -n --max-args -P --max-procs -s --max-chars --process-slot-var", 1),
            ("-e --eof -i --replace -l --max-lines", Arity.ATTACHED_ONLY),
            ("--help --version", Arity.EVERY_LATER_WORD),
        )
    ),
}


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


def program_positions(words: ct.Sequence[shell_syntax.Word]) -> list[int]:
    """Return the positions of the words that a simple command may run as a program, in order.

    The first word is a program, and so is each word that a wrapper among them runs. Every word after a program that
    an expansion hides may be one too, and so may every word from where the reader cannot read a wrapper.
    """
    found: set[int] = set()
    pending = [0] if words else []
    while pending:
        position = pending.pop()
        if position in found:
            continue
        found.add(position)
        name = shell_syntax.command_name(words[position].value)
        if name is None:
            pending.extend(range(position + 1, len(words)))
        elif name in WRAPPERS:
            reading = WRAPPERS[name].reading(words, position)
            pending.extend(reading.programs)
            if reading.programs_from is not None:
                pending.extend(range(reading.programs_from, len(words)))
    return sorted(found)


def subcommand_reading(
    words: ct.Sequence[shell_syntax.Word],
    position: int,
    subcommands: ct.Mapping[str, Wrapper | Exec],
    taken: tuple[Taken, ...],
) -> Reading:
    """Return how a wrapper that took these options reads the words from its subcommand at a position on."""
    name = words[position].value
    if name is None:
        return Reading(taken, programs_from=position + 1)
    subcommand = subcommands.get(name)
    if subcommand is None:
        return Reading(taken)
    inner = subcommand.reading(words, position)
    return Reading((*taken, *inner.options), inner.programs, inner.programs_from)


def is_option(word: shell_syntax.Word, table: ct.Mapping[str, Takes]) -> bool:
    """Return whether a wrapper with this table of options reads a word as an option."""
    return word.start.startswith("-") and (word.start != "-" or not word.complete or "-" in table)


def options_in(
    word: shell_syntax.Word, table: ct.Mapping[str, Takes], following: ct.Sequence[shell_syntax.Word]
) -> tuple[list[Taken], int]:
    """Return the options that an option word gives a wrapper with this table, and how many following words they take.

    Raises UnreadableOptionError.
    """
    if word.complete and word.start in table:
        option, taking = take(word.start, table[word.start], Missing.NONE_GIVEN, following)
        return [option], taking
    if word.start.startswith("--"):
        return long_option(word, table, following)
    return short_options(word, table, following)


def long_option(
    word: shell_syntax.Word, table: ct.Mapping[str, Takes], following: ct.Sequence[shell_syntax.Word]
) -> tuple[list[Taken], int]:
    """Return the long option that a word gives, and how many following words it takes.

    Raises UnreadableOptionError.
    """
    name, equals, attached = word.start.partition("=")
    names = [name] if name in table else [option for option in table if option.startswith(name)]
    if len(names) != 1 or not (word.complete or equals):
        raise UnreadableOptionError
    given: Argument = Missing.NONE_GIVEN
    if equals:
        given = attached if word.complete else Missing.UNSEEN
    option, taking = take(names[0], table[names[0]], given, following)
    return [option], taking


def short_options(
    word: shell_syntax.Word, table: ct.Mapping[str, Takes], following: ct.Sequence[shell_syntax.Word]
) -> tuple[list[Taken], int]:
    """Return the short options that a word gives, and how many following words the last of them takes.

    Raises UnreadableOptionError.
    """
    found: list[Taken] = []
    for at, letter in enumerate(word.start[1:], start=2):
        name, rest = f"-{letter}", word.start[at:]
        takes = table.get(name)
        if takes is None or (isinstance(takes, int) and takes > 0 and not (word.complete or rest)):
            raise UnreadableOptionError
        if takes != 0:
            option, taking = take(
                name, takes, (rest or Missing.NONE_GIVEN) if word.complete else Missing.UNSEEN, following
            )
            return [*found, option], taking
        found.append(Taken(name, Missing.NONE_GIVEN))
    if not word.complete:
        raise UnreadableOptionError
    return found, 0


def take(name: str, takes: Takes, given: Argument, following: ct.Sequence[shell_syntax.Word]) -> tuple[Taken, int]:
    """Return an option with the argument in its own word or the next, and how many following words it takes."""
    if isinstance(takes, Arity):
        return Taken(name, given), 0
    if given is not Missing.NONE_GIVEN:
        return Taken(name, given), max(takes - 1, 0)
    if takes == 0:
        return Taken(name, Missing.NONE_GIVEN), 0
    value = following[0].value if following else None
    return Taken(name, Missing.UNSEEN if value is None else value), takes


def xargs_replacement(options: ct.Sequence[Taken]) -> str | None:
    """Return the string that xargs with these options puts its input in place of, or None when it adds its input."""
    replacements = [
        option.argument if isinstance(option.argument, str) else XARGS_REPLACEMENT_WITHOUT_AN_ARGUMENT[option.argument]
        for option in options
        if option.name in XARGS_REPLACE_OPTIONS
    ]
    return replacements[-1] if replacements else None


def put_in_place(word: shell_syntax.Word, replacement: str) -> shell_syntax.Word:
    """Return the word that xargs hands on, hidden from the first place where it holds the replacement on."""
    at = word.start.find(replacement)
    return word if at < 0 else shell_syntax.Word(word.start[:at], complete=False, text=word.text)


def readings(words: ct.Sequence[shell_syntax.Word]) -> list[tuple[tuple[shell_syntax.Word, ...], Origin]]:
    """Return the words that a simple command may run, each with where a word that the reader cannot see comes from.

    Behind xargs, the command that xargs runs also takes the words of its input: after its last word, or in place of
    the string that -I, -i or --replace names in the words after its program. Without a command, xargs runs echo.
    """
    found = [(tuple(words), Origin.EXPANSION)]
    xargs = next((at for at in program_positions(words) if shell_syntax.command_name(words[at].value) == XARGS), None)
    if xargs is None:
        return found
    reading = WRAPPERS[XARGS].reading(words, xargs)
    if reading.programs_from is not None:
        replaced_from, replacement = reading.programs_from, IN_EVERY_WORD
    elif reading.programs:
        replaced_from, replacement = reading.programs[0] + 1, xargs_replacement(reading.options)
    else:
        return found
    if replacement is None:
        handed = (*words, shell_syntax.UNSEEN)
    else:
        handed = (*words[:replaced_from], *(put_in_place(word, replacement) for word in words[replaced_from:]))
    return [*found, (handed, Origin.XARGS_INPUT)]


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
    """Yield a program that a simple command hides, or else the commands it hands a shell, its programs and tofu."""
    found = [(words, origin, program_positions(words)) for words, origin in readings(call.words)]
    for words, origin, programs in found:
        if any(words[at].value is None for at in programs):
            yield Hidden(call.text, f"its program {origin}")
            return
    yield from shell_findings(call)
    for index in range(len(call.words)):
        for words, origin, programs in found:
            if index in programs or names_tofu(words[index]):
                yield Run(words[index], words[index + 1 :], call.text, origin)


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
