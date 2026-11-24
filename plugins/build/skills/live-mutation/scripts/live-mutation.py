#!/usr/bin/env python3
"""Propose, run and record a live mutation, for build:live-mutation.

    live-mutation.py propose <name> --derive <cmd> --show <cmd> --run <cmd> [--check <check>=<cmd>]...
    live-mutation.py propose <name> --opentofu <root> [--destroy] [--target <address>]... [--check <check>=<cmd>]...
    live-mutation.py demonstrate <name> <check> <cmd> [--session <id>]
    live-mutation.py run <name> <digest> [--go-ahead <the owner's words>]
    live-mutation.py record <name> [--session <id>]
    live-mutation.py posted <name> <url>... [--session <id>]
    live-mutation.py pending

A proposal is the directory tmp/live-mutation/<session>/<name>/ at the root of
the repository, where <session> is CLAUDE_CODE_SESSION_ID. Each command is one
line of sh, run from the root of the repository with LIVE_MUTATION_INPUTS naming
the directory of the proposal's frozen inputs: the derive command writes them,
the show command prints what the owner reads, and the run command executes
them. The digest covers the commands, the checks, every input and the
rendering.

The OpenTofu form writes those commands for a saved plan of one root module, a
directory relative to the root of the repository, and adds the check
no-changes. It reads the JSON of the plan and of the root module's state into
memory only, since both hold sensitive values in plain text. tofu prints such a
value where it loses the mark, so the tool hides each value that the plan or the
state marks sensitive in all that a command prints before it writes it, and
reads the state again after the apply, which may generate one. A proposal or a
run that would show one stops before the run. With --target, the plan and
no-changes take -target for each address, and the proposal waits. Before any
command runs, the tool reads each command that the agent wrote with the reader
of the plugin's OpenTofu hook, opentofu_commands.py, and refuses one that names
tofu and that it cannot read.
The generic form runs no OpenTofu command that prints values and keeps no saved
plan among its inputs, and a check or a demonstration of the OpenTofu form
prints values of the form's own root module alone. A proposal of that form runs without a go-ahead
when no resource change of its plan does more than create, read or update and
none imports, its configuration holds no provisioner, no TF_CLI_ARGS variable
and no TF_DATA_DIR is set, the root module's workspace is default, HEAD was on
a branch other than the default branch of origin, and a rule file under
.claude/rules/, as unprotected_roots.py reads it at that default branch, lists
the root module or a directory above it under unprotected-roots in its
frontmatter. Every other proposal runs only on the owner's go-ahead.

`run` refuses a proposal of another session, another digest, a second run,
inputs that changed, a go-ahead of no words, a run without a go-ahead that the
proposal was shown to need or that the plan and the rule files read again do
not allow, and a rendering that live state no longer gives or that shows a
sensitive value. It derives and
renders again before it runs, because OpenTofu refuses a saved plan whose state
changed but not one whose live resources drifted. `record` writes the action record as
Markdown comments, and refuses one in which a check never failed. `posted`
logs the URLs of those comments once they are posted, and `pending` lists the
runs of the current branch, in every session of this working tree, whose
record has no such line yet.
"""

import argparse
import collections.abc as ct
import contextlib
import dataclasses
import datetime as dt
import difflib
import enum
import fcntl
import hashlib
import json
import os
import pathlib
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
import typing as t
import zipfile

import unprotected_roots

HOOKS = pathlib.Path(__file__).resolve().parents[3] / "hooks"
if str(HOOKS) not in sys.path:
    sys.path.append(str(HOOKS))

import opentofu_commands  # noqa: E402
import shell_syntax  # noqa: E402

KEY = f"{unprotected_roots.UNPROTECTED_ROOTS}:"

SHELL = "/bin/sh"
NAME = re.compile(r"[a-z0-9]+(?:-[a-z0-9]+)*")
SESSION = re.compile(r"[A-Za-z0-9_-]+")
DIGEST_LENGTH = 16
# GitHub refuses a comment body of more characters than this.
COMMENT_LIMIT = 65_536
TAIL_LINES = 40
TOOL = pathlib.Path(__file__).resolve()

NO_CHANGES = "no-changes"
PLAN = '"$LIVE_MUTATION_INPUTS/plan"'
HIDDEN = "(sensitive value hidden by live-mutation.py)"
GO_ESCAPES = {
    "\a": r"\a",
    "\b": r"\b",
    "\f": r"\f",
    "\n": r"\n",
    "\r": r"\r",
    "\t": r"\t",
    "\v": r"\v",
    "\\": r"\\",
    '"': r"\"",
}
GO_HEX_ESCAPED = frozenset(chr(code) for code in [*range(0x20), 0x7F])
BASIC_PLANE = range(0x10000)
DELETES_NOTHING = frozenset({"no-op", "create", "read", "update"})
GENERIC = "The proposal is of the generic form, and only the OpenTofu form runs without a go-ahead."
GO_AHEAD_WORDS = "'<the words of the owner>'"
QUOTING = r"Put the owner's words between the single quotes word for word, and write each `'` in them as `'\''`."
JUDGED = (
    "Run it without one only when you judge that the apply can be undone and that the plan reaches only the target"
    " that the rule names:"
)
URL = re.compile(r"https://\S+")
SHOWN_WAITING = (
    "The proposal was shown as waiting for the owner's go-ahead, and such a proposal never runs without one."
)
FIELDS_AN_OLDER_PROPOSAL_LACKS: ct.Mapping[str, object] = {
    "form": None,
    "route": {"kind": "go-ahead-needed", "reasons": [GENERIC]},
    "branch": None,
}
FIELDS_AN_OLDER_LOG_LINE_LACKS: ct.Mapping[str, object] = {"rule_file": "", "commit": "", "directory": "", "urls": []}
FIELDS_AN_OLDER_OPENTOFU_FORM_LACKS: ct.Mapping[str, object] = {"targets": []}
READS_ANOTHER_STATE = frozenset({"state", "var", "var-file"})
CHANGES_DIRECTORY = frozenset({"cd", "popd", "pushd"})
SETS_A_TF_VARIABLE = re.compile(r"(?<![A-Za-z0-9_])TF_[A-Za-z0-9_]*\+?=")
FROZEN_PLAN = frozenset({"$LIVE_MUTATION_INPUTS/plan", "${LIVE_MUTATION_INPUTS}/plan"})
SAVED_PLAN_MEMBER = "tfplan"
OPENTOFU_FORM = (
    "Propose an OpenTofu plan in the OpenTofu form, which hides what the plan and the state mark sensitive, and when"
    " the plan needs an argument that the form does not take, stop and tell the owner."
)
IN_THE_SHELL = "Read any other value of OpenTofu that you need in the shell, outside the proposal."
OWN_ROOT_ONLY = "Read the root module of the form alone there, and any other in the shell, outside the proposal."


class RefusalError(Exception):
    """A request the tool refuses. The message names the refusal and the way out."""


class UnreadRunError(Exception):
    """An OpenTofu run that an expansion hides part of from the tool. The message says which part, and why."""


class Kind(enum.StrEnum):
    """What a line of the log records."""

    DERIVE = "derive"
    SHOW = "show"
    CHECK = "check"
    DEMONSTRATION = "demonstration"
    DRIFT = "drift"
    GO_AHEAD = "go-ahead"
    NO_GO_AHEAD = "no-go-ahead"
    RUN = "run"
    POSTED = "posted"


USES_UP = frozenset({Kind.GO_AHEAD, Kind.NO_GO_AHEAD})


@dataclasses.dataclass(frozen=True, slots=True)
class Entry:
    """One line of the log: a command the tool ran, what allowed the run, or where its action record was posted.

    A go-ahead line holds the owner's words. A no-go-ahead line holds the rule file, the commit it was read at and
    the directory it lists. Both name the output of the run. A posted line holds the URLs of the comments.
    """

    kind: Kind
    started: str
    ended: str
    status: int
    command: str = ""
    output: str = ""
    check: str = ""
    words: str = ""
    rule_file: str = ""
    commit: str = ""
    directory: str = ""
    urls: tuple[str, ...] = ()


@dataclasses.dataclass(frozen=True, slots=True)
class Commands:
    """What a proposal runs: each a line of sh, and the checks by name."""

    derive: str
    show: str
    run: str
    checks: dict[str, str]


@dataclasses.dataclass(frozen=True, slots=True)
class Generic:
    """The generic form of a proposal: the commands as the agent wrote them."""

    commands: Commands


