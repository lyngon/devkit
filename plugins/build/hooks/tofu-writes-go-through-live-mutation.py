#!/usr/bin/env python3
"""PreToolUse hook of the build plugin on Bash and Monitor: OpenTofu writes go through live-mutation.

A subagent, whose hook input holds an agent_id, never calls propose, demonstrate or run of that skill's tool, nor
the tool in a call whose subcommand the hook cannot read.
"""

import collections.abc as ct
import itertools
import json
import re
import sys
import typing as t

import shell_syntax

ROUTE = (
    "An OpenTofu command that writes runs only through build:live-mutation."
    " The lead invokes that skill and proposes the command with the skill's tool, which runs the apply of a saved"
    " plan on an unprotected root module without a go-ahead when it finds that it may,"
    " and every other write on the owner's go-ahead."
    " A subagent stops and reports the command to its lead."
)

SUBAGENT = (
    "A subagent never proposes, demonstrates or runs a live mutation with the tool of build:live-mutation,"
    " since only the lead can ask the owner for a go-ahead and only the lead has the standing instructions."
    " Stop, and report to your lead the live mutation that your work needs."
)

TOOL = "live-mutation.py"

NAMES_THE_TOOL = re.compile(r"live-mutation\.py")

TOOL_AT_THE_END = re.compile(r"(?:^|/)live-mutation\.py[\"']?$")

LIVE_SUBCOMMANDS = frozenset({"propose", "demonstrate", "run"})

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

ADDS_WORDS_FROM_ITS_INPUT = "xargs"

SHELL_FLAGS_WITH_AN_ARGUMENT = frozenset("oO")

SHELL_LONG_OPTIONS_WITH_AN_ARGUMENT = frozenset({"--init-file", "--rcfile"})

WORDS_OF_A_USE = ' "$@"'

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

NESTING = frozenset(command.split()[0] for command in [*WRITES_ALWAYS, *WRITES_WITH_A_FLAG] if " " in command)

HELP = frozenset({"-h", "-help", "--help"})

PRINTS_HELP = "-help"

SHELLS = frozenset({"bash", "dash", "ksh", "sh", "zsh"})

SHELL_COMMAND_OPTION = re.compile(r"-[a-z]*c[a-z]*")

ECHO_OPTIONS = re.compile(r"-[neE]+")

READS_STANDARD_INPUT = (
    "reads commands from standard input, where the hook reads only a here-document, a here-string"
    " or an echo without a backslash"
)

HAND_IT_THE_COMMANDS = "Hand the shell its commands with -c, a here-document or a here-string."

NAMES_TOFU = re.compile(r"(?<![a-z0-9.-])(?:open)?tofu(?![a-z0-9.-])", re.IGNORECASE)

OPENTOFU_FLAKE = re.compile(r"[^#]*#(?:.*\.)?opentofu")

DIALECTS = ("bash", "zsh")

EXPANDED = "comes from a variable or a substitution"


def writes(part: str) -> str:
    """Return the reason that denies a part of a command that runs an OpenTofu command that writes."""
    return f"`{part}` is an OpenTofu command that writes. {ROUTE}"


def hidden(part: str, why: str) -> str:
    """Return the reason that denies a part of a command whose effect an expansion hides from the hook."""
    return (
        f"This command names tofu, and the hook cannot tell what `{part}` runs, since {why}, so it denies it."
        f" Spell it out without a variable or a substitution there. {ROUTE}"
    )


def unread(why: str, remedy: str) -> str:
    """Return the reason that denies a command that names tofu and that the hook cannot parse."""
    return f"This command names tofu, and the hook cannot read it, since {why}, so it denies it. {remedy} {ROUTE}"


def json_object(value: object, name: str) -> dict[str, object]:
    """Return the value as a JSON object, whose keys are strings. Exits 1, naming it, when it is no object."""
    if not isinstance(value, dict):
        sys.exit(f"tofu-writes-go-through-live-mutation.py: {name} is no JSON object")
    return t.cast("dict[str, object]", value)


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


def tofu_command(arguments: ct.Sequence[shell_syntax.Word]) -> tuple[str | None, ct.Sequence[shell_syntax.Word]]:
    """Return the command that an OpenTofu run with these arguments runs, and the arguments after its name.

    The command is PRINTS_HELP for a run with a help flag or without a subcommand, and None when an expansion hides it.
    """
    if any(word.value in HELP for word in itertools.takewhile(lambda word: word.value != "--", arguments)):
        return PRINTS_HELP, ()
    position = next((index for index, word in enumerate(arguments) if not passed_over(word)), None)
    if position is None:
        return PRINTS_HELP, ()
    command = arguments[position].value
    rest = arguments[position + 1 :]
    if command in NESTING and rest and not passed_over(rest[0]):
        nested = rest[0].value
        return (None if nested is None else f"{command} {nested}"), rest[1:]
    return command, rest


