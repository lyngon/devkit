#!/usr/bin/env python3
"""PreToolUse hook of the build plugin on Bash and Monitor: an OpenTofu command that writes runs through live-mutation.

It denies rather than asks, since build:live-mutation decides whether a live mutation waits for the owner, and it
denies in a subagent as in the lead. A command that names tofu and that the hook cannot read is denied too.
A program that runs tofu itself, such as live-mutation.py, make or a script file, is a process the hook never sees.
"""

import collections.abc as ct
import itertools
import json
import re
import sys
import typing as t

import shell_syntax

ROUTE = (
    "An OpenTofu command that writes runs only through build:live-mutation: the lead invokes that skill,"
    " proposes the command with the skill's tool and runs it there on the owner's go-ahead,"
    " and a subagent stops and reports the command to its lead."
)

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

OPENTOFU_FLAKE = re.compile(r"[^#]*#(?:.*\.)?opentofu")

DOUBLE_QUOTED = re.compile(r'"((?:[^"\\]|\\.)*)"', re.DOTALL)

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
    """Return the command that a shell runs from a word, or None when an expansion hides it.

    A word in double quotes stands for the text inside them, where each expansion stays one for the hook to read.
    """
    if operand.value is not None:
        return operand.value
    quoted = DOUBLE_QUOTED.fullmatch(operand.text)
    return None if quoted is None else re.sub(r"\\([\\\"`$])", r"\1", quoted.group(1))


def shell_scripts(words: ct.Sequence[shell_syntax.Word]) -> list[str | None]:
    """Return the commands that a call hands a shell to run, the operand of a shell's -c or what eval joins.

    A command is None when an expansion hides it.
    """
    if words and words[0].value == "eval":
        scripts = [script(argument) for argument in words[1:]]
        return [None if None in scripts else " ".join(t.cast("list[str]", scripts))]
    found: list[str | None] = []
    for index, word in enumerate(words):
        rest = words[index + 1 :]
        if shell_syntax.command_name(word.value) in SHELLS:
            option = next(
                (at for at, argument in enumerate(rest) if SHELL_COMMAND_OPTION.fullmatch(argument.value or "")), None
            )
            operand = None if option is None else next((w for w in rest[option + 1 :] if not passed_over(w)), None)
            if operand is not None:
                found.append(script(operand))
    return found


def call_denial(call: shell_syntax.Call) -> str | None:
    """Return why the hook denies a simple command of a command that names tofu, or None to let it run."""
    if call.words and call.words[0].value is None:
        return hidden(call.text, f"its program {EXPANDED}")
    for command in shell_scripts(call.words):
        if command is None:
            return hidden(call.text, f"the command it hands a shell {EXPANDED}")
        reason = denial(command)
        if reason is not None:
            return reason
    for index, word in enumerate(call.words):
        reason = tofu_run(call.words[index + 1 :], call.text) if names_tofu(word) else None
        if reason is not None:
            return reason
    return None


def denial(command: str) -> str | None:
    """Return why the hook denies a shell command, or None to let it run."""
    if "tofu" not in command.lower():
        return None
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


def answer(hook_input: dict[str, object]) -> dict[str, object] | None:
    """Return the hook's output for a call, or None to let it run as it is.

    Exits 1 when the hook input or its tool_input is no JSON object.
    """
    command = json_object(hook_input.get("tool_input"), "its tool_input").get("command")
    reason = denial(command) if isinstance(command, str) else None
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
