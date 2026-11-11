#!/usr/bin/env python3
"""Propose, run and record a live mutation, for build:live-mutation.

    live-mutation.py propose <name> --derive <cmd> --show <cmd> --run <cmd> [--check <check>=<cmd>]...
    live-mutation.py demonstrate <name> <check> <cmd>
    live-mutation.py run <name> <digest> --go-ahead <the owner's words>
    live-mutation.py record <name> [--session <id>]

A proposal is the directory tmp/live-mutation/<session>/<name>/ at the root of
the repository, where <session> is CLAUDE_CODE_SESSION_ID, so that a later
session never finds a proposal it did not show to run. Each command is one line
of sh, run from the root of the repository with LIVE_MUTATION_INPUTS naming the
directory of the proposal's frozen inputs: the derive command writes them, the
show command prints what the owner reads, and the run command executes them.
The digest covers the commands, the checks, every input and the rendering, so a
go-ahead that names it names exactly what the owner read.

`run` refuses a proposal of another session, another digest, inputs that
changed, a rendering that live state no longer gives, and a second run. It
derives and renders again before it runs, because OpenTofu refuses a saved plan
whose state changed but not one whose live resources drifted. `record` writes
the action record as Markdown comments, and refuses one in which a check never
failed, since a check that cannot fail is no evidence.

Imports the standard library only, because the baseline promises a shipped
script the interpreter and nothing else.
"""

import argparse
import collections.abc as ct
import dataclasses
import datetime as dt
import difflib
import enum
import hashlib
import json
import os
import pathlib
import re
import shutil
import signal
import subprocess
import sys
import typing as t

# The commands are lines of sh that the agent writes, with $LIVE_MUTATION_INPUTS
# for the shell to expand. /bin/sh, since a shipped script gets no sh on its PATH.
SHELL = "/bin/sh"
NAME = re.compile(r"[a-z0-9]+(?:-[a-z0-9]+)*")
SESSION = re.compile(r"[A-Za-z0-9_-]+")
DIGEST_LENGTH = 16
# GitHub refuses a comment body of more characters than this.
COMMENT_LIMIT = 65_536
TAIL_LINES = 40


class RefusalError(Exception):
    """A request the tool refuses. The message names the refusal and the way out."""


class Kind(enum.StrEnum):
    """What a line of the log records."""

    DERIVE = "derive"
    SHOW = "show"
    CHECK = "check"
    DEMONSTRATION = "demonstration"
    DRIFT = "drift"
    GO_AHEAD = "go-ahead"
    RUN = "run"


@dataclasses.dataclass(frozen=True, slots=True)
class Entry:
    """One line of the log: a command the tool ran, or the go-ahead that used the proposal up."""

    kind: Kind
    started: str
    ended: str
    status: int
    command: str = ""
    output: str = ""
    check: str = ""
    words: str = ""


@dataclasses.dataclass(frozen=True, slots=True)
class Commands:
    """What a proposal runs: each a line of sh, and the checks by name."""

    derive: str
    show: str
    run: str
    checks: dict[str, str]


@dataclasses.dataclass(frozen=True, slots=True)
class Proposal:
    """What the owner is shown. The digest covers everything but the name, the session and the time."""

    name: str
    session: str
    created: str
    commands: Commands
    inputs: dict[str, str]
    rendering: str
    digest: str


@dataclasses.dataclass(frozen=True, slots=True)
class Place:
    """The directory of one proposal and the files in it."""

    directory: pathlib.Path
    proposal: pathlib.Path
    rendering: pathlib.Path
    inputs: pathlib.Path
    outputs: pathlib.Path
    log: pathlib.Path
    drift: pathlib.Path


def place_at(directory: pathlib.Path) -> Place:
    """Return the files of the proposal in the directory."""
    return Place(
        directory=directory,
        proposal=directory / "proposal.json",
        rendering=directory / "rendering.txt",
        inputs=directory / "inputs",
        outputs=directory / "outputs",
        log=directory / "log.jsonl",
        drift=directory / "drift",
    )


def now() -> str:
    """Return the time in UTC, to the second."""
    return dt.datetime.now(dt.UTC).strftime("%Y-%m-%dT%H:%M:%SZ")


def repository_root(start: pathlib.Path) -> pathlib.Path:
    """Return the nearest directory at or above start that holds .git, or start when none does."""
    for directory in (start, *start.parents):
        if (directory / ".git").exists():
            return directory
    return start


