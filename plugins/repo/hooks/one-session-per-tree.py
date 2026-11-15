#!/usr/bin/env python3
"""Hook of the repo plugin: two live Claude Code sessions never work in one working tree.

PreToolUse, on the tools that change a working tree: denies the call while a live session that started before this
one works in the call's tree, and says how this session moves on. SessionStart: says so when Claude Code's registry
of live sessions holds no entry for this session, since every call then runs unchecked.
"""

import dataclasses
import json
import os
import pathlib
import sys
import time
import typing as t

PARENT_PID = 4

START_TIME = 22

ENTRYPOINTS = {"cli": "a CLI session", "sdk-cli": "a headless session", "claude-vscode": "a VS Code session"}

WORKTREE_OPTIONS = frozenset({b"-w", b"--worktree"})

UNREGISTERED = (
    "Claude Code's registry of live sessions, {registry}, holds no entry for this session,"
    " so the repo plugin cannot tell whether another session works in this working tree,"
    " and nothing stops a second session from working in it beside this one."
)


@dataclasses.dataclass(frozen=True, slots=True)
class Session:
    """A live Claude Code session: a registry entry whose process still runs with the start time it records."""

    pid: int
    process_start: int
    name: str
    entrypoint: str
    status: str
    status_since: float | None

    @property
    def order(self) -> tuple[int, int]:
        """Sort from the earliest session to the latest: by the start time of the process, then by its pid."""
        return self.process_start, self.pid


def registry() -> pathlib.Path:
    """Return the directory where Claude Code keeps one file for each live session, named after its pid."""
    return pathlib.Path(os.environ.get("CLAUDE_CONFIG_DIR") or pathlib.Path.home() / ".claude") / "sessions"


def stat_field(pid: int, number: int) -> int | None:
    """Return the numeric field of /proc/<pid>/stat that proc(5) numbers so, or None when no process has the pid.

    The second field, the command name in parentheses, may hold spaces and parentheses itself, so the count goes on
    after the last closing parenthesis, with the third field.
    """
    try:
        stat = pathlib.Path(f"/proc/{pid}/stat").read_text()
    except OSError:
        return None
    return int(stat.rpartition(")")[2].split()[number - 3])


def text(entry: dict[str, object], key: str) -> str:
    """Return the string a registry entry holds under a key, or "" when it holds something else or nothing."""
    value = entry.get(key)
    return value if isinstance(value, str) else ""


def session(path: pathlib.Path) -> Session | None:
    """Return the live session of a registry file.

    None when the file cannot be read or has another shape, when its process has ended, or when its pid now belongs
    to a process with another start time, as after a crash.
    """
    try:
        value = t.cast("object", json.loads(path.read_bytes()))
    except (OSError, ValueError):
        return None
    if not isinstance(value, dict):
        return None
    entry = t.cast("dict[str, object]", value)
    pid, process_start, since = entry.get("pid"), str(entry.get("procStart")), entry.get("statusUpdatedAt")
    if not isinstance(pid, int) or not process_start.isdigit() or stat_field(pid, START_TIME) != int(process_start):
        return None
    return Session(
        pid=pid,
        process_start=int(process_start),
        name=text(entry, "name") or text(entry, "sessionId") or f"pid {pid}",
        entrypoint=text(entry, "entrypoint"),
        status=text(entry, "status"),
        status_since=since / 1000 if isinstance(since, int | float) else None,
    )


def own_session() -> Session | None:
    """Return the session that runs this hook: the nearest ancestor process with a live entry in the registry.

    Claude Code starts a hook as its own child, and the nearest ancestor and not the parent keeps it so when a shell
    that runs the hook's command stays in between.
    """
    pid = os.getppid()
    while pid > 1:
        found = session(registry() / f"{pid}.json")
        if found is not None and found.pid == pid:
            return found
        pid = stat_field(pid, PARENT_PID) or 0
    return None


def live_sessions() -> list[Session]:
    """Return every live session in the registry, from the earliest to the latest."""
    found = (session(path) for path in registry().glob("*.json"))
    return sorted((live for live in found if live is not None), key=lambda live: live.order)


def tree_of(directory: pathlib.Path) -> pathlib.Path | None:
    """Return the working tree that holds a directory: the nearest directory at or above it that holds .git."""
    return next((candidate for candidate in (directory, *directory.parents) if (candidate / ".git").exists()), None)


def process_tree(pid: int) -> pathlib.Path | None:
    """Return the working tree that holds a process's working directory, or None when it has ended or is in none."""
    try:
        return tree_of(pathlib.Path(f"/proc/{pid}/cwd").readlink())
    except OSError:
        return None