@dataclasses.dataclass(frozen=True, slots=True)
class OpenTofu:
    """The OpenTofu form of a proposal: a saved plan of one root module, a directory relative to the repository.

    The form holds the resource addresses that the plan targets and the checks that the agent gave, never
    no-changes, and writes every command itself, so no stored command can differ from the commands that it runs.
    The plan and no-changes both take each target, so that no-changes judges the part of the root module that the
    plan changes.
    """

    root: str
    destroy: bool
    targets: tuple[str, ...]
    checks: dict[str, str]

    def tofu(self, arguments: str) -> str:
        """Return a line of sh that runs tofu in the root module."""
        return f"tofu -chdir={shlex.quote(self.root)} {arguments}"

    @property
    def commands(self) -> Commands:
        """Return the commands of the form, with the check no-changes before the given ones."""
        destroy = " -destroy" if self.destroy else ""
        narrowed = destroy + "".join(f" {shlex.quote(f'-target={target}')}" for target in self.targets)
        return Commands(
            derive=self.tofu(f"plan -no-color -input=false{narrowed} -out={PLAN}"),
            show=self.tofu(f"show -no-color {PLAN}"),
            run=self.tofu(f"apply -no-color -input=false {PLAN}"),
            checks={NO_CHANGES: self.tofu(f"plan -no-color -input=false{narrowed} -detailed-exitcode"), **self.checks},
        )

    def plan_json(self) -> str:
        """Return a line of sh that prints the frozen plan as JSON."""
        return self.tofu(f"show -json {PLAN}")


@dataclasses.dataclass(frozen=True, slots=True)
class NoGoAheadNeeded:
    """The route of a proposal that may run without a go-ahead: the rule file that lists its root module."""

    rule_file: str
    commit: str
    directory: str


@dataclasses.dataclass(frozen=True, slots=True)
class GoAheadNeeded:
    """The route of a proposal that runs only on the owner's go-ahead, with each reason as a sentence."""

    reasons: tuple[str, ...]


type Form = Generic | OpenTofu
type Route = NoGoAheadNeeded | GoAheadNeeded
type Secrets = frozenset[str]


@dataclasses.dataclass(frozen=True, slots=True)
class Proposal:
    """What the owner is shown, and the route that the tool found when it proposed it.

    The digest covers the commands of the form, the inputs and the rendering. The branch is None when HEAD was
    detached.
    """

    name: str
    session: str
    created: str
    form: Form
    inputs: dict[str, str]
    rendering: str
    digest: str
    route: Route
    branch: str | None


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


@dataclasses.dataclass(frozen=True, slots=True, order=True)
class Waiting:
    """A run whose action record is not posted, ordered by when it ran."""

    ran: str
    session: str
    name: str
    gated: bool


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


def json_object(value: object) -> dict[str, object] | None:
    """Return a JSON value as an object, or None when it is none."""
    return t.cast("dict[str, object]", value) if isinstance(value, dict) else None


def fields_of(text: str) -> dict[str, object]:
    """Parse a JSON object. Raises RefusalError for any other JSON."""
    data = json_object(t.cast("object", json.loads(text)))
    if data is None:
        raise RefusalError("corrupt: a file of the proposal holds no JSON object")
    return data


def text_of(fields: ct.Mapping[str, object], key: str) -> str:
    """Return a field as a string. Raises RefusalError when it is none."""
    value = fields.get(key)
    if not isinstance(value, str):
        raise RefusalError(f"corrupt: {key} is missing or no string")
    return value


def texts_of(fields: ct.Mapping[str, object], key: str) -> dict[str, str]:
    """Return a field as a mapping of strings. Raises RefusalError when it is none."""
    value = json_object(fields.get(key))
    if value is None:
        raise RefusalError(f"corrupt: {key} is missing or no object")
    texts = {k: v for k, v in value.items() if isinstance(v, str)}
    if len(texts) != len(value):
        raise RefusalError(f"corrupt: {key} holds a value that is no string")
    return texts


def strings_of(fields: ct.Mapping[str, object], key: str) -> tuple[str, ...]:
    """Return a field as a list of strings. Raises RefusalError when it is none."""
    value = fields.get(key)
    if not isinstance(value, list):
        raise RefusalError(f"corrupt: {key} is missing or no list")
    items = t.cast("list[object]", value)
    strings = tuple(item for item in items if isinstance(item, str))
    if len(strings) != len(items):
        raise RefusalError(f"corrupt: {key} holds an item that is no string")
    return strings


def form_of(fields: ct.Mapping[str, object]) -> Form:
    """Parse the form of a proposal. Raises RefusalError for a form that is neither of the two.

    The generic form keeps its commands beside the other fields, and the OpenTofu form keeps under form the root
    module and the checks the agent gave.
    """
    if fields["form"] is None:
        derive, show, executes = (text_of(fields, field) for field in ("derive", "show", "run"))
        return Generic(Commands(derive, show, executes, texts_of(fields, "checks")))
    form = json_object(fields["form"])
    destroy = None if form is None else form.get("destroy")
    if form is None or text_of(form, "kind") != "opentofu" or not isinstance(destroy, bool):
        raise RefusalError("corrupt: form is neither missing nor an OpenTofu form")
    checks = texts_of(form, "checks")
    if NO_CHANGES in checks:
        raise RefusalError(f"corrupt: the OpenTofu form holds a check of its own named {NO_CHANGES}")
    targets = strings_of({**FIELDS_AN_OLDER_OPENTOFU_FORM_LACKS, **form}, "targets")
    return OpenTofu(root=text_of(form, "root"), destroy=destroy, targets=targets, checks=checks)


def form_fields(form: Form) -> dict[str, object]:
    """Return a form as the fields of a proposal that form_of parses."""
    match form:
        case Generic(commands=commands):
            return dataclasses.asdict(commands)
        case OpenTofu(root=root, destroy=destroy, targets=targets, checks=checks):
            fields = {"kind": "opentofu", "root": root, "destroy": destroy, "targets": list(targets), "checks": checks}
            return {"form": fields}


def route_from(value: object) -> Route:
    """Parse the route of a proposal. Raises RefusalError for a value that is no route."""
    fields = json_object(value)
    kind = None if fields is None else fields.get("kind")
    if fields is not None and kind == "no-go-ahead-needed":
        return NoGoAheadNeeded(text_of(fields, "rule_file"), text_of(fields, "commit"), text_of(fields, "directory"))
    if fields is not None and kind == "go-ahead-needed":
        return GoAheadNeeded(strings_of(fields, "reasons"))
    raise RefusalError("corrupt: route is no route")


def route_fields(route: Route) -> dict[str, object]:
    """Return a route as the JSON object that route_from parses."""
    kind = "no-go-ahead-needed" if isinstance(route, NoGoAheadNeeded) else "go-ahead-needed"
    return {"kind": kind, **dataclasses.asdict(route)}


def load(place: Place) -> Proposal:
    """Read a proposal from its directory.

    Raises RefusalError (corrupt) for a proposal whose file's JSON is no object or lacks a field, or whose digest is
    not the one that its commands, inputs and rendering give.
    """
    fields = {**FIELDS_AN_OLDER_PROPOSAL_LACKS, **fields_of(place.proposal.read_text(encoding="utf-8"))}
    branch = fields["branch"]
    if branch is not None and not isinstance(branch, str):
        raise RefusalError("corrupt: branch is neither null nor a string")
    proposal = Proposal(
        name=text_of(fields, "name"),
        session=text_of(fields, "session"),
        created=text_of(fields, "created"),
        form=form_of(fields),
        inputs=texts_of(fields, "inputs"),
        rendering=text_of(fields, "rendering"),
        digest=text_of(fields, "digest"),
        route=route_from(fields["route"]),
        branch=branch,
    )
    if digest_of(proposal.form.commands, proposal.inputs, proposal.rendering) != proposal.digest:
        message = (
            f"corrupt: the digest of proposal {proposal.name} is not the one its commands, inputs and rendering give"
        )
        raise RefusalError(message)
    return proposal


def save(place: Place, proposal: Proposal) -> None:
    """Write a proposal into its directory."""
    fields = {
        "name": proposal.name,
        "session": proposal.session,
        "created": proposal.created,
        **form_fields(proposal.form),
        "inputs": proposal.inputs,
        "rendering": proposal.rendering,
        "digest": proposal.digest,
        "route": route_fields(proposal.route),
        "branch": proposal.branch,
    }
    _ = place.proposal.write_text(json.dumps(fields, indent=2) + "\n", encoding="utf-8")


def read_log(place: Place) -> list[Entry]:
    """Return the lines of the log, oldest first."""
    if not place.log.exists():
        return []
    entries: list[Entry] = []
    for line in place.log.read_text(encoding="utf-8").splitlines():
        fields = {**FIELDS_AN_OLDER_LOG_LINE_LACKS, **fields_of(line)}
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
                rule_file=text_of(fields, "rule_file"),
                commit=text_of(fields, "commit"),
                directory=text_of(fields, "directory"),
                urls=strings_of(fields, "urls"),
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


def environment_of(inputs: pathlib.Path) -> dict[str, str]:
    """Return the environment of a command of a proposal: the tool's own, with LIVE_MUTATION_INPUTS set."""
    return {**os.environ, "LIVE_MUTATION_INPUTS": str(inputs)}