def session_of(environ: ct.Mapping[str, str]) -> str:
    """Return the session that a proposal belongs to. Raises RefusalError outside a Claude Code session."""
    session = environ.get("CLAUDE_CODE_SESSION_ID", "")
    if not SESSION.fullmatch(session):
        message = (
            "no-conversation: CLAUDE_CODE_SESSION_ID holds no session ID,"
            " and a proposal belongs to the conversation that showed it to the owner"
        )
        raise RefusalError(message)
    return session


def sessions_root(root: pathlib.Path) -> pathlib.Path:
    """Return the directory that holds one directory per session."""
    return root / "tmp" / "live-mutation"


def place_of(root: pathlib.Path, session: str, name: str) -> Place:
    """Return where a proposal of the session lives. Raises RefusalError for a name that is no kebab-case name."""
    if not NAME.fullmatch(name):
        raise RefusalError(f"bad-name: {name!r} is not a kebab-case name such as org-import")
    return place_at(sessions_root(root) / session / name)


def fields_of(text: str) -> dict[str, object]:
    """Parse a JSON object. Raises RefusalError for any other JSON."""
    data = t.cast("object", json.loads(text))
    if not isinstance(data, dict):
        raise RefusalError("corrupt: a file of the proposal holds no JSON object")
    return t.cast("dict[str, object]", data)


def text_of(fields: ct.Mapping[str, object], key: str) -> str:
    """Return a field as a string. Raises RefusalError when it is none."""
    value = fields.get(key)
    if not isinstance(value, str):
        raise RefusalError(f"corrupt: {key} is missing or no string")
    return value


def texts_of(fields: ct.Mapping[str, object], key: str) -> dict[str, str]:
    """Return a field as a mapping of strings. Raises RefusalError when it is none."""
    value = fields.get(key)
    if not isinstance(value, dict):
        raise RefusalError(f"corrupt: {key} is missing or no object")
    pairs = t.cast("dict[object, object]", value)
    texts = {k: v for k, v in pairs.items() if isinstance(k, str) and isinstance(v, str)}
    if len(texts) != len(pairs):
        raise RefusalError(f"corrupt: {key} holds a value that is no string")
    return texts


def load(place: Place) -> Proposal:
    """Read a proposal from its directory."""
    fields = fields_of(place.proposal.read_text(encoding="utf-8"))
    commands = Commands(
        derive=text_of(fields, "derive"),
        show=text_of(fields, "show"),
        run=text_of(fields, "run"),
        checks=texts_of(fields, "checks"),
    )
    return Proposal(
        name=text_of(fields, "name"),
        session=text_of(fields, "session"),
        created=text_of(fields, "created"),
        commands=commands,
        inputs=texts_of(fields, "inputs"),
        rendering=text_of(fields, "rendering"),
        digest=text_of(fields, "digest"),
    )


def save(place: Place, proposal: Proposal) -> None:
    """Write a proposal into its directory, its commands beside its other fields."""
    fields = {
        "name": proposal.name,
        "session": proposal.session,
        "created": proposal.created,
        "derive": proposal.commands.derive,
        "show": proposal.commands.show,
        "run": proposal.commands.run,
        "checks": proposal.commands.checks,
        "inputs": proposal.inputs,
        "rendering": proposal.rendering,
        "digest": proposal.digest,
    }
    _ = place.proposal.write_text(json.dumps(fields, indent=2) + "\n", encoding="utf-8")


def read_log(place: Place) -> list[Entry]:
    """Return the lines of the log, oldest first."""
    if not place.log.exists():
        return []
    entries: list[Entry] = []
    for line in place.log.read_text(encoding="utf-8").splitlines():
        fields = fields_of(line)
        status = fields.get("status")
        if not isinstance(status, int):
            raise RefusalError(f"corrupt: a line of {place.log} has no status")
        entries.append(
            Entry(
                kind=Kind(text_of(fields, "kind")),
                started=text_of(fields, "started"),
                ended=text_of(fields, "ended"),
                status=status,
                command=text_of(fields, "command"),
                output=text_of(fields, "output"),
                check=text_of(fields, "check"),
                words=text_of(fields, "words"),
            )
        )
    return entries


def append(place: Place, entry: Entry) -> None:
    """Add a line to the log."""
    with place.log.open("a", encoding="utf-8") as file:
        _ = file.write(json.dumps(dataclasses.asdict(entry)) + "\n")


def output_name(place: Place, kind: Kind, check: str = "") -> str:
    """Return the name of the next output file, numbered after the lines of the log."""
    number = len(read_log(place)) + 1
    return f"{number:03d}-{kind}{'-' + check if check else ''}.txt"


