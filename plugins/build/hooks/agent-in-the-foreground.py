#!/usr/bin/env python3
"""PreToolUse hook of the build plugin on the Agent tool: a subagent starts in the foreground.

A headless session starts a subagent in the background when the call leaves
`run_in_background` out, and the lead then ends its turn to wait for it, while
every skill of this plugin asks for the foreground. The hook answers such a
call with its input plus `run_in_background: false`, which Claude Code runs in
place of the input the model wrote, and with no permission decision, so the
call still meets the session's permissions. A call that names the parameter
runs as it is. Imports the standard library only, because the baseline
promises a shipped script the interpreter and nothing else.
"""

import json
import sys
import typing as t


def answer(tool_input: dict[str, object]) -> dict[str, object] | None:
    """Return the hook's output for a call with this input, or None to let it run as it is."""
    if "run_in_background" in tool_input:
        return None
    updated = {**tool_input, "run_in_background": False}
    return {"hookSpecificOutput": {"hookEventName": "PreToolUse", "updatedInput": updated}}


def main() -> None:
    """Read the hook input on stdin and print the output, if any. Exits 1 on an input without a tool input."""
    # The keys of a JSON object are strings.
    hook_input = t.cast("dict[str, object]", json.load(sys.stdin))
    tool_input = hook_input.get("tool_input")
    if not isinstance(tool_input, dict):
        sys.exit("agent-in-the-foreground.py: the hook input holds no object tool_input")
    output = answer(t.cast("dict[str, object]", tool_input))
    if output is not None:
        json.dump(output, sys.stdout)


if __name__ == "__main__":
    main()
