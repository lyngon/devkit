#!/usr/bin/env python3
"""PreToolUse hook of build:auto on Edit, Write, NotebookEdit and Bash: the lead writes no code.

Of a shell command it refuses the writes that shell_writes can name before the command runs. Any other
program may write files as well, an interpreter or git among them, and the hook cannot tell that from a read.
"""

import json
import pathlib
import sys
import typing as t

import shell_syntax
import shell_writes

LEADS_DIRECTORIES: tuple[tuple[str, ...], ...] = (("tmp",), ("docs", "plans"), ("docs", "mistakes"))

DELEGATE = (
    'Start a build:implementer delegate (subagent_type "build:implementer") with a brief that names the file, '
    "and review its diff. "
    "The lead writes, by any tool, only under tmp/, docs/plans/ and docs/mistakes/ of the repository, and outside it"
)

BY_ITS_PATH = "and its command names such a file by a path without a variable or a substitution"

REWRITE = "Write the command without that construct."


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
        try:
            part = shell_writes.first_write(command, cwd, in_the_change)
        except shell_syntax.UnreadableError as error:
            unread = f"and the hook cannot read this command, since {error}, so it cannot tell what it writes"
            return refusal(f"In /build:auto the lead writes no code, {unread}. {REWRITE} {DELEGATE}, {BY_ITS_PATH}.")
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
