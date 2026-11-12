#!/usr/bin/env python3
"""PreToolUse hook of the build plugin on Agent: a subagent starts no subagent of its own.

Claude Code 2.1.283 starts a subagent's own subagent in the background and sends its report to the
lead, so the subagent that started it ends without it.
"""

import json
import sys
import typing as t

REFUSAL = {
    "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "deny",
        "permissionDecisionReason": (
            "A subagent starts no subagent of its own, since the report of that subagent can reach the lead "
            "instead of you. Do this work yourself, here, and put what it finds in your report."
        ),
    }
}


def main() -> None:
    """Read the hook input on stdin and refuse the call when a subagent makes it, which its agent_id shows."""
    hook_input = t.cast("object", json.load(sys.stdin))
    if not isinstance(hook_input, dict):
        sys.exit("subagent-starts-no-subagent.py: the hook input is no JSON object")
    if "agent_id" in hook_input:
        json.dump(REFUSAL, sys.stdout)


if __name__ == "__main__":
    main()
