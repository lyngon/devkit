#!/usr/bin/env python3
"""Hook of the repo plugin: two live Claude Code sessions never work in one working tree.

PreToolUse, on the tools that change a working tree: denies the call while a live session that started before this
one works in the call's tree, and says how this session moves on. SessionStart: says so when Claude Code's registry
of live sessions holds no entry for this session, since every call then runs unchecked; otherwise, at startup, names
each earlier session in this session's tree and how to end it, on screen and to the model. A resumed session runs
SessionStart in the tree it was launched in, before it enters its worktree, so it gets those names at its first
UserPromptSubmit instead, which runs in the tree it works in.
"""

import contextlib
import dataclasses
import json
import os
import pathlib
import re
import sys
import time
import typing as t

STAT_STATE = 3

STAT_PPID = 4

STAT_TERMINAL = 7

STAT_STARTTIME = 22

ENTRYPOINTS = {"cli": "a CLI session", "sdk-cli": "a headless session", "claude-vscode": "a VS Code session"}

UNREGISTERED = (
    "Claude Code's registry of live sessions, {registry}, holds no entry for this session,"
    " so the repo plugin cannot tell whether another session works in this working tree,"
    " and nothing stops a second session from working in it beside this one."
)

SESSION_ID = re.compile(r"[A-Za-z0-9_-]+")

WEEK_SECONDS = 7 * 24 * 60 * 60


@dataclasses.dataclass(frozen=True, slots=True)
class Session:
    """A live Claude Code session: a registry entry whose process still runs with the start time it records."""

    pid: int
    process_start: int
    name: str
    entrypoint: str
    status: str
    status_since: float | None
    stopped: bool
    terminal: int | None

    @property
    def order(self) -> tuple[int, int]:
        """Sort from the earliest session to the latest: by the start time of the process, then by its pid."""
        return self.process_start, self.pid


def registry() -> pathlib.Path:
    """Return the directory where Claude Code keeps one file for each live session, named after its pid."""
    return pathlib.Path(os.environ.get("CLAUDE_CONFIG_DIR") or pathlib.Path.home() / ".claude") / "sessions"


def stat(pid: int) -> list[str] | None:
    """Return the fields of /proc/<pid>/stat at the numbers proc(5) gives them, or None when no process has the pid.

    The second field, the command name in parentheses, may hold spaces and parentheses itself, so the fields after it
    are counted from the last closing parenthesis.
    """
    try:
        content = pathlib.Path(f"/proc/{pid}/stat").read_text()
    except OSError:
        return None
    head, _, tail = content.rpartition(")")
    return ["", *head.split(" (", 1), *tail.split()]


def text(entry: dict[str, object], key: str) -> str:
    """Return the string under a key, or "" for anything else or nothing."""
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
    if not isinstance(pid, int):
        return None
    fields = stat(pid)
    if fields is None or fields[STAT_STARTTIME] != process_start:
        return None
    return Session(
        pid=pid,
        process_start=int(process_start),
        name=text(entry, "name") or text(entry, "sessionId") or f"pid {pid}",
        entrypoint=text(entry, "entrypoint"),
        status=text(entry, "status"),
        status_since=since / 1000 if isinstance(since, int | float) else None,
        stopped=fields[STAT_STATE] == "T",
        terminal=int(fields[STAT_TERMINAL]) or None,
    )


def own_session() -> Session | None:
    """Return the session that runs this hook: the nearest ancestor process with a live entry in the registry.

    Claude Code starts a hook as a child of the session's process. The search goes on past the parent because a shell
    that runs the hook's command may stay in between, as Ubuntu's dash does for a lone command.
    """
    pid = os.getppid()
    while pid > 1:
        found = session(registry() / f"{pid}.json")
        if found is not None and found.pid == pid:
            return found
        fields = stat(pid)
        pid = int(fields[STAT_PPID]) if fields else 0
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


def terminal_path(device: int | None) -> str | None:
    """Return the path of the terminal with a device number, as field 7 of /proc/<pid>/stat gives it.

    None without a terminal and for a number that no terminal under /dev has.
    """
    if device is None:
        return None
    for path in (*pathlib.Path("/dev/pts").glob("*"), *pathlib.Path("/dev").glob("tty*")):
        try:
            if path.stat().st_rdev == device:
                return str(path)
        except OSError:
            continue
    return None


def describe(other: Session, now: float) -> str:
    """Return how the hook names a session: its name, pid, kind and terminal, then what it is doing."""
    kind = ENTRYPOINTS.get(other.entrypoint, f"entrypoint {other.entrypoint}") if other.entrypoint else "a session"
    terminal = terminal_path(other.terminal)
    details = [f"pid {other.pid}", f"{kind} on {terminal}" if terminal else kind]
    if other.stopped:
        details.append("stopped")
    elif other.status == "idle" and other.status_since is not None:
        details.append(f"idle for {duration(now - other.status_since)}")
    elif other.status:
        details.append(other.status)
    return f'"{other.name}" ({", ".join(details)})'


def ending(other: Session, own: Session) -> str:
    """Return how the operator ends a session in the state it is in."""
    name = f'"{other.name}"'
    if not other.stopped:
        return f"kill {other.pid} ends {name}."
    if other.terminal is None:
        return f"{name} is stopped, so a plain kill leaves it stopped, and kill -KILL {other.pid} ends it."
    here = other.terminal == own.terminal
    where = "this terminal" if here else terminal_path(other.terminal) or "another terminal"
    job = f"{name} is stopped, a job of the shell that started it on {where}, so a plain kill leaves it stopped:"
    if here:
        return f"{job} end this session with /exit, then run fg in that shell and end {name} with /exit."
    return f"{job} run fg in that shell and end it with /exit."