def execute(command: str, root: pathlib.Path, inputs: pathlib.Path, out: pathlib.Path, err: pathlib.Path | None) -> int:
    """Run a line of sh from the root with LIVE_MUTATION_INPUTS set, and return its exit status.

    Standard error goes to err, or after standard output into out when err is
    None. An interrupt is passed on to the command as SIGINT and the command is
    waited for, never killed: OpenTofu stops an apply cleanly on SIGINT, and a
    kill can leave its state locked and half written.
    """
    out.parent.mkdir(parents=True, exist_ok=True)
    environment = {**os.environ, "LIVE_MUTATION_INPUTS": str(inputs)}
    with out.open("wb") as stdout, (err or out).open("ab") as errors:
        stderr = subprocess.STDOUT if err is None else errors
        process = subprocess.Popen([SHELL, "-c", command], cwd=root, env=environment, stdout=stdout, stderr=stderr)
        try:
            return process.wait()
        except KeyboardInterrupt:
            process.send_signal(signal.SIGINT)
            return process.wait()


def step(root: pathlib.Path, place: Place, kind: Kind, command: str, check: str = "") -> Entry:
    """Run one command of a proposal against its inputs, log it, and return its line of the log."""
    output = output_name(place, kind, check)
    started = now()
    status = execute(command, root, place.inputs, place.outputs / output, None)
    entry = Entry(kind=kind, started=started, ended=now(), status=status, command=command, output=output, check=check)
    append(place, entry)
    return entry


def digests_of(directory: pathlib.Path) -> dict[str, str]:
    """Return the SHA-256 of every file under the directory, by its path relative to it."""
    files = sorted(path for path in directory.rglob("*") if path.is_file())
    return {path.relative_to(directory).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest() for path in files}


def digest_of(commands: Commands, inputs: ct.Mapping[str, str], rendering: str) -> str:
    """Return the digest that a go-ahead names."""
    covered = {**dataclasses.asdict(commands), "inputs": dict(inputs), "rendering": rendering}
    return hashlib.sha256(json.dumps(covered, sort_keys=True).encode()).hexdigest()[:DIGEST_LENGTH]


def derive_and_show(root: pathlib.Path, directory: pathlib.Path, commands: Commands) -> tuple[int, str]:
    """Derive inputs into the directory and render them. Returns the first status that is not 0, and the rendering."""
    if directory.exists():
        shutil.rmtree(directory)
    inputs = directory / "inputs"
    inputs.mkdir(parents=True)
    log = directory / "derive-and-show.txt"
    status = execute(commands.derive, root, inputs, log, None)
    if status != 0:
        return status, ""
    rendering = directory / "rendering.txt"
    status = execute(commands.show, root, inputs, rendering, log)
    return status, rendering.read_text(encoding="utf-8", errors="replace")


def fence(text: str) -> str:
    """Return a code fence longer than every run of backticks in the text."""
    return "`" * max([3, *(match.end() - match.start() + 1 for match in re.finditer(r"`+", text))])


def outcome(status: int) -> str:
    """Return how a check or a command ended, in words."""
    return "passes" if status == 0 else f"fails ({status})"


def outcomes(entries: ct.Iterable[Entry], kind: Kind, check: str) -> str:
    """Return how each run of a kind of one check ended, in words, or none."""
    found = [outcome(entry.status) for entry in entries if entry.kind is kind and entry.check == check]
    return ", ".join(found) or "none"


def consumed(entries: ct.Sequence[Entry]) -> Entry | None:
    """Return the go-ahead that used the proposal up, if one did."""
    return next((entry for entry in entries if entry.kind is Kind.GO_AHEAD), None)


