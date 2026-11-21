# ruff: noqa: INP001  # a hook script that Claude Code runs by its path, which no package holds
"""Deny a shell command that writes a currency pair in lower case, since the rate script reads it as no pair."""

import json
import re
import sys

import pairs

WORD = re.compile(r"\b[A-Za-z]{3}/[A-Za-z]{3}\b")


def main() -> int:
    command = json.load(sys.stdin).get("tool_input", {}).get("command", "")
    for word in WORD.findall(command):
        try:
            pairs.parse(word)
        except pairs.PairError:
            decision = {
                "hookEventName": "PreToolUse",
                "permissionDecision": "deny",
                "permissionDecisionReason": f"{word} names no pair: write it as {word.upper()}",
            }
            print(json.dumps({"hookSpecificOutput": decision}))
            break
    return 0


if __name__ == "__main__":
    sys.exit(main())
