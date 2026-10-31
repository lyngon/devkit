#!/usr/bin/env python3
"""PreToolUse hook of build:auto on Edit, Write and NotebookEdit: the lead writes no code.

The mode's frontmatter names this hook, so Claude Code runs it only in a
session that started /build:auto, from that turn on, and never in one of its
subagents. In the mode a build:implementer delegate writes the code, however
small the change. The hook refuses the lead, the session without an
`agent_id`, a write of a file inside a repository, and leaves alone what the
playbooks and the skills they route to have the lead write itself: the
scratch under `tmp/` at the root of the repository (the work trace, the pull
request body, arena and prototype files), design files under `docs/plans/`,
ledger files under `docs/mistakes/`, and any file outside a repository. The
repository is the nearest directory above the file that holds `.git`, so a
file in a worktree counts by its path in that worktree. Imports the standard
library only, because the baseline promises a shipped script the interpreter
and nothing else.
"""

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


def answer(hook_input: dict[str, object]) -> dict[str, object] | None:
    """Return the hook's output for a call, or None to let it run as it is."""
    if "agent_id" in hook_input:
        return None
    tool_input = t.cast("dict[str, object]", hook_input["tool_input"])
    target = str(tool_input["file_path"] if "file_path" in tool_input else tool_input["notebook_path"])
    path = (pathlib.Path(str(hook_input["cwd"])) / target).resolve()
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
    # The keys of a JSON object are strings.
    output = answer(t.cast("dict[str, object]", json.load(sys.stdin)))
    if output is not None:
        json.dump(output, sys.stdout)


if __name__ == "__main__":
    main()