def execute(command: str, root: pathlib.Path, inputs: pathlib.Path, *, apart: bool = False) -> tuple[int, str, str]:
    """Run a line of sh from the root with LIVE_MUTATION_INPUTS set, and return its exit status and what it printed.

    Standard error follows standard output, or comes back apart. A Ctrl-C
    reaches the command through the process group it shares with this tool, so
    the tool only waits for it, and never kills it or interrupts it again:
    OpenTofu stops an apply cleanly on a first SIGINT and at once on a second,
    and a kill can leave its state locked and half written.
    """
    with tempfile.TemporaryFile(dir=inputs.parent) as out, tempfile.TemporaryFile(dir=inputs.parent) as err:
        process = subprocess.Popen(
            [SHELL, "-c", command],
            cwd=root,
            env=environment_of(inputs),
            stdout=out,
            stderr=err if apart else subprocess.STDOUT,
        )
        try:
            status = process.wait()
        except KeyboardInterrupt:
            status = process.wait()
        _ = out.seek(0)
        _ = err.seek(0)
        return status, out.read().decode(errors="replace"), err.read().decode(errors="replace")


def forms_of(secret: str) -> set[str]:
    """Return the patterns that find a sensitive string in what tofu prints, or none for a blank one.

    tofu prints a string as it is or quoted, and one that spans lines as a heredoc that indents
    each line.
    """
    lines = [line.strip() for line in secret.splitlines() if line.strip()]
    if not lines:
        return set()
    return {r"\s*".join(map(re.escape, lines)), re.escape(quoted(secret))}


def quoted(text: str) -> str:
    """Return a string as tofu prints it between quotes, escaped as Go's strconv.Quote escapes it."""
    escaped: list[str] = []
    for char in text:
        code = ord(char)
        if char in GO_ESCAPES:
            escaped.append(GO_ESCAPES[char])
        elif char.isprintable():
            escaped.append(char)
        elif char in GO_HEX_ESCAPED:
            escaped.append(f"\\x{code:02x}")
        elif code in BASIC_PLANE:
            escaped.append(f"\\u{code:04x}")
        else:
            escaped.append(f"\\U{code:08x}")
    return "".join(escaped)


def hide(text: str, secrets: Secrets) -> tuple[str, int]:
    """Return the text with each sensitive value in it replaced by HIDDEN, and how many the tool replaced."""
    forms = sorted({form for secret in secrets for form in forms_of(secret)}, key=len, reverse=True)
    return re.subn("|".join(forms), HIDDEN, text) if forms else (text, 0)


def keep(path: pathlib.Path, text: str, secrets: Secrets) -> bool:
    """Write a text with each sensitive value in it hidden. Returns whether the tool hid one."""
    hidden, count = hide(text, secrets)
    path.parent.mkdir(parents=True, exist_ok=True)
    _ = path.write_text(hidden, encoding="utf-8")
    return count > 0


def logged(place: Place, entry: Entry, printed: str, secrets: Secrets) -> bool:
    """Write what a command printed into the output that its line names, and log the line.

    Returns whether the tool hid a sensitive value in it.
    """
    shown = keep(place.outputs / entry.output, printed, secrets)
    append(place, entry)
    return shown


def checked(
    root: pathlib.Path, place: Place, kind: Kind, checks: ct.Mapping[str, str], secrets: Secrets
) -> list[tuple[Entry, bool]]:
    """Run each check's command against the inputs of a proposal, in order, and log it as the kind given.

    Returns each one's line of the log, and whether the tool hid a sensitive value in what it printed.
    """
    lines: list[tuple[Entry, bool]] = []
    for check, command in checks.items():
        output = output_name(place, kind, check)
        started = now()
        status, printed, _ = execute(command, root, place.inputs)
        entry = Entry(kind, started, now(), status, command, output, check)
        lines.append((entry, logged(place, entry, printed, secrets)))
    return lines


def digests_of(directory: pathlib.Path) -> dict[str, str]:
    """Return the SHA-256 of every file under the directory, by its path relative to it."""
    files = sorted(path for path in directory.rglob("*") if path.is_file())
    return {path.relative_to(directory).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest() for path in files}


def digest_of(commands: Commands, inputs: ct.Mapping[str, str], rendering: str) -> str:
    """Return the digest that a go-ahead names."""
    covered = {**dataclasses.asdict(commands), "inputs": dict(inputs), "rendering": rendering}
    return hashlib.sha256(json.dumps(covered, sort_keys=True).encode()).hexdigest()[:DIGEST_LENGTH]


def root_module(root: pathlib.Path, text: str) -> str:
    """Return a root module as a path relative to the root of the repository, without `.` or a trailing slash.

    Raises RefusalError for a path that is absolute, holds `..`, names no directory, or passes through a symlink,
    so that the directory a rule file lists is the directory tofu runs in.
    """
    path = pathlib.PurePosixPath(text)
    if path.is_absolute() or ".." in path.parts:
        raise RefusalError(f"bad-root: {text!r} is no path relative to the root of the repository without `..`")
    for depth in range(1, len(path.parts) + 1):
        here = pathlib.PurePosixPath(*path.parts[:depth])
        if (root / here).is_symlink():
            raise RefusalError(f"bad-root: {here} is a symlink; name the directory it points to")
    if not (root / path).is_dir():
        raise RefusalError(f"bad-root: {text!r} names no directory under the root of the repository")
    return str(path)


def resource_changes(
    plan: ct.Mapping[str, object], key: t.Literal["resource_changes", "resource_drift"] = "resource_changes"
) -> list[tuple[str, dict[str, object]]]:
    """Return the address and the change of each resource change of a plan, the change empty where it is no object.

    Raises RefusalError for a plan that holds no list of resource changes under the key.
    """
    changes = plan.get(key, [])
    if not isinstance(changes, list):
        raise RefusalError(f"plan-unreadable: the plan's JSON holds no list of resource changes under {key}")
    found: list[tuple[str, dict[str, object]]] = []
    for number, item in enumerate(t.cast("list[object]", changes), 1):
        resource = json_object(item) or {}
        address = resource.get("address")
        change = json_object(resource.get("change")) or {}
        found.append((address if isinstance(address, str) else f"resource change {number}", change))
    return found


def deletes_nothing(change: ct.Mapping[str, object]) -> bool:
    """Return whether a change lists actions and each is in DELETES_NOTHING.

    A change with no action, or with actions that the tool cannot read, counts as one that deletes, since that only
    makes the run wait.
    """
    actions = change.get("actions")
    listed = t.cast("list[object]", actions) if isinstance(actions, list) else []
    return bool(listed) and all(isinstance(action, str) and action in DELETES_NOTHING for action in listed)


def provisioned(module: object, prefix: str = "") -> list[str]:
    """Return the address of each resource that holds a provisioner, in a module and in the modules it calls.

    A resource that the tool cannot read counts as one. Raises RefusalError for a module whose configuration holds no
    list of resources or no object of module calls.
    """
    fields = json_object(module)
    resources = None if fields is None else fields.get("resources", [])
    calls = None if fields is None else json_object(fields.get("module_calls", {}))
    if not isinstance(resources, list) or calls is None:
        where = prefix.removesuffix(".") or "the root module"
        raise RefusalError(f"plan-unreadable: the plan's JSON holds no configuration of {where} that the tool reads")
    found: list[str] = []
    for number, item in enumerate(t.cast("list[object]", resources), 1):
        resource = json_object(item)
        address = None if resource is None else resource.get("address")
        if resource is None or "provisioners" in resource:
            found.append(f"{prefix}{address}" if isinstance(address, str) else f"{prefix}resource {number}")
    for name, call in calls.items():
        found.extend(provisioned((json_object(call) or {}).get("module"), f"{prefix}module.{name}."))
    return found


def exempted(route: NoGoAheadNeeded) -> str:
    """Return why a run needs no go-ahead, as the sentence that the output and the record print."""
    return (
        f"`{route.rule_file}` at `{route.commit}` lists `{route.directory}` under `{KEY}`,"
        " and the plan deletes and replaces nothing."
    )


def route_of(root: pathlib.Path, place: Place, form: Form, branch: str | None) -> Route:
    """Return whether a proposal may run without a go-ahead, from its frozen plan and the rule files at origin/HEAD.

    Reads the plan and the rule files only for the OpenTofu form, since a proposal of the generic form always waits.
    """
    if isinstance(form, Generic):
        return GoAheadNeeded((GENERIC,))
    reasons = [*plan_reasons(root, place, form), *reach_reasons(root, place, form)]
    if form.targets:
        listed = ", ".join(f"`-target={target}`" for target in form.targets)
        reasons.append(f"The plan takes {listed}, and only a plan of the whole root module runs without a go-ahead.")
    if branch is None:
        reasons.append("HEAD was detached at the proposal, so its action record has no branch to wait on.")
    try:
        declaration = unprotected_roots.declaration_of(root)
    except unprotected_roots.UndeclaredError as error:
        return GoAheadNeeded((*reasons, str(error)))
    commit = declaration.commit
    if branch == declaration.branch:
        on_default = (
            f"HEAD is on `{branch}`, the default branch of origin, so no pull request will take the action record."
        )
        reasons.append(on_default)
    reasons.extend(
        f"`{path}` at `{commit}` names `{KEY}` in a form the tool does not read, since {why}."
        for path, why in declaration.unreadable
    )
    covering = declaration.covering(form.root)
    if covering is None:
        uncovered = (
            f"No rule file under `{unprotected_roots.RULES}` at `{commit}` lists `{form.root}`"
            f" or a directory above it under `{KEY}`."
        )
        reasons.append(uncovered)
    if covering is None or reasons:
        return GoAheadNeeded(tuple(reasons))
    return NoGoAheadNeeded(rule_file=covering[0], commit=commit, directory=covering[1])