@dataclasses.dataclass(frozen=True, slots=True)
class Wording:
    """The words that the hook's messages take for one earlier session, or for several."""

    sessions: str
    work: str
    ended: str
    it: str


ONE = Wording(sessions="session", work="works", ended="that session has ended", it="it has")

SEVERAL = Wording(sessions="sessions", work="work", ended="those sessions have ended", it="they have")


def earlier_in(tree: pathlib.Path, own: Session) -> list[Session]:
    """Return the live sessions that started before this one and work in its working tree, from the earliest."""
    return [other for other in live_sessions() if other.order < own.order and process_tree(other.pid) == tree]


def held(earlier: list[Session], wording: Wording, tree: pathlib.Path, head: str | None, now: float) -> str:
    """Return the line that names the earlier sessions in a working tree, and the line that says what follows."""
    checked = f" which has {head} checked out," if head else ""
    return (
        f"The Claude Code {wording.sessions} {enumeration([describe(other, now) for other in earlier])} {wording.work}"
        f" in this working tree, {tree},{checked} and started before this session.\n"
        "Two sessions in one working tree change its HEAD, its index and its files under each other,"
        " so the repo plugin refuses this session's edits and shell commands here"
        f" until this session has moved to a worktree of its own or {wording.ended}."
    )


def denial(own: Session, tree: pathlib.Path, now: float) -> str | None:
    """Return why this session may not change its working tree, or None when no earlier live session works there."""
    earlier = earlier_in(tree, own)
    if not earlier:
        return None
    wording = ONE if len(earlier) == 1 else SEVERAL
    names = enumeration(['"' + other.name + '"' for other in earlier])
    head = checked_out(tree)
    allowed = (
        " Every other tool still works, Read, EnterWorktree and ExitWorktree among them."
        " The standing instructions at the start of this session ask for this move,"
        " so it counts as the operator asking for each call below."
    )
    stay = (
        f"- If your task continues the work on {head or 'what is checked out there'},"
        f" ask the operator to close the {wording.sessions} {names}, and carry on here once {wording.it} ended."
    )
    move = (
        "- Otherwise, call EnterWorktree without a name, so that it creates a new worktree under a name it generates,"
        " since a name in use would enter that worktree, and carry on there."
        " If EnterWorktree answers that this session is in a worktree session already,"
        " call ExitWorktree with action keep first, never remove,"
        f" because the other {wording.sessions} {wording.work} in it."
    )
    return f"{held(earlier, wording, tree, head, now)}{allowed}\n{stay}\n{move}"


def warning(own: Session, tree: pathlib.Path, event: str, now: float) -> dict[str, object] | None:
    """Return the output for a hook event that names the earlier sessions in this session's tree and how to end each.

    The CLI shows the systemMessage on screen and never passes it to the model. VS Code shows none, so the
    additionalContext asks the model to pass it on. None when no earlier live session works in the tree.
    """
    earlier = earlier_in(tree, own)
    if not earlier:
        return None
    wording = ONE if len(earlier) == 1 else SEVERAL
    endings = " ".join(ending(other, own) for other in earlier)
    message = f"{held(earlier, wording, tree, checked_out(tree), now)}\n{endings}"
    context = f"{message}\nTell the operator in your next reply."
    return {"systemMessage": message, "hookSpecificOutput": {"hookEventName": event, "additionalContext": context}}


def resume_record(hook_input: dict[str, object]) -> pathlib.Path | None:
    """Return the file that records a resume of the input's session until the session's first prompt.

    None when the input names no session id of the form Claude Code gives one.
    """
    session_id = text(hook_input, "session_id")
    if SESSION_ID.fullmatch(session_id) is None:
        return None
    return pathlib.Path(os.environ["CLAUDE_PLUGIN_DATA"]) / "resumed-without-session-warning" / session_id


def record_resume(hook_input: dict[str, object], now: float) -> None:
    """Record a resumed session until its first prompt, and forget the ones resumed over a week ago that got none."""
    record = resume_record(hook_input)
    if record is None:
        return
    record.parent.mkdir(parents=True, exist_ok=True)
    for other in record.parent.iterdir():
        with contextlib.suppress(FileNotFoundError):
            if now - other.stat().st_mtime > WEEK_SECONDS:
                other.unlink()
    record.touch()


def first_prompt_since_resume(hook_input: dict[str, object]) -> bool:
    """Remove the record of a resume of the input's session, and return whether there was one."""
    record = resume_record(hook_input)
    if record is None:
        return False
    try:
        record.unlink()
    except FileNotFoundError:
        return False
    return True


def main() -> None:
    """Read the hook input on stdin and print the hook's output, if any."""
    loaded = t.cast("object", json.load(sys.stdin))
    hook_input = t.cast("dict[str, object]", loaded) if isinstance(loaded, dict) else {}
    event, source = text(hook_input, "hook_event_name"), text(hook_input, "source")
    if event == "UserPromptSubmit" and not first_prompt_since_resume(hook_input):
        return
    if event == "SessionStart" and source == "resume":
        record_resume(hook_input, time.time())
    own = own_session()
    tree = tree_of(pathlib.Path.cwd())
    if own is None:
        if event == "SessionStart":
            print(UNREGISTERED.format(registry=registry()))
        return
    if tree is None:
        return
    if event == "PreToolUse":
        reason = denial(own, tree, time.time())
        if reason is not None:
            output = {"hookEventName": "PreToolUse", "permissionDecision": "deny", "permissionDecisionReason": reason}
            json.dump({"hookSpecificOutput": output}, sys.stdout)
    elif event == "UserPromptSubmit" or (event == "SessionStart" and source == "startup"):
        output = warning(own, tree, event, time.time())
        if output is not None:
            json.dump(output, sys.stdout)


if __name__ == "__main__":
    main()