def checked_out(tree: pathlib.Path) -> str | None:
    """Return what a working tree has checked out, as "the branch <name>" or "the detached HEAD at <commit>"."""
    git = tree / ".git"
    try:
        if git.is_file():
            git = tree / git.read_text().removeprefix("gitdir:").strip()
        head = (git / "HEAD").read_text().strip()
    except OSError:
        return None
    if head.startswith("ref: "):
        return f"the branch {head.removeprefix('ref: ').removeprefix('refs/heads/')}"
    return f"the detached HEAD at {head[:12]}"


def in_worktree_session(own: Session, tree: pathlib.Path) -> bool:
    """Return whether the session is in a worktree session, where EnterWorktree creates no new worktree.

    It is when it started with --worktree, and when it moved into its tree after it started, by EnterWorktree or by a
    resume into a worktree, both of which leave CLAUDE_PROJECT_DIR at the tree it started in.
    """
    try:
        arguments = pathlib.Path(f"/proc/{own.pid}/cmdline").read_bytes().split(b"\0")
    except OSError:
        arguments = []
    if any(argument in WORKTREE_OPTIONS or argument.startswith(b"--worktree=") for argument in arguments):
        return True
    project = os.environ.get("CLAUDE_PROJECT_DIR")
    return project is not None and tree_of(pathlib.Path(project).resolve()) != tree


def duration(seconds: float) -> str:
    """Return a span of time in days, hours and minutes, leaving out the units that are zero."""
    minutes = int(seconds // 60)
    if minutes < 1:
        return "less than a minute"
    days, minutes = divmod(minutes, 24 * 60)
    hours, minutes = divmod(minutes, 60)
    return " ".join(f"{count} {unit}" for count, unit in ((days, "d"), (hours, "h"), (minutes, "min")) if count)


def enumeration(items: list[str]) -> str:
    """Return items as a sentence lists them: "a", "a and b", "a, b and c"."""
    return items[0] if len(items) == 1 else f"{', '.join(items[:-1])} and {items[-1]}"


def describe(other: Session, now: float) -> str:
    """Return how a refusal names a session: its name, then what kind of session it is and what it is doing."""
    details = [ENTRYPOINTS.get(other.entrypoint, f"entrypoint {other.entrypoint}")] if other.entrypoint else []
    if other.status == "idle" and other.status_since is not None:
        details.append(f"idle for {duration(now - other.status_since)}")
    elif other.status:
        details.append(other.status)
    return f'"{other.name}" ({", ".join(details)})' if details else f'"{other.name}"'


def denial(own: Session, tree: pathlib.Path, now: float) -> str | None:
    """Return why this session may not change its working tree, or None when no earlier live session works there."""
    earlier = [other for other in live_sessions() if other.order < own.order and process_tree(other.pid) == tree]
    if not earlier:
        return None
    if len(earlier) == 1:
        sessions, work, ended, it = "session", "works", "that session has ended", "it has"
    else:
        sessions, work, ended, it = "sessions", "work", "those sessions have ended", "they have"
    names = enumeration(['"' + other.name + '"' for other in earlier])
    head = checked_out(tree)
    checked = f" which has {head} checked out," if head else ""
    who = (
        f"The Claude Code {sessions} {enumeration([describe(other, now) for other in earlier])} {work}"
        f" in this working tree, {tree},{checked} and started before this session."
    )
    why = (
        "Two sessions in one working tree change its HEAD, its index and its files under each other,"
        " so the repo plugin refuses this session's edits and shell commands here"
        f" until this session has moved to a worktree of its own or {ended}."
        " Every other tool still works, Read, EnterWorktree and ExitWorktree among them."
        " The operator's standing instructions ask for this move, so it counts as the operator asking for a worktree."
    )
    stay = (
        f"- If your task continues the work on {head or 'what is checked out there'},"
        f" ask the operator to close the {sessions} {names}, and carry on here once {it} ended."
    )
    if in_worktree_session(own, tree):
        move = (
            f"- Otherwise, ask the operator to close the {sessions} {names} or to start this session again"
            " in another worktree, because this session cannot leave its worktree by itself."
        )
    else:
        move = "- Otherwise, call EnterWorktree with a name of your own for your task, and carry on there."
    return f"{who}\n{why}\n{stay}\n{move}"


def main() -> None:
    """Read the hook input on stdin and print the hook's output, if any."""
    hook_input = t.cast("object", json.load(sys.stdin))
    event = t.cast("dict[str, object]", hook_input).get("hook_event_name") if isinstance(hook_input, dict) else None
    own = own_session()
    if event == "SessionStart":
        if own is None:
            print(UNREGISTERED.format(registry=registry()))
        return
    tree = tree_of(pathlib.Path.cwd())
    reason = None if own is None or tree is None else denial(own, tree, time.time())
    if reason is not None:
        output = {"hookEventName": "PreToolUse", "permissionDecision": "deny", "permissionDecisionReason": reason}
        json.dump({"hookSpecificOutput": output}, sys.stdout)


if __name__ == "__main__":
    main()