def fence(text: str) -> str:
    """Return a code fence longer than every run of backticks in the text."""
    return "`" * max([3, *(match.end() - match.start() + 1 for match in re.finditer(r"`+", text))])


def outcome(status: int) -> str:
    """Return how a check or a command ended, in words. A negative status is the signal that ended it."""
    if status < 0:
        return f"ended by signal {-status}"
    return "passes" if status == 0 else f"fails ({status})"


def outcomes(entries: ct.Iterable[Entry], kind: Kind, check: str) -> str:
    """Return how each run of a kind of one check ended, in words, or none."""
    found = [outcome(entry.status) for entry in entries if entry.kind is kind and entry.check == check]
    return ", ".join(found) or "none"


def consumed(entries: ct.Sequence[Entry]) -> Entry | None:
    """Return the line that used the proposal up, a go-ahead or a run without one, if one did."""
    return next((entry for entry in entries if entry.kind in USES_UP), None)


def go_ahead_command(name: str, digest: str) -> str:
    """Return the command that runs a proposal on a go-ahead."""
    return f"{TOOL} run {name} {digest} --go-ahead {GO_AHEAD_WORDS}"


def route_lines(name: str, digest: str, route: Route) -> list[str]:
    """Return the end of a proposal's output: its route, and the commands that run it."""
    on_a_go_ahead = ["```sh", go_ahead_command(name, digest), "```", "", QUOTING]
    if isinstance(route, GoAheadNeeded):
        return [
            "The run waits for the owner's go-ahead:",
            "",
            *[f"- {reason}" for reason in route.reasons],
            "",
            "On a go-ahead for this digest, in this conversation:",
            "",
            *on_a_go_ahead,
        ]
    return [
        f"The run needs no go-ahead: {exempted(route)}",
        JUDGED,
        "",
        "```sh",
        f"{TOOL} run {name} {digest}",
        "```",
        "",
        "Otherwise ask the owner, and on a go-ahead for this digest, in this conversation:",
        "",
        *on_a_go_ahead,
    ]


def captured(root: pathlib.Path, inputs: pathlib.Path, command: str) -> subprocess.CompletedProcess[bytes]:
    """Run a line of sh as the commands of a proposal run against the inputs, and keep what it prints in memory only."""
    return subprocess.run(
        [SHELL, "-c", command], cwd=root, env=environment_of(inputs), capture_output=True, check=False
    )


def said(result: subprocess.CompletedProcess[bytes]) -> str:
    """Return what a command printed on standard error, on one line."""
    return " ".join(result.stderr.decode(errors="replace").split())


def printed_json(root: pathlib.Path, inputs: pathlib.Path, command: str, refusal: str) -> dict[str, object]:
    """Return the JSON object that a line of sh prints, which the tool keeps in memory only.

    Raises RefusalError, named by the refusal given, when the command fails or prints no JSON object.
    """
    result = captured(root, inputs, command)
    if result.returncode != 0:
        raise RefusalError(f"{refusal}: `{command}` exited {result.returncode}: {said(result)}")
    try:
        printed = json_object(t.cast("object", json.loads(result.stdout.decode(errors="replace"))))
    except json.JSONDecodeError as error:
        raise RefusalError(f"{refusal}: `{command}` printed no JSON ({error})") from None
    if printed is None:
        raise RefusalError(f"{refusal}: `{command}` printed no JSON object")
    return printed


def read_plan(root: pathlib.Path, inputs: pathlib.Path, form: OpenTofu) -> dict[str, object]:
    """Return the JSON of the plan among the inputs of the OpenTofu form, which it keeps in memory only.

    Raises RefusalError (plan-unreadable) when tofu show -json fails or prints no JSON object.
    """
    return printed_json(root, inputs, form.plan_json(), "plan-unreadable")


def strings(value: object) -> ct.Iterator[str]:
    """Yield each string in a value of the plan's JSON."""
    if isinstance(value, str):
        yield value
    elif isinstance(value, dict):
        for item in t.cast("dict[str, object]", value).values():
            yield from strings(item)
    elif isinstance(value, list):
        for item in t.cast("list[object]", value):
            yield from strings(item)


def marked(value: object, mask: object) -> ct.Iterator[str]:
    """Yield each string of a value of the plan's JSON that its sensitivity mask marks."""
    if mask is True:
        yield from strings(value)
    elif isinstance(mask, dict) and isinstance(value, dict):
        values = t.cast("dict[str, object]", value)
        for key, inner in t.cast("dict[str, object]", mask).items():
            yield from marked(values.get(key), inner)
    elif isinstance(mask, list) and isinstance(value, list):
        for item, inner in zip(t.cast("list[object]", value), t.cast("list[object]", mask), strict=False):
            yield from marked(item, inner)


def secrets_of(plan: ct.Mapping[str, object]) -> Secrets:
    """Return each string that a plan marks sensitive.

    Raises RefusalError (plan-unreadable) for a plan whose resource changes are no list.
    """
    configuration = json_object((json_object(plan.get("configuration")) or {}).get("root_module")) or {}
    declared = json_object(configuration.get("variables")) or {}
    values = json_object(plan.get("variables")) or {}
    found = {
        secret
        for name, variable in declared.items()
        if (json_object(variable) or {}).get("sensitive") is True
        for secret in strings((json_object(values.get(name)) or {}).get("value"))
    }
    outputs = json_object(plan.get("output_changes")) or {}
    changes = [
        *(change for _, change in resource_changes(plan)),
        *(change for _, change in resource_changes(plan, "resource_drift")),
        *(json_object(change) or {} for change in outputs.values()),
    ]
    found.update(
        secret
        for change in changes
        for side in ("before", "after")
        for secret in marked(change.get(side), change.get(f"{side}_sensitive"))
    )
    return frozenset(found)


def module_secrets(module: object) -> ct.Iterator[str]:
    """Yield each string that a module of a state's JSON marks sensitive, in its resources and its child modules.

    Raises RefusalError (state-unreadable) for a module whose resources or child modules are no list.
    """
    fields = json_object(module) or {}
    resources, children = fields.get("resources", []), fields.get("child_modules", [])
    if not isinstance(resources, list) or not isinstance(children, list):
        raise RefusalError("state-unreadable: the state's JSON holds a module whose resources or modules are no list")
    for item in t.cast("list[object]", resources):
        resource = json_object(item) or {}
        yield from marked(resource.get("values"), resource.get("sensitive_values"))
    for child in t.cast("list[object]", children):
        yield from module_secrets(child)


def state_secrets_of(state: ct.Mapping[str, object]) -> Secrets:
    """Return each string that a state's JSON marks sensitive, in an output or a resource of any module."""
    values = json_object(state.get("values")) or {}
    outputs = (json_object(output) or {} for output in (json_object(values.get("outputs")) or {}).values())
    found = {secret for output in outputs for secret in marked(output.get("value"), output.get("sensitive"))}
    return frozenset(found | set(module_secrets(values.get("root_module"))))


def state_secrets_in(root: pathlib.Path, inputs: pathlib.Path, form: Form) -> Secrets:
    """Return each value that the state of the root module of the OpenTofu form marks sensitive now.

    The state holds what the plan cannot know, such as a value that the apply generates, and what a -target plan
    leaves out. Returns none for the generic form, whose root module the tool does not know. Raises RefusalError
    (state-unreadable) when tofu show -json cannot read the state.
    """
    if isinstance(form, Generic):
        return frozenset()
    return state_secrets_of(printed_json(root, inputs, form.tofu("show -json"), "state-unreadable"))


def secrets_in(root: pathlib.Path, inputs: pathlib.Path, form: Form) -> Secrets:
    """Return each value that the plan among the inputs or the state of its root module marks sensitive now.

    The tool cannot read what the inputs of the generic form mark sensitive, so it returns none for that form. Raises
    RefusalError (plan-unreadable or state-unreadable) when tofu show -json cannot read one of the two.
    """
    planned = frozenset[str]() if isinstance(form, Generic) else secrets_of(read_plan(root, inputs, form))
    return planned | state_secrets_in(root, inputs, form)


