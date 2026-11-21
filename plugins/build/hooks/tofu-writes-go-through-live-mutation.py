#!/usr/bin/env python3
"""PreToolUse hook of the build plugin on Bash and Monitor: OpenTofu writes go through live-mutation.

No command in the shell is one, and neither is a command that the tool of that skill runs at once, before any
go-ahead. A subagent, whose hook input holds an agent_id, never calls propose, demonstrate or run of that skill's
tool, nor the tool in a call whose subcommand the hook cannot read.
"""

import argparse
import collections.abc as ct
import contextlib
import importlib
import io
import json
import pathlib
import re
import sys
import typing as t

import opentofu_commands
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

TOOL_SCRIPTS = pathlib.Path(__file__).resolve().parent.parent / "skills" / "live-mutation" / "scripts"

NAMES_THE_TOOL = re.compile(r"live-mutation\.py")

TOOL_AT_THE_END = re.compile(r"(?:^|/)live-mutation\.py[\"']?$")

LIVE_SUBCOMMANDS = frozenset({"propose", "demonstrate", "run"})

RUN_AT_ONCE = frozenset({"propose", "demonstrate"})

AT_ONCE = (
    f"{TOOL} runs the --derive, --show and --check commands of propose and the command of demonstrate at once,"
    " with no go-ahead, so none of them may write: only a proposal's run does."
)

WORDS_OF_A_USE = ' "$@"'

READS_STANDARD_INPUT = (
    "reads commands from standard input, where the hook reads only a here-document, a here-string"
    " or an echo without a backslash"
)

HAND_IT_THE_COMMANDS = "Hand the shell its commands with -c, a here-document or a here-string."


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


def tofu_run(arguments: ct.Sequence[shell_syntax.Word], part: str, origin: opentofu_commands.Origin) -> str | None:
    """Return why the hook denies an OpenTofu run with these arguments, or None when it only reads."""
    found = opentofu_commands.tofu_command(arguments)
    command, rest = found.name, found.arguments
    if command is None:
        return hidden(part, f"its subcommand {origin}")
    if command in opentofu_commands.WRITES_ALWAYS:
        return writes(part)
    flags = opentofu_commands.WRITES_WITH_A_FLAG.get(command, frozenset())
    names = {opentofu_commands.flag_name(word) for word in rest} if flags else set[str | None]()
    if names & flags:
        return writes(part)
    if None in names:
        return hidden(part, f"an argument {origin} and may be {' or '.join(f'-{flag}' for flag in sorted(flags))}")
    return None


def tool_parser() -> argparse.ArgumentParser:
    """Return the parser of the command line of the tool of build:live-mutation."""
    if str(TOOL_SCRIPTS) not in sys.path:
        sys.path.append(str(TOOL_SCRIPTS))
    module = vars(importlib.import_module(TOOL.removesuffix(".py")))
    return t.cast("ct.Callable[[], argparse.ArgumentParser]", module["parser"])()


def commands_given_at_once(arguments: list[str]) -> list[str]:
    """Return the commands that these arguments give the tool to run at once."""
    try:
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            parsed = tool_parser().parse_args(arguments)
    except SystemExit:
        return []
    match t.cast("str", parsed.command):
        case "propose":
            given = [t.cast("str | None", parsed.derive), t.cast("str | None", parsed.show)]
            checks = t.cast("list[tuple[str, str]]", parsed.check)
            return [command for command in given if command is not None] + [command for _, command in checks]
        case "demonstrate":
            return [t.cast("str", parsed.cmd)]
        case _:
            return []


def tool_run(arguments: ct.Sequence[shell_syntax.Word], part: str, origin: opentofu_commands.Origin) -> str | None:
    """Return why the hook denies a run of the tool of build:live-mutation with these arguments, or None to let it run.

    It denies a run that may propose or demonstrate when any of its arguments is hidden, or when the hook denies a
    command that the arguments give the tool to run at once.
    """
    if not runs_one_of(arguments, RUN_AT_ONCE):
        return None
    values = [argument.value for argument in arguments]
    if None in values:
        reason = hidden(part, f"an argument of {TOOL} {origin}")
    else:
        commands = commands_given_at_once(t.cast("list[str]", values))
        reason = next((found for command in commands if (found := denial(command)) is not None), None)
    return None if reason is None else f"{AT_ONCE} {reason}"


