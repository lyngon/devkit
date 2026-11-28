#!/usr/bin/env python3
"""Stop and SubagentStop hook: the last line of a turn of the lead says whether its session runs, waits or is done.

At the end of a turn of the lead it sends the last message back until the message ends with the status marker that
fits, alone on its last line, and holds no marker before that line. ⏳ fits while something that the session started
runs or waits to wake it, as Claude Code lists in the hook input, and 🔔 or 🏁 fits when nothing does. 🏁 also needs a
checkout that holds nothing that origin lacks: no path that `git status` lists, and every commit on a branch of origin
unless HEAD is the commit of a ref there, such as the head that GitHub keeps of a pull request after its branch is
deleted. Whether a question is open, or something the operator asked for is unfinished, is for the agent to judge.
At the end of a subagent it sends back a report that holds a marker, since the markers say where the lead stands.

It sends a message back as often as the message fails, since a marker that fits is always open to the agent, and
Claude Code ends the turn after 8 blocks in a row (CLAUDE_CODE_STOP_HOOK_BLOCK_CAP, on 2.1.321 to 2.1.329).
"""

import enum
import json
import os
import pathlib
import subprocess
import sys
import typing as t


class Status(enum.Enum):
    """A status marker: the line that ends the last message of a turn of the lead."""

    RUNNING = "⏳ Still running"
    YOUR_MOVE = "🔔 Your move"
    COMPLETE = "🏁 Session complete"

    @property
    def emoji(self) -> str:
        """Return the emoji that starts the marker, which appears nowhere else in what the session writes."""
        return self.value[0]


# A model may write an emoji with the selector that asks for its emoji form, which no reader sees.
VARIATION_SELECTOR = "️"

# Background tasks that Claude Code starts on its own, to consolidate memories and to scan for an auto-mode setup.
CLAUDE_CODES_OWN_TASKS = frozenset({"dream", "auto-mode scan"})

GIT_SECONDS = 10


class CheckoutUnreadError(Exception):
    """A git command that the check of the checkout needs could not run, failed, or gave no answer in time."""


def json_object(value: object, name: str) -> dict[str, object]:
    """Return the value as a JSON object, whose keys are strings. Exits 1, naming it, when it is no object."""
    if not isinstance(value, dict):
        sys.exit(f"turn-ends-with-a-status-marker.py: {name} is no JSON object")
    return t.cast("dict[str, object]", value)


def json_objects(hook_input: dict[str, object], key: str) -> list[dict[str, object]]:
    """Return a list of JSON objects from the hook input. Exits 1, naming it, when the input lacks it."""
    value = hook_input.get(key)
    if not isinstance(value, list):
        sys.exit(f"turn-ends-with-a-status-marker.py: the hook input holds no list {key}, which Claude Code sends")
    return [json_object(item, f"an item of {key}") for item in t.cast("list[object]", value)]


def still_running(hook_input: dict[str, object]) -> list[str]:
    """Return what the session started and still runs or waits to wake it, one description each."""
    work = [
        f"the {task.get('type')} {task.get('id')} ({task.get('description')})"
        for task in json_objects(hook_input, "background_tasks")
        if task.get("type") not in CLAUDE_CODES_OWN_TASKS
    ]
    work.extend(
        f"the scheduled wake-up {cron.get('id')} ({cron.get('schedule')})"
        for cron in json_objects(hook_input, "session_crons")
    )
    return work


def status_of(line: str) -> Status | None:
    """Return the status marker that a line is, or None when it is none."""
    try:
        return Status(line.strip().replace(VARIATION_SELECTOR, ""))
    except ValueError:
        return None


def holds_a_marker(text: str) -> bool:
    """Say whether a text holds the emoji of a status marker."""
    return any(status.emoji in text for status in Status)