def plan_reasons(root: pathlib.Path, place: Place, form: OpenTofu) -> list[str]:
    """Return why the frozen plan makes a run wait, read from its JSON in memory and never written anywhere."""
    plan = read_plan(root, place.inputs, form)
    reasons: list[str] = []
    changes = resource_changes(plan)
    blocking = [address for address, change in changes if not deletes_nothing(change)]
    if blocking:
        listed = ", ".join(f"`{address}`" for address in blocking)
        reasons.append(f"The plan does more than create, read or update these resources: {listed}.")
    imported = [address for address, change in changes if "importing" in change]
    if imported:
        listed = ", ".join(f"`{address}`" for address in imported)
        adopts = f"The plan imports these resources, and so adopts objects that the state of `{form.root}` never held"
        reasons.append(f"{adopts}: {listed}.")
    provisioners = provisioned((json_object(plan.get("configuration")) or {}).get("root_module"))
    if provisioners:
        listed = ", ".join(f"`{address}`" for address in provisioners)
        reasons.append(
            f"A provisioner runs code that the plan does not show, and the configuration holds one in {listed}."
        )
    return reasons


def reach_reasons(root: pathlib.Path, place: Place, form: OpenTofu) -> list[str]:
    """Return why the tool's environment makes the apply reach more than the plan of the declared directory shows.

    A TF_CLI_ARGS variable passes arguments that the form does not write, TF_DATA_DIR picks a backend and a state
    that -chdir does not, and a workspace other than default reaches a state that the rule file does not name.
    """
    reasons = [
        f"`{name}` is set, so tofu runs with arguments that the OpenTofu form does not write."
        for name in sorted(os.environ)
        if name == "TF_CLI_ARGS" or name.startswith("TF_CLI_ARGS_")
    ]
    if "TF_DATA_DIR" in os.environ:
        reasons.append("`TF_DATA_DIR` is set, so tofu reads a backend and a state that `-chdir` does not choose.")
    command = form.tofu("workspace show")
    result = captured(root, place.inputs, command)
    workspace = result.stdout.decode(errors="replace").strip()
    if result.returncode != 0:
        unknown = f"`{command}` exited {result.returncode}: {said(result)}"
        reasons.append(f"{unknown}, so the tool cannot tell which workspace the apply reaches.")
    elif workspace != "default":
        other = (
            f"The workspace of `{form.root}` is `{workspace}`, and only its `default` workspace runs without a"
            " go-ahead, since a rule file declares a directory and not a workspace."
        )
        reasons.append(other)
    return reasons


def changed_inputs(before: ct.Mapping[str, str], after: ct.Mapping[str, str]) -> str:
    """Return the inputs whose digests differ, by their paths, or nothing when none does."""
    return ", ".join(sorted(path for path in {*before, *after} if before.get(path) != after.get(path)))


def sensitive_shown(paths: ct.Iterable[pathlib.Path], outcome_of_it: str) -> RefusalError:
    """Return the refusal of a proposal or a run that printed a sensitive value, naming the files where it is hidden."""
    listed = ", ".join(str(path) for path in paths)
    message = (
        "sensitive-value-shown: a command printed a value that the plan or the state marks sensitive, so"
        f" {outcome_of_it}; the tool hid it in {listed}. OpenTofu prints such a value where it loses the mark, as in"
        " the output of a terraform_data resource whose input holds one. When a check of yours printed it, fix the"
        " check and propose again. Otherwise stop and tell the owner, since the generic form refuses an OpenTofu plan."
    )
    return RefusalError(message)


def is_saved_plan(path: pathlib.Path) -> bool:
    """Return whether a file is an OpenTofu saved plan: a zip archive that holds a member named tfplan."""
    try:
        with zipfile.ZipFile(path) as archive:
            return SAVED_PLAN_MEMBER in archive.namelist()
    except zipfile.BadZipFile:
        return False


def refuse_saved_plans(inputs: pathlib.Path, outcome_of_it: str) -> None:
    """Refuse inputs of the generic form that hold an OpenTofu saved plan, whose sensitive values that form cannot read.

    Raises RefusalError (saved-plan) before the tool writes anything that the derive command printed.
    """
    plans = sorted(
        path.relative_to(inputs).as_posix() for path in inputs.rglob("*") if path.is_file() and is_saved_plan(path)
    )
    if plans:
        message = (
            f"saved-plan: the derive command wrote the OpenTofu saved plan {', '.join(plans)}, whose sensitive values"
            f" the generic form cannot hide, so {outcome_of_it}, and the tool wrote nothing that it printed."
            f" {OPENTOFU_FORM}"
        )
        raise RefusalError(message)


def unread_command(part: str, why: str) -> RefusalError:
    """Return the refusal of a command that names tofu and that the tool cannot read."""
    message = (
        f"unread-command: `{part}` names tofu, and the tool cannot read it, since {why}, so it cannot tell what"
        " OpenTofu prints there. Spell the OpenTofu command out, without a variable, a substitution or a script"
        " that runs it."
    )
    return RefusalError(message)


def is_frozen_plan(word: shell_syntax.Word) -> bool:
    """Return whether a word names the frozen plan by LIVE_MUTATION_INPUTS, quoted or not."""
    return word.unexpanded in FROZEN_PLAN or word.text in FROZEN_PLAN


def directory_read(run: opentofu_commands.Run, found: opentofu_commands.TofuCommand) -> str:
    """Return the directory that an OpenTofu run reads, its -chdir or the root of the repository, without `./`.

    Raises UnreadRunError when an expansion hides a global option.
    """
    directory = "."
    for option in found.options:
        name = opentofu_commands.flag_name(option)
        if name is None or (name == "chdir" and option.value is None):
            raise UnreadRunError(f"a global option {run.origin}")
        if name == "chdir" and option.value is not None:
            directory = option.value.partition("=")[2]
    return str(pathlib.PurePosixPath(directory))


def argument_reasons(run: opentofu_commands.Run, found: opentofu_commands.TofuCommand) -> list[str]:
    """Return how the arguments of a value-printing OpenTofu run read another state, other values or another file."""
    reasons: list[str] = []
    for argument in found.arguments:
        name = opentofu_commands.flag_name(argument)
        if found.name == "show" and name in {"", None}:
            if not is_frozen_plan(argument):
                reasons.append(f"of `{argument.text}`, a file other than the frozen plan")
        elif name is None:
            raise UnreadRunError(f"an argument {run.origin}")
        elif name in READS_ANOTHER_STATE:
            reasons.append(f"with `-{name}`")
    return reasons


def foreign_reasons(command: str, run: opentofu_commands.Run, form: OpenTofu, *, moves: bool) -> list[str]:
    """Return how a value-printing OpenTofu run reads more than the root module of the form, or none.

    None means that the run reads the root module of the form alone: its -chdir names it, the command changes no
    directory and sets no TF_ variable, the run takes no argument that reads another state or other values, and a
    show reads no file but the frozen plan. Raises UnreadRunError when an expansion hides what the run reads.
    """
    found = opentofu_commands.tofu_command(run.arguments)
    directory = directory_read(run, found)
    reasons = [f"against `{directory}`"] if directory != form.root else []
    if moves:
        reasons.append("after a cd, pushd or popd, which may leave it")
    if SETS_A_TF_VARIABLE.search(command) is not None:
        reasons.append("while the command sets a `TF_` variable, which may point it at another state")
    return [*reasons, *argument_reasons(run, found)]


def run_refusal(command: str, run: opentofu_commands.Run, form: Form, *, moves: bool) -> RefusalError | None:
    """Return why the tool refuses an OpenTofu run in a command of a proposal, or None when it may run there."""
    name = opentofu_commands.tofu_command(run.arguments).name
    if name is None:
        return unread_command(run.part, f"its subcommand {run.origin}")
    if name not in opentofu_commands.PRINTS_VALUES:
        return None
    prints = f"unhidden-values: `{run.part}` runs `tofu {name}`, which prints the values of a plan or a state"
    if isinstance(form, Generic):
        return RefusalError(f"{prints}, and the generic form hides none of them. {OPENTOFU_FORM} {IN_THE_SHELL}")
    try:
        reasons = foreign_reasons(command, run, form, moves=moves)
    except UnreadRunError as error:
        return unread_command(run.part, str(error))
    if not reasons:
        return None
    message = (
        f"{prints}, {', '.join(reasons)}, and the tool hides only the values that the frozen plan and the state of"
        f" `{form.root}` mark sensitive."
        f" {OWN_ROOT_ONLY}"
    )
    return RefusalError(message)


def finding_refusal(
    command: str, finding: opentofu_commands.Finding, form: Form, *, moves: bool
) -> RefusalError | None:
    """Return why the tool refuses what the reader found in a command of a proposal, or None."""
    match finding:
        case opentofu_commands.Unparsed(cause=opentofu_commands.Unparsable.PARSER_MISSING):
            return unread_command(command, "shfmt, which parses it, is not on the PATH of the tool")
        case opentofu_commands.Unparsed():
            return unread_command(command, "it parses neither as bash nor as zsh")
        case opentofu_commands.Hidden(part=part, why=why):
            return unread_command(part, why)
        case opentofu_commands.ReadsStandardInput(part=part):
            return unread_command(part, "it runs a shell on commands from standard input that the tool does not see")
        case opentofu_commands.Run(program=program):
            return run_refusal(command, finding, form, moves=moves) if opentofu_commands.names_tofu(program) else None


