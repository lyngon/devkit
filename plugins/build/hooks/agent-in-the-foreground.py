#!/usr/bin/env python3
"""PreToolUse hook of the build plugin on Agent: a call without run_in_background runs in the foreground."""

import json
import sys
import typing as t


def json_object(value: object, name: str) -> dict[str, object]:
    """Return the value as a JSON object, whose keys are strings. Exits 1, naming it, when it is no object."""
    if not isinstance(value, dict):
        sys.exit(f"agent-in-the-foreground.py: {name} is no JSON object")
    return t.cast("dict[str, object]", value)


def answer(tool_input: dict[str, object]) -> dict[str, object] | None:
    """Return the hook's output for a call with this input, or None to let it run as it is."""
    if "run_in_background" in tool_input:
        return None
    updated = {**tool_input, "run_in_background": False}
    return {"hookSpecificOutput": {"hookEventName": "PreToolUse", "updatedInput": updated}}


def main() -> None:
    """Read the hook input on stdin and print the output, if any."""
    hook_input = json_object(t.cast("object", json.load(sys.stdin)), "the hook input")
    output = answer(json_object(hook_input.get("tool_input"), "its tool_input"))
    if output is not None:
        json.dump(output, sys.stdout)


if __name__ == "__main__":
    main()