def verdict(finding: opentofu_commands.Finding) -> str | None:
    """Return why the hook denies what a reader found in a command, or None to let it run."""
    match finding:
        case opentofu_commands.Unparsed(cause=opentofu_commands.Unparsable.PARSER_MISSING):
            return unread(
                "shfmt, which parses it, is not on the PATH that Claude Code gives its hooks",
                (
                    "Ask the operator to start Claude Code from the repository's devenv shell,"
                    " whose lyngon.scriptTools provide shfmt."
                ),
            )
        case opentofu_commands.Unparsed():
            return unread("it parses neither as bash nor as zsh", "Write it as bash.")
        case opentofu_commands.Hidden(part=part, why=why):
            return hidden(part, why)
        case opentofu_commands.ReadsStandardInput(part=part):
            return unread(f"`{part}` {READS_STANDARD_INPUT}", HAND_IT_THE_COMMANDS)
        case opentofu_commands.Run(program=program, arguments=arguments, part=part, origin=origin):
            if opentofu_commands.names_tofu(program):
                return tofu_run(arguments, part, origin)
            return tool_run(arguments, part, origin) if names_the_tool(program) else None


def denial(command: str) -> str | None:
    """Return why the hook denies a shell command, or None to let it run."""
    reasons = (verdict(finding) for finding in opentofu_commands.findings(command))
    return next((reason for reason in reasons if reason is not None), None)


def names_the_tool(word: shell_syntax.Word) -> bool:
    """Return whether a word names the tool of build:live-mutation, by its name or a path that ends in it."""
    if word.value is not None:
        return shell_syntax.command_name(word.value) == TOOL
    return TOOL_AT_THE_END.search(word.text) is not None


def runs_one_of(arguments: ct.Sequence[shell_syntax.Word], subcommands: frozenset[str]) -> bool:
    """Return whether the tool, run with these arguments, may run one of the subcommands.

    Its subcommand is the first argument that is not --, and it counts when an expansion hides it.
    """
    subcommand = next((argument for argument in arguments if argument.value != "--"), None)
    return subcommand is not None and (subcommand.value is None or subcommand.value in subcommands)


def shell_calls_the_tool(arguments: ct.Sequence[shell_syntax.Word]) -> bool:
    """Return whether a shell run with these arguments may call propose, demonstrate or run of the tool.

    The command of its -c counts when an expansion hides it, and standard input always counts, since the hook does
    not see what a heredoc, a here-string or a pipe hands the shell.
    """
    operand = opentofu_commands.shell_command(arguments)
    if operand is None:
        return opentofu_commands.reads_standard_input(arguments)
    command = opentofu_commands.script(operand)
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
        return runs_one_of(arguments, LIVE_SUBCOMMANDS)
    match shell_syntax.command_name(program.value):
        case name if name in opentofu_commands.SHELLS:
            return shell_calls_the_tool(arguments)
        case "eval":
            command = opentofu_commands.evaluated(arguments)
            return command is None or calls_the_tool(command)
        case "alias":
            return any(alias_calls_the_tool(argument) for argument in arguments)
        case _:
            return False


def call_calls_the_tool(words: ct.Sequence[shell_syntax.Word]) -> bool:
    """Return whether a simple command may call propose, demonstrate or run of the tool of build:live-mutation.

    The tool counts only where the command may run it as a program, never as an argument of another program.
    """
    return any(
        program_calls_the_tool(words[position], arguments)
        for position in opentofu_commands.program_positions(words)
        for arguments, _ in opentofu_commands.readings(words, position)
    )


def calls_the_tool(command: str) -> bool:
    """Return whether a shell command may call propose, demonstrate or run of the tool of build:live-mutation.

    A command that names the tool counts when the hook cannot parse it, when a shell in it reads commands from
    standard input, and when a simple command in it may call one of the three.
    """
    if NAMES_THE_TOOL.search(command) is None:
        return False
    try:
        parts = shell_syntax.calls_and_redirections(command, opentofu_commands.DIALECTS, resolve_variables=True)
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
        reason = None if opentofu_commands.NAMES_TOFU.search(command) is None else denial(command)
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