def tofu_run(arguments: ct.Sequence[shell_syntax.Word], part: str) -> str | None:
    """Return why the hook denies an OpenTofu run with these arguments, or None when it only reads."""
    command, rest = tofu_command(arguments)
    if command is None:
        return hidden(part, f"its subcommand {EXPANDED}")
    if command in WRITES_ALWAYS:
        return writes(part)
    flags = WRITES_WITH_A_FLAG.get(command, frozenset())
    names = {flag_name(word) for word in rest} if flags else set[str | None]()
    if names & flags:
        return writes(part)
    if None in names:
        return hidden(part, f"an argument {EXPANDED} and may be {' or '.join(f'-{flag}' for flag in sorted(flags))}")
    return None


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


def handed(command: str | None, call: shell_syntax.Call) -> str | None:
    """Return why the hook denies a command that a call hands a shell, or None to let it run."""
    return hidden(call.text, f"the command it hands a shell {EXPANDED}") if command is None else denial(command)


def input_denial(call: shell_syntax.Call) -> str | None:
    """Return why the hook denies the commands that a shell of a call reads on standard input, or None to let them run.

    It denies an echo with a backslash, which the echo of zsh may turn into a line break.
    """
    source = call.standard_input
    if isinstance(source, shell_syntax.Word):
        return handed(script(source), call)
    if (
        isinstance(source, shell_syntax.Call)
        and source.words
        and shell_syntax.command_name(source.words[0].value) == "echo"
    ):
        command = echoed(source.words[1:])
        if command is None or "\\" not in command:
            return handed(command, call)
    return unread(f"`{call.text}` {READS_STANDARD_INPUT}", HAND_IT_THE_COMMANDS)


def shell_denial(call: shell_syntax.Call) -> str | None:
    """Return why the hook denies a command that a call hands a shell to run, or None to let them all run."""
    words = call.words
    if words and words[0].value == "eval":
        return handed(evaluated(words[1:]), call)
    programs = program_positions(words)
    for index, word in enumerate(words):
        if shell_syntax.command_name(word.value) not in SHELLS:
            continue
        operand = shell_command(words[index + 1 :])
        if operand is not None:
            reason = handed(script(operand), call)
        elif index in programs and reads_standard_input(words[index + 1 :]):
            reason = input_denial(call)
        else:
            reason = None
        if reason is not None:
            return reason
    return None


def call_denial(call: shell_syntax.Call) -> str | None:
    """Return why the hook denies a simple command of a command that names tofu, or None to let it run."""
    if call.words and call.words[0].value is None:
        return hidden(call.text, f"its program {EXPANDED}")
    reason = shell_denial(call)
    if reason is not None:
        return reason
    for index, word in enumerate(call.words):
        reason = tofu_run(call.words[index + 1 :], call.text) if names_tofu(word) else None
        if reason is not None:
            return reason
    return None


def denial(command: str) -> str | None:
    """Return why the hook denies a shell command, or None to let it run."""
    try:
        parts = shell_syntax.calls_and_redirections(command, DIALECTS, resolve_variables=True)
    except shell_syntax.ParserMissingError:
        return unread(
            "shfmt, which parses it, is not on the PATH that Claude Code gives its hooks",
            (
                "Ask the operator to start Claude Code from the repository's devenv shell,"
                " whose lyngon.scriptTools provide shfmt."
            ),
        )
    if parts is None:
        return unread("it parses neither as bash nor as zsh", "Write it as bash.")
    calls = (part for part in parts if isinstance(part, shell_syntax.Call))
    return next((reason for call in calls if (reason := call_denial(call)) is not None), None)


def names_the_tool(word: shell_syntax.Word) -> bool:
    """Return whether a word names the tool of build:live-mutation, by its name or a path that ends in it."""
    if word.value is not None:
        return shell_syntax.command_name(word.value) == TOOL
    return TOOL_AT_THE_END.search(word.text) is not None