def propose(root: pathlib.Path, session: str, name: str, commands: Commands) -> str:
    """Derive, render and check a proposal of this session, and return the text that shows it to the owner."""
    place = place_of(root, session, name)
    for check in commands.checks:
        if not NAME.fullmatch(check):
            raise RefusalError(f"bad-name: the check {check!r} is not a kebab-case name such as no-changes")
    if place.directory.exists():
        used = consumed(read_log(place))
        if used is not None:
            raise RefusalError(f"already-ran: proposal {name} ran at {used.started}; propose under a new name")
        shutil.rmtree(place.directory)
    place.outputs.mkdir(parents=True)
    place.inputs.mkdir()
    derived = step(root, place, Kind.DERIVE, commands.derive)
    if derived.status != 0:
        raise RefusalError(f"derive-failed: derive exited {derived.status}; see {place.outputs / derived.output}")
    started = now()
    output = output_name(place, Kind.SHOW)
    status = execute(commands.show, root, place.inputs, place.rendering, place.outputs / output)
    append(place, Entry(Kind.SHOW, started, now(), status, commands.show, output))
    if status != 0:
        raise RefusalError(f"show-failed: show exited {status}; see {place.outputs / output}")
    checked = [step(root, place, Kind.CHECK, command, check) for check, command in commands.checks.items()]
    rendering = place.rendering.read_text(encoding="utf-8", errors="replace")
    inputs = digests_of(place.inputs)
    rendering_digest = hashlib.sha256(place.rendering.read_bytes()).hexdigest()
    digest = digest_of(commands, inputs, rendering_digest)
    save(place, Proposal(name, session, now(), commands, inputs, rendering_digest, digest))
    checks = [f"- `{entry.check}` {outcome(entry.status)}: `{entry.command}`" for entry in checked] or ["- none"]
    lines = [
        f"Proposal `{name}` at digest `{digest}`, shown in session `{session}`.",
        "",
        "The command that runs on a go-ahead:",
        "",
        f"{fence(commands.run)}sh",
        commands.run,
        fence(commands.run),
        "",
        f"The rendering, also in {place.rendering}:",
        "",
        f"{fence(rendering)}text",
        rendering.rstrip("\n"),
        fence(rendering),
        "",
        "The checks, run once before any go-ahead:",
        "",
        *checks,
        "",
        "On a go-ahead for this digest, in this conversation:",
        "",
        "```sh",
        f"live-mutation.py run {name} {digest} --go-ahead '<the owner's words>'",
        "```",
    ]
    return "\n".join(lines) + "\n"


def find(root: pathlib.Path, session: str, name: str) -> Place:
    """Return the place of a proposal of this session. Raises RefusalError when this session showed none by the name."""
    place = place_of(root, session, name)
    if place.proposal.exists():
        return place
    others = sorted(
        directory.name
        for directory in sessions_root(root).glob("*")
        if directory.name != session and (directory / name / "proposal.json").exists()
    )
    elsewhere = f" It was shown in session {', '.join(others)}." if others else ""
    message = (
        f"not-in-this-conversation: this conversation (session {session}) showed no proposal {name}.{elsewhere}"
        " A proposal runs only in the conversation that showed it: propose it again,"
        " show it to the owner and ask for a go-ahead."
    )
    raise RefusalError(message)


def demonstrate(root: pathlib.Path, session: str, name: str, check: str, command: str) -> tuple[int, str]:
    """Run a check's command against a state where its property does not hold, and log it."""
    place = find(root, session, name)
    if check not in load(place).commands.checks:
        raise RefusalError(f"no-such-check: proposal {name} has no check {check}")
    entry = step(root, place, Kind.DEMONSTRATION, command, check)
    if entry.status == 0:
        return 1, f"The demonstration of {check} passed, so it shows nothing; see {place.outputs / entry.output}\n"
    return 0, f"The demonstration of {check} {outcome(entry.status)}, as a check must where its property fails.\n"


def drift_check(root: pathlib.Path, place: Place, proposal: Proposal) -> None:
    """Derive and render again from live state, and log it. Raises RefusalError unless it gives the same rendering."""
    started = now()
    status, rendering = derive_and_show(root, place.drift, proposal.commands)
    approved = place.rendering.read_text(encoding="utf-8", errors="replace")
    lines = difflib.unified_diff(approved.splitlines(True), rendering.splitlines(True), "approved", "live now")  # noqa: FBT003  # keepends is positional only
    diff = "".join(lines)
    output = output_name(place, Kind.DRIFT)
    _ = (place.outputs / output).write_text(diff or "The rendering derived again equals the approved one.\n")
    append(place, Entry(Kind.DRIFT, started, now(), status or int(bool(diff)), "derive and show again", output))
    if status != 0:
        raise RefusalError(f"drift-check-failed: deriving again exited {status}; see {place.drift}")
    if diff:
        raise RefusalError(f"drifted: live state no longer gives the rendering the owner approved\n{diff}")