def git(cwd: pathlib.Path, *arguments: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    """Run git in the directory, with its messages in English, and return how it ended.

    Raises CheckoutUnreadError when git is not on the PATH, gives no answer within GIT_SECONDS, or fails while
    check is true, with its first error line.
    """
    try:
        result = subprocess.run(
            ["git", "-C", str(cwd), *arguments],
            capture_output=True,
            text=True,
            check=False,
            timeout=GIT_SECONDS,
            env=os.environ | {"GIT_TERMINAL_PROMPT": "0", "LC_ALL": "C"},
        )
    except FileNotFoundError as error:
        raise CheckoutUnreadError("git is not on the PATH that Claude Code gives its hooks") from error
    except subprocess.TimeoutExpired as error:
        raise CheckoutUnreadError(f"git {arguments[0]} gave no answer within {GIT_SECONDS} s") from error
    if check and result.returncode != 0:
        raise CheckoutUnreadError(failure(result, arguments[0]))
    return result


def failure(result: subprocess.CompletedProcess[str], command: str) -> str:
    """Return how a git command failed, by its first error line."""
    reason = (result.stderr.strip().splitlines() or [f"exit status {result.returncode}"])[0]
    return f"git {command} failed: {reason}"


def count(number: int, noun: str) -> str:
    """Return a count with its noun, in the plural unless it is one."""
    return f"1 {noun}" if number == 1 else f"{number} {noun}s"


def checkout_around(cwd: pathlib.Path) -> pathlib.Path | None:
    """Return the top level of the working tree that the directory lies in, or None when it lies in no repository.

    Raises CheckoutUnreadError when git fails, as it does in a repository without a working tree.
    """
    top = git(cwd, "rev-parse", "--show-toplevel", check=False)
    if top.returncode != 0 and "not a git repository" in top.stderr:
        return None
    if top.returncode != 0:
        raise CheckoutUnreadError(failure(top, "rev-parse"))
    return pathlib.Path(top.stdout.strip())


def commits_only_here(cwd: pathlib.Path) -> str | None:
    """Describe the commits of HEAD that origin lacks, or return None when origin has them all or there is none.

    Raises CheckoutUnreadError when git cannot show it, as when origin cannot be fetched.
    """
    if git(cwd, "rev-parse", "--verify", "--quiet", "HEAD", check=False).returncode != 0:
        return None
    if git(cwd, "remote", "get-url", "origin", check=False).returncode != 0:
        return "it has commits, and no remote named origin holds them"
    _ = git(cwd, "fetch", "--quiet", "--prune", "origin")
    if not (unpushed := git(cwd, "rev-list", "HEAD", "--not", "--remotes=origin").stdout.split()):
        return None
    head = git(cwd, "rev-parse", "HEAD").stdout.strip()
    if head in {line.split("\t")[0] for line in git(cwd, "ls-remote", "origin").stdout.splitlines()}:
        return None
    oldest = git(cwd, "log", "-1", "--format=%h %s", unpushed[-1]).stdout.strip()
    commits = count(len(unpushed), "commit")
    return f"{commits} of HEAD, the oldest `{oldest}`, lie on no branch of origin, and no ref there is HEAD"


def work_only_here(top: pathlib.Path) -> list[str]:
    """Return what of the checkout at its top level exists there and not on origin.

    Raises CheckoutUnreadError when git cannot show it.
    """
    found: list[str] = []
    if paths := git(top, "status", "--porcelain").stdout.splitlines():
        found.append(f"`git status` lists {count(len(paths), 'path')}, such as `{paths[0].strip()}`")
    if commits := commits_only_here(top):
        found.append(commits)
    return found


def block(reason: str) -> dict[str, object]:
    """Return the output that sends the message back to the agent with the reason."""
    return {"decision": "block", "reason": reason}


def checkout_problem(cwd: pathlib.Path) -> str | None:
    """Return why the checkout around the directory cannot go with the session, or None when it can or there is none."""
    try:
        top = checkout_around(cwd)
        left = work_only_here(top) if top else []
    except CheckoutUnreadError as error:
        return f"The hook cannot show that the checkout around {cwd} holds nothing that origin lacks, since {error}."
    return f"The checkout at {top} holds work that origin lacks: {'; '.join(left)}." if left else None


def lead_answer(message: str, running: list[str], cwd: pathlib.Path) -> dict[str, object] | None:
    """Return the output at the end of a turn of the lead, or None to let the turn end."""
    before, _, last = message.rstrip().rpartition("\n")
    status = status_of(last)
    problems: list[str] = []
    if status is None:
        problems.append("Its last line is no status marker alone.")
    if holds_a_marker(before):
        problems.append("It holds a status marker before its last line.")
    if running and status is not None and status is not Status.RUNNING:
        problems.append(f"It ends with {status.value}, while something that the session started still runs.")
    if not running and status is Status.RUNNING:
        problems.append(f"It ends with {Status.RUNNING.value}, while nothing that the session started still runs.")
    if not running and status is Status.COMPLETE and (problem := checkout_problem(cwd)):
        problems.append(f"It ends with {Status.COMPLETE.value}. {problem}")
    if not problems:
        return None
    if running:
        way = (
            f"This still runs: {'; '.join(running)}. Write the whole message again, say in it what still runs, "
            f"and end it with this line alone: {Status.RUNNING.value}"
        )
    else:
        way = (
            f"Write the whole message again and end it with one of these lines alone: {Status.YOUR_MOVE.value} "
            "when progress needs the operator, saying what you need, or "
            f"{Status.COMPLETE.value} when nothing is left for you to do and nothing exists only in the checkout. "
            f"When unsure, end with {Status.YOUR_MOVE.value}."
        )
    return block(f"The message cannot end the turn. {' '.join(problems)} {way} Put no marker anywhere else.")


def report_answer(message: str) -> dict[str, object] | None:
    """Return the output at the end of a subagent, or None to let its report go to the lead."""
    if not holds_a_marker(message):
        return None
    reason = (
        "A subagent's report carries no status marker, since the markers say where the lead's session stands. "
        "Write the report again without ⏳, 🔔 and 🏁, and change nothing else."
    )
    return block(reason)


def answer(hook_input: dict[str, object]) -> dict[str, object] | None:
    """Return the hook's output at the end of a turn of the lead or of a subagent, or None to let it end."""
    message = str(hook_input.get("last_assistant_message", ""))
    event = hook_input.get("hook_event_name")
    if event == "SubagentStop":
        return report_answer(message)
    if event == "Stop":
        return lead_answer(message, still_running(hook_input), pathlib.Path(str(hook_input.get("cwd", "."))))
    sys.exit(f"turn-ends-with-a-status-marker.py: it runs at Stop and SubagentStop, not at {event}")


def main() -> None:
    """Read the hook input on stdin and print the output, if any."""
    output = answer(json_object(t.cast("object", json.load(sys.stdin)), "the hook input"))
    if output is not None:
        json.dump(output, sys.stdout)


if __name__ == "__main__":
    main()