def program_positions(words: ct.Sequence[shell_syntax.Word]) -> range:
    """Return the positions of the words that a simple command may run as a program.

    The first word is the program. When it is a wrapper, which runs a command that its arguments give, or when an
    expansion hides it, any later word may be a program too, since the hook does not read each wrapper's options.
    """
    if not words:
        return range(0)
    if words[0].value is None or shell_syntax.command_name(words[0].value) in WRAPPERS:
        return range(len(words))
    return range(1)


def calls_live(arguments: ct.Sequence[shell_syntax.Word]) -> bool:
    """Return whether the tool, run with these arguments, may propose, demonstrate or run.

    Its subcommand is the first argument that is not --, and it counts when an expansion hides it.
    """
    subcommand = next((argument for argument in arguments if argument.value != "--"), None)
    return subcommand is not None and (subcommand.value is None or subcommand.value in LIVE_SUBCOMMANDS)


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


def shell_calls_the_tool(arguments: ct.Sequence[shell_syntax.Word]) -> bool:
    """Return whether a shell run with these arguments may call propose, demonstrate or run of the tool.

    The command of its -c counts when an expansion hides it, and standard input always counts, since the hook does
    not see what a heredoc, a here-string or a pipe hands the shell.
    """
    operand = shell_command(arguments)
    if operand is None:
        return reads_standard_input(arguments)
    command = script(operand)
    return command is None or calls_the_tool(command)


def alias_calls_the_tool(argument: shell_syntax.Word) -> bool:
    """Return whether an argument of alias defines a name that may call propose, demonstrate or run of the tool.

    The shell runs the value after = with the words of each use after it, which WORDS_OF_A_USE stands for.
    """
    if argument.value is None:
        return NAMES_THE_TOOL.search(argument.text) is not None
    return calls_the_tool(argument.value.partition("=")[2] + WORDS_OF_A_USE)


def program_calls_the_tool(program: shell_syntax.Word, arguments: ct.Sequence[shell_syntax.Word]) -> bool:
    """Return whether a program of a simple command, run with these arguments, may call propose, demonstrate or run."""
    if names_the_tool(program):
        return calls_live(arguments)
    match shell_syntax.command_name(program.value):
        case name if name in SHELLS:
            return shell_calls_the_tool(arguments)
        case "eval":
            command = evaluated(arguments)
            return command is None or calls_the_tool(command)
        case "alias":
            return any(alias_calls_the_tool(argument) for argument in arguments)
        case _:
            return False


def call_calls_the_tool(words: ct.Sequence[shell_syntax.Word]) -> bool:
    """Return whether a simple command may call propose, demonstrate or run of the tool of build:live-mutation.

    The tool counts only where the command may run it as a program, never as an argument of another program, and
    behind xargs, which adds words from its input, it counts whatever its arguments.
    """
    for position in program_positions(words):
        program, arguments = words[position], words[position + 1 :]
        before = {shell_syntax.command_name(word.value) for word in words[:position]}
        behind_xargs = ADDS_WORDS_FROM_ITS_INPUT in before and names_the_tool(program)
        if behind_xargs or program_calls_the_tool(program, arguments):
            return True
    return False


def calls_the_tool(command: str) -> bool:
    """Return whether a shell command may call propose, demonstrate or run of the tool of build:live-mutation.

    A command that names the tool counts when the hook cannot parse it, when a shell in it reads commands from
    standard input, and when a simple command in it may call one of the three.
    """
    if NAMES_THE_TOOL.search(command) is None:
        return False
    try:
        parts = shell_syntax.calls_and_redirections(command, DIALECTS, resolve_variables=True)
    except shell_syntax.ParserMissingError:
        return True
    if parts is None:
        return True
    return any(call_calls_the_tool(part.words) for part in parts if isinstance(part, shell_syntax.Call))


def answer(hook_input: dict[str, object]) -> dict[str, object] | None:
    """Return the hook's output for a call, or None to let it run as it is.

    Exits 1 when the hook input or its tool_input is no JSON object.
    """
    command = json_object(hook_input.get("tool_input"), "its tool_input").get("command")
    if not isinstance(command, str):
        return None
    if "agent_id" in hook_input and calls_the_tool(command):
        reason = SUBAGENT
    else:
        reason = None if NAMES_TOFU.search(command) is None else denial(command)
    if reason is None:
        return None
    return {
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": reason,
        }
    }


def main() -> None:
    """Read the hook input on stdin and print the output, if any."""
    output = answer(json_object(t.cast("object", json.load(sys.stdin)), "the hook input"))
    if output is not None:
        json.dump(output, sys.stdout)


if __name__ == "__main__":
    main()