def refusal_of(command: str, form: Form) -> RefusalError | None:
    """Return why the tool refuses a command of a proposal for what OpenTofu may print in it, or None.

    The tool hides only the values that the frozen plan and the state of the root module of the OpenTofu form mark
    sensitive, so the generic form runs no OpenTofu command that prints values, and a check or a demonstration of the
    OpenTofu form runs one only against the root module of the form. It reads the command with the reader of the
    plugin's OpenTofu hook, and refuses a command that names tofu and that the reader cannot read.
    """
    if opentofu_commands.NAMES_TOFU.search(command) is None:
        return None
    findings = list(opentofu_commands.findings(command))
    moves = any(
        isinstance(finding, opentofu_commands.Run)
        and shell_syntax.command_name(finding.program.value) in CHANGES_DIRECTORY
        for finding in findings
    )
    refusals = (finding_refusal(command, finding, form, moves=moves) for finding in findings)
    return next((refusal for refusal in refusals if refusal is not None), None)


def commands_written_by_hand(form: Form) -> list[str]:
    """Return the commands of a form that the agent wrote: all of the generic form, the checks of the OpenTofu form."""
    match form:
        case Generic(commands=commands):
            return [commands.derive, commands.show, commands.run, *commands.checks.values()]
        case OpenTofu(checks=checks):
            return list(checks.values())


def refuse_unhidden(commands: ct.Iterable[str], form: Form) -> None:
    """Refuse the first command that may print OpenTofu values that the tool cannot hide, before any of them runs.

    Raises RefusalError (unhidden-values or unread-command).
    """
    refusal = next((found for command in commands if (found := refusal_of(command, form)) is not None), None)
    if refusal is not None:
        raise refusal


def derive_and_show(root: pathlib.Path, place: Place, form: Form) -> tuple[Secrets, list[pathlib.Path]]:
    """Derive the inputs of a proposal and render them, and log both with each sensitive value hidden.

    Returns the sensitive values of the plan and the state, and the files where the tool hid one. Raises RefusalError
    (derive-failed or show-failed) when either command fails, (saved-plan) when the derive command of the generic
    form wrote an OpenTofu saved plan, (plan-unreadable or state-unreadable) when tofu show -json cannot read the
    plan or the state, and (corrupt) for a line of the log whose JSON is no object or lacks a field.
    """
    commands = form.commands
    output = output_name(place, Kind.DERIVE)
    started = now()
    status, printed, _ = execute(commands.derive, root, place.inputs)
    if isinstance(form, Generic):
        refuse_saved_plans(place.inputs, "there is no proposal")
    derived = Entry(Kind.DERIVE, started, now(), status, commands.derive, output)
    secrets = secrets_in(root, place.inputs, form) if status == 0 else frozenset[str]()
    hidden = [place.outputs / output] if logged(place, derived, printed, secrets) else []
    if status != 0:
        raise RefusalError(f"derive-failed: derive exited {status}; see {place.outputs / output}")
    output = output_name(place, Kind.SHOW)
    started = now()
    status, rendering, errors = execute(commands.show, root, place.inputs, apart=True)
    hidden += [place.rendering] if keep(place.rendering, rendering, secrets) else []
    shown_line = Entry(Kind.SHOW, started, now(), status, commands.show, output)
    hidden += [place.outputs / output] if logged(place, shown_line, errors, secrets) else []
    if status != 0:
        raise RefusalError(f"show-failed: show exited {status}; see {place.outputs / output}")
    return secrets, hidden


def propose(root: pathlib.Path, session: str, name: str, form: Form) -> str:
    """Derive, render and check a proposal of this session, and return the text that shows it to the owner.

    Raises RefusalError (bad-name) for a name or a check that is no kebab-case name, (unhidden-values or
    unread-command) for a command that may print OpenTofu values that the tool cannot hide, (corrupt) for a line of
    the log whose JSON is no object or lacks a field, (already-ran) when a proposal of the name ran, (derive-failed,
    show-failed, saved-plan, plan-unreadable or state-unreadable) as derive_and_show does, (inputs-changed) when a
    check changes an input, so that the route, the digest and the run all read the inputs that the derive command
    wrote, (sensitive-value-shown) when a command printed a value that the plan or the state marks sensitive, and
    (nothing-to-apply) when the plan of the OpenTofu form changes nothing. Raises GitError (git-missing or
    git-failed) when git cannot read the branch or the rule files.
    """
    commands = form.commands
    place = place_of(root, session, name)
    for check in commands.checks:
        if not NAME.fullmatch(check):
            raise RefusalError(f"bad-name: the check {check!r} is not a kebab-case name such as no-changes")
    refuse_unhidden(commands_written_by_hand(form), form)
    branch = unprotected_roots.branch_of(root)
    if place.directory.exists():
        used = consumed(read_log(place))
        if used is not None:
            raise RefusalError(f"already-ran: proposal {name} ran at {used.started}; propose under a new name")
        shutil.rmtree(place.directory)
    place.outputs.mkdir(parents=True)
    place.inputs.mkdir()
    secrets, hidden = derive_and_show(root, place, form)
    rendered = place.rendering.read_bytes()
    inputs = digests_of(place.inputs)
    results = checked(root, place, Kind.CHECK, commands.checks, secrets)
    hidden += [place.outputs / entry.output for entry, hid in results if hid]
    changed = changed_inputs(inputs, digests_of(place.inputs))
    if changed:
        raise RefusalError(f"inputs-changed: {changed} changed while the checks ran; a check only reads, so fix it")
    if hidden:
        raise sensitive_shown(hidden, "there is no proposal")
    if isinstance(form, OpenTofu) and any(entry.check == NO_CHANGES and entry.status == 0 for entry, _ in results):
        message = (
            f"nothing-to-apply: the plan of {form.root} changes nothing, since its check {NO_CHANGES} passes,"
            " so the check could never fail"
        )
        raise RefusalError(message)
    route = route_of(root, place, form, branch)
    rendering = rendered.decode(encoding="utf-8", errors="replace")
    rendering_digest = hashlib.sha256(rendered).hexdigest()
    digest = digest_of(commands, inputs, rendering_digest)
    proposal = Proposal(name, session, now(), form, inputs, rendering_digest, digest, route, branch)
    save(place, proposal)
    checks = [f"- `{entry.check}` {outcome(entry.status)}: `{entry.command}`" for entry, _ in results] or ["- none"]
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
        *route_lines(name, digest, route),
    ]
    return "\n".join(lines) + "\n"


def find(root: pathlib.Path, session: str, name: str) -> Place:
    """Return the place of a proposal of this session.

    Raises RefusalError (bad-name) for a name that is no kebab-case name, and (not-in-this-conversation) when this
    session showed none by the name.
    """
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


def held(root: pathlib.Path, session: str, name: str) -> Place:
    """Return the place of a proposal of the session, this one or another.

    Raises RefusalError (bad-name) for a name that is no kebab-case name, and (not-found) when the session holds none
    by the name.
    """
    place = place_of(root, session, name)
    if not place.proposal.exists():
        raise RefusalError(f"not-found: session {session} holds no proposal {name}")
    return place


def demonstrate(root: pathlib.Path, session: str, name: str, check: str, command: str) -> tuple[int, str]:
    """Run a check's command against a state where its property does not hold, and log it in the session's proposal."""
    place = held(root, session, name)
    form = load(place).form
    if check not in form.commands.checks:
        raise RefusalError(f"no-such-check: proposal {name} has no check {check}")
    refuse_unhidden([command], form)
    secrets = secrets_in(root, place.inputs, form)
    [(entry, _)] = checked(root, place, Kind.DEMONSTRATION, {check: command}, secrets)
    if entry.status == 0:
        return 1, f"The demonstration of {check} passed, so it shows nothing; see {place.outputs / entry.output}\n"
    return 0, f"The demonstration of {check} {outcome(entry.status)}, as a check must where its property fails.\n"


