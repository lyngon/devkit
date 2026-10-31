#!/usr/bin/env python3
"""Stop hook of build:auto: a reply whose prose holds an em dash or an en dash goes back to the lead."""

import json
import re
import sys
import typing as t

DASH = re.compile("[\u2013\u2014]")
INLINE_CODE = re.compile(r"(`+).*?(?<!`)\1(?!`)")
FENCE = re.compile(r"\s*(`{3,}|~{3,})")


def json_object(value: object, name: str) -> dict[str, object]:
    """Return the value as a JSON object, whose keys are strings. Exits 1, naming it, when it is no object."""
    if not isinstance(value, dict):
        sys.exit(f"reply-has-no-dash.py: {name} is no JSON object")
    return t.cast("dict[str, object]", value)


def lines_with_a_dash(reply: str) -> list[str]:
    """Return the lines of the reply whose prose, outside fenced and inline code, holds a dash."""
    found: list[str] = []
    opening = ""
    for line in reply.splitlines():
        fence = FENCE.match(line)
        if fence and not opening:
            opening = fence.group(1)
        elif fence and fence.group(1)[0] == opening[0] and len(fence.group(1)) >= len(opening):
            opening = ""
        elif not opening and DASH.search(INLINE_CODE.sub("", line)):
            found.append(line.strip())
    return found


def answer(hook_input: dict[str, object]) -> dict[str, object] | None:
    """Return the hook's output at the end of a turn, or None to let the turn end."""
    if hook_input.get("stop_hook_active") is True:
        return None
    lines = lines_with_a_dash(str(hook_input.get("last_assistant_message", "")))
    if not lines:
        return None
    quoted = "\n".join(f"> {line}" for line in lines)
    reason = (
        "The reply holds an em dash or an en dash, which the reply rules of /build:auto forbid, in these lines:\n"
        f"{quoted}\n"
        "Write the whole reply again, with a comma, parentheses or a new sentence in place of each dash, "
        "put a quote that must keep its dash in code font, and change nothing else."
    )
    return {"decision": "block", "reason": reason}


def main() -> None:
    """Read the hook input on stdin and print the output, if any."""
    output = answer(json_object(t.cast("object", json.load(sys.stdin)), "the hook input"))
    if output is not None:
        json.dump(output, sys.stdout)


if __name__ == "__main__":
    main()