def run(root: pathlib.Path, session: str, name: str, digest: str, words: str) -> tuple[int, str]:
    """Run a proposal of this session once, on a go-ahead for its digest, then check its result."""
    place = find(root, session, name)
    proposal = load(place)
    if digest != proposal.digest:
        message = (
            f"digest-mismatch: the go-ahead names {digest}, and proposal {name} is at {proposal.digest};"
            " show the owner the proposal at that digest and ask again"
        )
        raise RefusalError(message)
    used = consumed(read_log(place))
    if used is not None:
        message = (
            f"already-ran: proposal {name} ran on the go-ahead {used.words!r} at {used.started};"
            " a go-ahead covers one run, so propose again from the new live state"
        )
        raise RefusalError(message)
    current = digests_of(place.inputs)
    changed = sorted(path for path in {*proposal.inputs, *current} if proposal.inputs.get(path) != current.get(path))
    if changed:
        raise RefusalError(f"inputs-changed: {', '.join(changed)} changed since the proposal; propose again")
    drift_check(root, place, proposal)
    output = output_name(place, Kind.RUN)
    append(place, Entry(Kind.GO_AHEAD, now(), now(), 0, output=output, words=words))
    started = now()
    path = place.outputs / output
    status = execute(proposal.commands.run, root, place.inputs, path, None)
    append(place, Entry(Kind.RUN, started, now(), status, proposal.commands.run, output))
    after = [step(root, place, Kind.CHECK, command, check) for check, command in proposal.commands.checks.items()]
    lines = [
        f"The run {outcome(status)}; its whole output is in {path}. Its last lines:",
        "",
        "```text",
        *path.read_text(encoding="utf-8", errors="replace").splitlines()[-TAIL_LINES:],
        "```",
        "",
        "The checks after the run:",
        "",
        *[f"- `{entry.check}` {outcome(entry.status)}" for entry in after],
        "",
        f"Write the action record now: live-mutation.py record {name}",
    ]
    good = status == 0 and all(entry.status == 0 for entry in after)
    return (0 if good else 1), "\n".join(lines) + "\n"


def details(summary: str, path: pathlib.Path) -> str:
    """Return a file as a collapsed block of Markdown, cut in the middle when it would fill half a comment."""
    text = path.read_text(encoding="utf-8", errors="replace") if path.exists() else "(no output)\n"
    half = COMMENT_LIMIT // 4
    if len(text) > 2 * half:
        text = f"{text[:half]}\n[{len(text) - 2 * half} characters cut; the whole output is in {path}]\n{text[-half:]}"
    marker = fence(text)
    return f"<details><summary>{summary}</summary>\n\n{marker}text\n{text.rstrip()}\n{marker}\n\n</details>\n\n"


def record(root: pathlib.Path, session: str, name: str) -> list[pathlib.Path]:
    """Write the action record of a run as Markdown comments that GitHub accepts, and return their paths."""
    place = place_of(root, session, name)
    if not place.proposal.exists():
        raise RefusalError(f"not-found: session {session} holds no proposal {name}")
    proposal = load(place)
    entries = read_log(place)
    go_ahead = consumed(entries)
    if go_ahead is None:
        raise RefusalError(f"not-run: proposal {name} has had no go-ahead, so there is no run to record")
    for check in proposal.commands.checks:
        if all(entry.status == 0 for entry in entries if entry.check == check):
            message = (
                f"check-never-failed: the check {check} never failed, so it is no evidence;"
                f" run live-mutation.py demonstrate {name} {check} '<cmd>' where its property does not hold"
            )
            raise RefusalError(message)
    position = entries.index(go_ahead)
    before, after = entries[:position], entries[position:]
    ran = next((entry for entry in after if entry.kind is Kind.RUN), None)
    drift = next(entry for entry in reversed(before) if entry.kind is Kind.DRIFT)
    if ran is None:
        finished = f"- The run started at {go_ahead.started} and has no end in the log."
    else:
        finished = f"- The run {outcome(ran.status)}, from {ran.started} to {ran.ended}."
    rows = [
        " | ".join(
            [
                f"| `{check}`",
                outcomes(before, Kind.CHECK, check),
                outcomes(after, Kind.CHECK, check),
                f"{outcomes(entries, Kind.DEMONSTRATION, check)} |",
            ]
        )
        for check in proposal.commands.checks
    ]
    header = [
        f"## Action record of `{name}`",
        "",
        f"- Proposal digest `{proposal.digest}`, shown at {proposal.created} in session `{session}`.",
        f"- Go-ahead at {go_ahead.started}, in the owner's words: {json.dumps(go_ahead.words)}",
        f"- Drift check at {drift.ended}: the rendering derived again equals the approved one.",
        finished,
        "",
        "| Check | Before the run | After the run | Demonstrations |",
        "| --- | --- | --- | --- |",
        *rows,
        "",
        f"{fence(proposal.commands.run)}sh",
        proposal.commands.run,
        fence(proposal.commands.run),
        "",
        "",
    ]
    checks = [
        details(
            f"{entry.kind} {entry.check}, {'after' if index > position else 'before'} the run: {outcome(entry.status)}",
            place.outputs / entry.output,
        )
        for index, entry in enumerate(entries)
        if entry.kind in {Kind.CHECK, Kind.DEMONSTRATION}
    ]
    blocks = [
        details("The rendering the owner approved", place.rendering),
        details("The output of the run", place.outputs / go_ahead.output),
        *checks,
    ]
    parts = ["\n".join(header)]
    for block in blocks:
        if len(parts[-1]) + len(block) > COMMENT_LIMIT:
            parts.append(f"## Action record of `{name}`, continued\n\n")
        parts[-1] += block
    written: list[pathlib.Path] = []
    for number, part in enumerate(parts, 1):
        path = place.directory / f"record-{number}.md"
        _ = path.write_text(part, encoding="utf-8")
        written.append(path)
    return written


