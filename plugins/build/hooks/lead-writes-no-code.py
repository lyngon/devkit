#!/usr/bin/env python3
"""PreToolUse hook of build:auto on Edit, Write and NotebookEdit: the lead writes no code."""

import json
import pathlib
import sys
import typing as t

LEADS_DIRECTORIES: tuple[tuple[str, ...], ...] = (("tmp",), ("docs", "plans"), ("docs", "mistakes"))


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


def answer(hook_input: dict[str, object]) -> dict[str, object] | None:
    """Return the hook's output for a call, or None to let it run as it is. Exits 1 when the call names no file."""
    if "agent_id" in hook_input:
        return None
    tool_input = json_object(hook_input.get("tool_input"), "its tool_input")
    target = tool_input.get("file_path", tool_input.get("notebook_path"))
    if not isinstance(target, str):
        sys.exit("lead-writes-no-code.py: its tool_input names no file")
    path = (pathlib.Path(str(hook_input.get("cwd", ""))) / target).resolve()
    if not in_the_change(path):
        return None
    reason = (
        f"In /build:auto the lead writes no code, so it may not write {target}. "
        'Start a build:implementer delegate (subagent_type "build:implementer") with a brief that names the file, '
        "and review its diff. "
        "The lead writes only under tmp/, docs/plans/ and docs/mistakes/ of the repository, and outside it."
    )
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