def drift_check(root: pathlib.Path, place: Place, proposal: Proposal, secrets: Secrets, *, approved: bool) -> Secrets:
    """Derive and render again from live state into the directory drift, and log it.

    The rendering is the one the owner approved on a go-ahead, and the proposed one without. Returns the given
    sensitive values with those of the plan derived again and of the state. Raises RefusalError (drift-check-failed)
    when deriving or rendering again fails, (saved-plan) when the derive command of the generic form wrote an
    OpenTofu saved plan, (plan-unreadable or state-unreadable) when tofu show -json cannot read the plan derived again
    or the state, (sensitive-value-shown) when deriving or rendering again printed a sensitive value, (drifted) when
    the rendering derived again differs, and (corrupt) for a line of the log whose JSON is no object or lacks a field.
    """
    started = now()
    if place.drift.exists():
        shutil.rmtree(place.drift)
    inputs = place.drift / "inputs"
    inputs.mkdir(parents=True)
    commands = proposal.form.commands
    status, printed, _ = execute(commands.derive, root, inputs)
    if isinstance(proposal.form, Generic):
        refuse_saved_plans(inputs, "nothing ran")
    rendering = errors = ""
    if status == 0:
        secrets |= secrets_in(root, inputs, proposal.form)
        status, rendering, errors = execute(commands.show, root, inputs, apart=True)
    log, again = place.drift / "derive-and-show.txt", place.drift / "rendering.txt"
    hidden = [path for path, text in ((log, printed + errors), (again, rendering)) if keep(path, text, secrets)]
    rendering = again.read_text(encoding="utf-8")
    shown = place.rendering.read_text(encoding="utf-8", errors="replace").splitlines(keepends=True)
    label = "approved" if approved else "proposed"
    diff = "".join(difflib.unified_diff(shown, rendering.splitlines(keepends=True), label, "live now"))
    output = output_name(place, Kind.DRIFT)
    _ = (place.outputs / output).write_text(diff or f"The rendering derived again equals the {label} one.\n")
    append(place, Entry(Kind.DRIFT, started, now(), status or int(bool(diff)), "derive and show again", output))
    if status != 0:
        raise RefusalError(f"drift-check-failed: deriving again exited {status}; see {place.drift}")
    if hidden:
        raise sensitive_shown(hidden, "nothing ran")
    if diff:
        what = "the rendering the owner approved" if approved else "the rendering of the proposal"
        raise RefusalError(f"drifted: live state no longer gives {what}\n{diff}")
    return secrets


def exemption_of(root: pathlib.Path, place: Place, proposal: Proposal) -> NoGoAheadNeeded:
    """Return what lets a proposal run without a go-ahead, read again from its frozen plan and the rule files.

    Raises RefusalError (needs-go-ahead) with each reason when the route read now needs a go-ahead, or the proposal
    was shown with a route that needs one, and (plan-unreadable) when the tool cannot read the JSON of the frozen
    plan. Raises GitError (git-missing or git-failed) when git cannot read the rule files.
    """
    route = route_of(root, place, proposal.form, proposal.branch)
    shown_waiting = isinstance(proposal.route, GoAheadNeeded)
    if isinstance(route, NoGoAheadNeeded) and not shown_waiting:
        return route
    waits = [*(route.reasons if isinstance(route, GoAheadNeeded) else ()), *([SHOWN_WAITING] if shown_waiting else [])]
    name = proposal.name
    reasons = "".join(f"\n- {reason}" for reason in waits)
    message = (
        f"needs-go-ahead: proposal {name} runs only on the owner's go-ahead:{reasons}\n"
        f"Show the owner the proposal and ask. On a go-ahead: {go_ahead_command(name, proposal.digest)}\n{QUOTING}"
    )
    raise RefusalError(message)


@contextlib.contextmanager
def one_run_at_a_time(place: Place) -> ct.Generator[None]:
    """Hold the lock of a proposal's directory, which one run of the proposal holds at a time.

    A run holds it from the check that nothing used the proposal up until it logs the line that uses it up, so of two
    runs started together the second waits and then finds the proposal used up. The kernel drops the lock with the
    process that held it, so a run that died leaves none behind.
    """
    directory = os.open(place.directory, os.O_RDONLY | os.O_DIRECTORY)
    try:
        fcntl.flock(directory, fcntl.LOCK_EX)
        yield
    finally:
        os.close(directory)


def run(root: pathlib.Path, session: str, name: str, digest: str, words: str | None) -> tuple[int, str]:
    """Run a proposal of this session once, on a go-ahead for its digest or where it needs none, then check it."""
    if words is not None and not words.strip():
        raise RefusalError("empty-go-ahead: --go-ahead holds no words; quote the owner's go-ahead word for word")
    place = find(root, session, name)
    proposal = load(place)
    if digest != proposal.digest:
        message = (
            f"digest-mismatch: the run names {digest}, and proposal {name} is at {proposal.digest};"
            " show the owner the proposal at that digest and ask again"
        )
        raise RefusalError(message)
    with one_run_at_a_time(place):
        used = consumed(read_log(place))
        if used is not None and used.kind is Kind.GO_AHEAD:
            message = (
                f"already-ran: proposal {name} ran on the go-ahead {used.words!r} at {used.started};"
                " a go-ahead covers one run, so propose again from the new live state"
            )
            raise RefusalError(message)
        if used is not None:
            message = (
                f"already-ran: proposal {name} ran without a go-ahead at {used.started};"
                " a proposal runs once, so propose again from the new live state"
            )
            raise RefusalError(message)
        refuse_unhidden(commands_written_by_hand(proposal.form), proposal.form)
        changed = changed_inputs(proposal.inputs, digests_of(place.inputs))
        if changed:
            raise RefusalError(f"inputs-changed: {changed} changed since the proposal; propose again")
        secrets = secrets_in(root, place.inputs, proposal.form)
        allowed_by = words if words is not None else exemption_of(root, place, proposal)
        secrets = drift_check(root, place, proposal, secrets, approved=isinstance(allowed_by, str))
        output = output_name(place, Kind.RUN)
        if isinstance(allowed_by, str):
            allowed = Entry(Kind.GO_AHEAD, now(), now(), 0, output=output, words=allowed_by)
        else:
            allowed = Entry(
                Kind.NO_GO_AHEAD,
                now(),
                now(),
                0,
                output=output,
                rule_file=allowed_by.rule_file,
                commit=allowed_by.commit,
                directory=allowed_by.directory,
            )
        append(place, allowed)
    started = now()
    path = place.outputs / output
    commands = proposal.form.commands
    status, printed, _ = execute(commands.run, root, place.inputs)
    try:
        secrets |= state_secrets_in(root, place.inputs, proposal.form)
    except RefusalError as error:
        message = (
            f"{error}\nThe run {outcome(status)}, and the tool kept nothing that it printed and ran no check after it,"
            " since it cannot tell which values the apply generated. Judge the result from live state, and write the"
            " record."
        )
        raise RefusalError(message) from None
    _ = logged(place, Entry(Kind.RUN, started, now(), status, commands.run, output), printed, secrets)
    after = [entry for entry, _ in checked(root, place, Kind.CHECK, commands.checks, secrets)]
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
        f"Write the action record now: {TOOL} record {name}",
    ]
    good = status == 0 and all(entry.status == 0 for entry in after)
    return (0 if good else 1), "\n".join(lines) + "\n"


def details(summary: str, path: pathlib.Path) -> str:
    """Return a file as a collapsed block of Markdown, cut in the middle when it would fill half a comment."""
    text = path.read_text(encoding="utf-8", errors="replace") if path.exists() else ""
    text = text if text.strip() else "(no output)\n"
    half = COMMENT_LIMIT // 4
    if len(text) > 2 * half:
        text = f"{text[:half]}\n[{len(text) - 2 * half} characters cut; the whole output is in {path}]\n{text[-half:]}"
    marker = fence(text)
    return f"<details><summary>{summary}</summary>\n\n{marker}text\n{text.rstrip()}\n{marker}\n\n</details>\n\n"