def check_pair(text: str) -> tuple[str, str]:
    """Parse a --check value, <check>=<cmd>. Raises argparse.ArgumentTypeError for one without a name."""
    check, separator, command = text.partition("=")
    if not separator or not check or not command:
        raise argparse.ArgumentTypeError(f"a check is <name>=<command>: {text!r}")
    return check, command


def parser() -> argparse.ArgumentParser:
    """Return the parser of the command line."""
    parsing = argparse.ArgumentParser(prog="live-mutation.py", description="Propose, run and record a live mutation.")
    commands = parsing.add_subparsers(dest="command", required=True)
    proposing = commands.add_parser("propose", help="derive, render and check a proposal")
    _ = proposing.add_argument("name")
    _ = proposing.add_argument("--derive", required=True, help="writes the frozen inputs into $LIVE_MUTATION_INPUTS")
    _ = proposing.add_argument("--show", required=True, help="prints what the owner reads")
    _ = proposing.add_argument("--run", required=True, help="executes the frozen inputs")
    _ = proposing.add_argument("--check", type=check_pair, action="append", default=[], metavar="CHECK=CMD")
    demonstrating = commands.add_parser("demonstrate", help="run a check where its property does not hold")
    _ = demonstrating.add_argument("name")
    _ = demonstrating.add_argument("check")
    _ = demonstrating.add_argument("cmd")
    running = commands.add_parser("run", help="run a proposal of this conversation on a go-ahead")
    _ = running.add_argument("name")
    _ = running.add_argument("digest")
    _ = running.add_argument("--go-ahead", required=True, help="the owner's words")
    recording = commands.add_parser("record", help="write the action record of a run")
    _ = recording.add_argument("name")
    _ = recording.add_argument("--session", help="the session that ran it, when not this one")
    return parsing


def main(arguments: ct.Sequence[str], environ: ct.Mapping[str, str]) -> int:
    """Run the command that the arguments name. Returns the exit status."""
    parsed = parser().parse_args(arguments)
    # A namespace types every value as Any; argparse has run each given one through its type.
    command = t.cast("str", parsed.command)
    name = t.cast("str", parsed.name)
    root = repository_root(pathlib.Path.cwd())
    status = 0
    try:
        if command == "record":
            given = t.cast("str | None", parsed.session)
            session = given if given is not None and SESSION.fullmatch(given) else session_of(environ)
            text = "".join(f"{path}\n" for path in record(root, session, name))
        elif command == "propose":
            pairs = t.cast("list[tuple[str, str]]", parsed.check)
            derive, show, executes = t.cast("str", parsed.derive), t.cast("str", parsed.show), t.cast("str", parsed.run)
            text = propose(root, session_of(environ), name, Commands(derive, show, executes, dict(pairs)))
        elif command == "demonstrate":
            check, cmd = t.cast("str", parsed.check), t.cast("str", parsed.cmd)
            status, text = demonstrate(root, session_of(environ), name, check, cmd)
        else:
            digest, words = t.cast("str", parsed.digest), t.cast("str", parsed.go_ahead)
            status, text = run(root, session_of(environ), name, digest, words)
    except RefusalError as refusal:
        print(f"live-mutation.py: {refusal}", file=sys.stderr)
        return 1
    print(text, end="")
    return status


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:], os.environ))
