#!/usr/bin/env python3
"""Print an installation token from agent-identity's cache, which every Bash command of an agent session reads.

It imports no more than it needs to read the cache, so that a cached token costs a command about one bare start
of the interpreter. With less than REFRESH_SECONDS left on the token, or none cached, it runs the command that
follows `--` in its place: agent-identity's own token, which mints one and caches it.

Usage: agent_token.py --installation <id> -- <command>...
"""

import datetime as dt
import json
import os
import pathlib
import sys
import typing as t

# A cached token is used while it has this long left, so that no command starts with one that expires midway.
REFRESH_SECONDS: t.Final = 300


def cache_path(installation_id: int) -> pathlib.Path | None:
    """Return the file that caches the installation's token, or None without XDG_RUNTIME_DIR to keep it in."""
    runtime = os.environ.get("XDG_RUNTIME_DIR")
    if not runtime:
        return None
    return pathlib.Path(runtime) / "lyngon-agent-identity" / f"installation-{installation_id}.json"


def fresh(path: pathlib.Path, now: float) -> str | None:
    """Return the cached token while it has REFRESH_SECONDS left, or None when it has not or cannot be read."""
    try:
        table = t.cast("object", json.loads(path.read_text()))
    except (OSError, ValueError):
        return None
    if not isinstance(table, dict):
        return None
    fields = t.cast("dict[str, object]", table)
    value, expires_at = fields.get("token"), fields.get("expires_at")
    if not isinstance(value, str) or not isinstance(expires_at, str):
        return None
    try:
        left = dt.datetime.fromisoformat(expires_at).timestamp() - now
    except ValueError:
        return None
    return value if left > REFRESH_SECONDS else None


def main() -> None:
    """Print the cached token, or run the command that mints one."""
    arguments = sys.argv[1:]
    if len(arguments) < 4 or arguments[0] != "--installation" or arguments[2] != "--":  # noqa: PLR2004  # the usage
        sys.exit("usage: agent_token.py --installation <id> -- <command>...")
    path = cache_path(int(arguments[1]))
    value = None if path is None else fresh(path, dt.datetime.now(dt.UTC).timestamp())
    if value is None:
        os.execv(arguments[3], arguments[3:])  # noqa: S606  # the command agent-identity wrote into the line
    print(value)


if __name__ == "__main__":
    main()