def record(root: pathlib.Path, session: str, name: str) -> list[pathlib.Path]:
    """Write the action record of a run as Markdown comments that GitHub accepts, and return their paths."""
    place = held(root, session, name)
    proposal = load(place)
    entries = read_log(place)
    used = consumed(entries)
    if used is None:
        raise RefusalError(f"not-run: proposal {name} has not run, so there is no run to record")
    commands = proposal.form.commands
    for check in commands.checks:
        if all(entry.status == 0 for entry in entries if entry.check == check):
            message = (
                f"check-never-failed: the check {check} never failed, so it is no evidence;"
                f" run {TOOL} demonstrate {name} {check} '<cmd>' --session {session} where its property does not hold"
            )
            raise RefusalError(message)
    position = entries.index(used)
    before, after = entries[:position], entries[position:]
    ran = next((entry for entry in after if entry.kind is Kind.RUN), None)
    drift = next(entry for entry in reversed(before) if entry.kind is Kind.DRIFT)
    if ran is None:
        finished = f"- The run started at {used.started} and has no end in the log."
    else:
        finished = f"- The run {outcome(ran.status)}, from {ran.started} to {ran.ended}."
    if used.kind is Kind.GO_AHEAD:
        allowed = f"- Go-ahead at {used.started}, in the owner's words: {json.dumps(used.words)}"
        drifted, rendering = "approved", "The rendering the owner approved"
    else:
        allowed = f"- No go-ahead was asked: {exempted(NoGoAheadNeeded(used.rule_file, used.commit, used.directory))}"
        drifted, rendering = "proposed", "The rendering of the proposal"
    rows = [
        " | ".join(
            [
                f"| `{check}`",
                outcomes(before, Kind.CHECK, check),
                outcomes(after, Kind.CHECK, check),
                f"{outcomes(entries, Kind.DEMONSTRATION, check)} |",
            ]
        )
        for check in commands.checks
    ]
    header = [
        f"## Action record of `{name}`",
        "",
        f"- Proposal digest `{proposal.digest}`, shown at {proposal.created} in session `{session}`.",
        allowed,
        f"- Drift check at {drift.ended}: the rendering derived again equals the {drifted} one.",
        finished,
        "",
        "| Check | Before the run | After the run | Demonstrations |",
        "| --- | --- | --- | --- |",
        *rows,
        "",
        f"{fence(commands.run)}sh",
        commands.run,
        fence(commands.run),
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
        details(rendering, place.rendering),
        details("The output of the run", place.outputs / used.output),
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


def posted(root: pathlib.Path, session: str, name: str, urls: ct.Sequence[str]) -> str:
    """Log the URLs of the comments that hold the action record of a run, which takes it off the pending list."""
    place = held(root, session, name)
    if consumed(read_log(place)) is None:
        raise RefusalError(f"not-run: proposal {name} has not run, so it has no action record to post")
    wrong = [url for url in urls if not URL.fullmatch(url)]
    if wrong:
        raise RefusalError(f"bad-url: {', '.join(wrong)} is no https URL of a comment")
    append(place, Entry(Kind.POSTED, now(), now(), 0, urls=tuple(urls)))
    return f"The action record of {name} is posted at {', '.join(urls)}.\n"


def pending(root: pathlib.Path) -> tuple[int, str]:
    """List the runs of the current branch whose action record is not posted, in every session, in the order they ran.

    Returns 1 when a proposal could not be read, since its run may be among them. Raises RefusalError (detached-head)
    when HEAD is detached, and GitError (git-missing or git-failed) when git cannot read the branch.
    """
    branch = unprotected_roots.branch_of(root)
    if branch is None:
        raise RefusalError("detached-head: HEAD is detached, so there is no branch whose runs pending could list")
    waiting: list[Waiting] = []
    unreadable: list[str] = []
    for path in sorted(sessions_root(root).glob("*/*/proposal.json")):
        place = place_at(path.parent)
        try:
            proposal, entries = load(place), read_log(place)
        except (RefusalError, ValueError) as error:
            unreadable.append(f"- {path.relative_to(root)}: {error}")
            continue
        used = consumed(entries)
        if proposal.branch == branch and used is not None and all(entry.kind is not Kind.POSTED for entry in entries):
            waiting.append(Waiting(used.started, path.parent.parent.name, proposal.name, used.kind is Kind.GO_AHEAD))
    lines: list[str] = []
    if waiting:
        lines += [f"The runs of branch `{branch}` whose action record is not posted, in the order they ran:", ""]
    else:
        lines.append(f"No run of branch `{branch}` waits for its action record to be posted.")
    for unposted in sorted(waiting):
        how = "on a go-ahead" if unposted.gated else "without a go-ahead"
        lines += [
            f"- `{unposted.name}` of session `{unposted.session}`, run {how} at {unposted.ran}.",
            "  Write its record, post each file it names in order, and note the URLs:",
            "",
            "  ```sh",
            f"  {TOOL} record {unposted.name} --session {unposted.session}",
            f"  {TOOL} posted {unposted.name} <url>... --session {unposted.session}",
            "  ```",
            "",
        ]
    if unreadable:
        lines += ["", "These proposals could not be read, so whether their record waits is unknown:", "", *unreadable]
    return (1 if unreadable else 0), "\n".join(lines).rstrip("\n") + "\n"


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
    _ = proposing.add_argument("--derive", help="writes the frozen inputs into $LIVE_MUTATION_INPUTS")
    _ = proposing.add_argument("--show", help="prints what the owner reads")
    _ = proposing.add_argument("--run", help="executes the frozen inputs")
    _ = proposing.add_argument(
        "--opentofu", metavar="ROOT", help="in place of the three, apply a plan of this root module"
    )
    _ = proposing.add_argument("--destroy", action="store_true", help="with --opentofu, plan a destroy")
    _ = proposing.add_argument(
        "--target",
        action="append",
        default=[],
        metavar="ADDRESS",
        help="with --opentofu, plan only this resource address, as -target does; the proposal then waits",
    )
    _ = proposing.add_argument("--check", type=check_pair, action="append", default=[], metavar="CHECK=CMD")
    demonstrating = commands.add_parser("demonstrate", help="run a check where its property does not hold")
    _ = demonstrating.add_argument("name")
    _ = demonstrating.add_argument("check")
    _ = demonstrating.add_argument("cmd")
    _ = demonstrating.add_argument("--session", help="the session that showed it, when not this one")
    running = commands.add_parser("run", help="run a proposal of this conversation once")
    _ = running.add_argument("name")
    _ = running.add_argument("digest")
    _ = running.add_argument("--go-ahead", help="the owner's words; without them, only a proposal that needs none runs")
    recording = commands.add_parser("record", help="write the action record of a run")
    _ = recording.add_argument("name")
    _ = recording.add_argument("--session", help="the session that ran it, when not this one")
    posting = commands.add_parser("posted", help="note the URLs of the comments that hold the action record of a run")
    _ = posting.add_argument("name")
    _ = posting.add_argument("urls", nargs="+", metavar="URL")
    _ = posting.add_argument("--session", help="the session that ran it, when not this one")
    _ = commands.add_parser("pending", help="list the runs of this branch whose action record is not posted")
    return parsing


def proposed(parsing: argparse.ArgumentParser, parsed: argparse.Namespace, root: pathlib.Path) -> Form:
    """Return the form that the arguments of propose ask for. Exits 2 on a wrong combination.

    Raises RefusalError (reserved-check) for a check of the OpenTofu form named no-changes, which the form adds
    itself, and (bad-root) for a root module that is no directory relative to the repository, as root_module says.
    """
    derive, show, executes = (t.cast("str | None", getattr(parsed, flag)) for flag in ("derive", "show", "run"))
    opentofu, destroy = t.cast("str | None", parsed.opentofu), t.cast("bool", parsed.destroy)
    targets = tuple(t.cast("list[str]", parsed.target))
    checks = dict(t.cast("list[tuple[str, str]]", parsed.check))
    if opentofu is not None:
        if derive is not None or show is not None or executes is not None:
            parsing.error("--opentofu writes the derive, show and run commands itself, so it takes none of them")
        if NO_CHANGES in checks:
            raise RefusalError(f"reserved-check: the OpenTofu form adds the check {NO_CHANGES}; name yours otherwise")
        return OpenTofu(root=root_module(root, opentofu), destroy=destroy, targets=targets, checks=checks)
    if derive is None or show is None or executes is None:
        parsing.error("propose takes --derive, --show and --run, or --opentofu")
    if destroy:
        parsing.error("--destroy plans a destroy of the OpenTofu form, so it takes --opentofu")
    if targets:
        parsing.error("--target narrows a plan of the OpenTofu form, so it takes --opentofu")
    return Generic(Commands(derive, show, executes, checks))


def session_named(parsed: argparse.Namespace, environ: ct.Mapping[str, str]) -> str:
    """Return the session that --session names, or this one without it.

    Raises RefusalError (bad-session) for a --session that is no session ID, which must never fall back to this
    session, and (no-conversation) without --session outside a Claude Code session.
    """
    given = t.cast("str | None", parsed.session)
    if given is None:
        return session_of(environ)
    if not SESSION.fullmatch(given):
        message = (
            f"bad-session: {given!r} is no session ID, which holds only letters, digits, `_` and `-`;"
            " name the session that pending lists"
        )
        raise RefusalError(message)
    return given


def main(arguments: ct.Sequence[str], environ: ct.Mapping[str, str]) -> int:
    """Run the command that the arguments name. Returns the exit status."""
    parsing = parser()
    parsed = parsing.parse_args(arguments)
    command = t.cast("str", parsed.command)
    root = repository_root(pathlib.Path.cwd())
    status = 0
    try:
        match command:
            case "propose":
                form = proposed(parsing, parsed, root)
                text = propose(root, session_of(environ), t.cast("str", parsed.name), form)
            case "demonstrate":
                name, check, cmd = (t.cast("str", getattr(parsed, field)) for field in ("name", "check", "cmd"))
                status, text = demonstrate(root, session_named(parsed, environ), name, check, cmd)
            case "run":
                name, digest = t.cast("str", parsed.name), t.cast("str", parsed.digest)
                status, text = run(root, session_of(environ), name, digest, t.cast("str | None", parsed.go_ahead))
            case "record":
                paths = record(root, session_named(parsed, environ), t.cast("str", parsed.name))
                text = "".join(f"{path}\n" for path in paths)
            case "posted":
                urls = t.cast("list[str]", parsed.urls)
                text = posted(root, session_named(parsed, environ), t.cast("str", parsed.name), urls)
            case "pending":
                status, text = pending(root)
            case _:
                parsing.error(f"no such command: {command}")
    except (RefusalError, unprotected_roots.GitError) as refusal:
        print(f"live-mutation.py: {refusal}", file=sys.stderr)
        return 1
    print(text, end="")
    return status


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:], os.environ))
