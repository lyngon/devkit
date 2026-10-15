#!/usr/bin/env python3
"""Run the eval suite at a base commit and in the working tree, and print each case's score at both.

The base commit is checked out into a clone in a temporary directory, which
borrows the objects of this repository. Both runs are `claude plugin eval .`
from the root of their checkout: a model call on the account of whoever runs
this, with the report kept off claude.ai and no baseline arm. The run at the
base commit starts with `devenv shell`, so it gets the commands of that
commit's environment, and the run in the working tree keeps the devenv shell
that this program starts from. A case that seeds its working directory does
so with a script of its own, which runs as whoever runs this, at both
commits. The clone and everything a run writes are removed again.
Exits 0 when it prints a comparison, whatever the scores are, since a red
case at the base commit is the point. The status says that there is a
comparison to read and nothing about what it is worth. The comparison says
that itself: a tool that a suite lacked, an error that ended a run of a
case, a case that the commit has and its suite gave no result for, a case
file that a suite failed to load, a grant that the harness refused, and a
suite that the harness cut short. When the run in the working tree gives no
result after the run at the base commit gave one, it prints the table of the
base run, which was paid for, and exits 1, since there is no comparison.
"""

import argparse
import collections.abc as ct
import dataclasses
import json
import os
import pathlib
import shutil
import signal
import subprocess
import sys
import tempfile
import typing as t


class CompareError(Exception):
    """A comparison that cannot be made. The message is what the operator reads."""


@dataclasses.dataclass(frozen=True, slots=True)
class Said:
    """What a run said about its suite as a whole, in the harness's words.

    That is each case file that it failed to load and each entry of
    `--allow-tools` that it refused to grant. The harness says these before
    any case runs, so a run that gives no result has said them too.
    """

    load_failures: tuple[str, ...]
    grant_refusals: tuple[str, ...]


class RunError(CompareError):
    """A run that gave no result that this program can read, with what it said before that."""

    def __init__(self, message: str, said: Said) -> None:
        super().__init__(message)
        self.said: Said = said


@dataclasses.dataclass(frozen=True, slots=True)
class Options:
    """What the operator asked for.

    That is the base commit, the gated tools that both runs ask the harness
    to grant, and the options both runs get, that grant among them.
    """

    base: str
    granted: tuple[str, ...]
    eval_options: tuple[str, ...]


@dataclasses.dataclass(frozen=True, slots=True)
class Case:
    """What one eval case did at one commit.

    The notes are what the harness said about the case as a whole, such as a
    gated tool that the case lists and the run did not grant. A grader that
    expects that something did not happen cannot fail in such a run, so the
    score alone is no proof. A run the harness refused or cut short adds its
    reason to the errors, and still counts in the score. A grader that failed
    is listed with the number of runs it failed in, in the order the case
    declares its graders.
    """

    score: float
    runs: int
    notes: tuple[str, ...]
    errors: tuple[str, ...]
    failed_graders: ct.Mapping[str, int]


@dataclasses.dataclass(frozen=True, slots=True)
class Result:
    """The result of one run of the suite.

    That is its cases by their directory, what the run cost, the harness's
    reason when it cut the suite short, and what the run said about its suite.
    """

    cases: ct.Mapping[str, Case]
    cost_usd: float
    cut_short_reason: str | None
    said: Said


@dataclasses.dataclass(frozen=True, slots=True)
class Column:
    """One column of the table.

    It holds the side it stands for, the result of the run at that commit,
    and the cases present at the commit that the run gave no result for.

    A result does not say why it lacks a case. A suite that was cut short
    leaves out each case that it did not reach, a suite leaves out each case
    whose file it failed to load, and no result holds a case that the commit
    does not have. The files of the commit tell the last from the others.
    Only the cases that the other run gave a result for are looked up, since
    the program knows of no other.
    """

    side: str
    result: Result
    present: frozenset[str]


@dataclasses.dataclass(frozen=True, slots=True)
class Comparison:
    """What the program prints.

    That is the lines of the comparison on stdout, and the reason there is
    none on stderr. When the run in the working tree gave no result after the
    run at the base commit gave one, the lines hold the table of the base run,
    which was paid for, and below it what the other run said and the reason.
    """

    lines: tuple[str, ...]
    error: str | None


def value(text: str) -> str:
    """Return a value of an option that reaches `claude plugin eval`, as it stands.

    The harness gets each value as a word of its own, and could read one that
    starts with a dash as an option. No case, model or tool is named by an
    empty word, by one that opens or ends with white space, or by one that
    starts with a dash, so such a value raises argparse.ArgumentTypeError,
    which makes it a usage error. A comparison then never depends on what the
    harness makes of a value that names nothing, such as the empty word that
    `--model=$MODEL` gives where the variable is not set.
    """
    if not text:
        raise argparse.ArgumentTypeError("a value cannot be empty")
    if text != text.strip():
        raise argparse.ArgumentTypeError(f"a value cannot open or end with white space: {text!r}")
    if text.startswith("-"):
        raise argparse.ArgumentTypeError(f"a value cannot start with a dash: {text!r}")
    return text


def number(text: str) -> str:
    """Return a number of runs as the digits that the harness gets in its place.

    The digits can differ from the text, which may open with white space.
    Raises ValueError for text that is no whole number, and
    argparse.ArgumentTypeError for a number below 1, since no comparison has
    fewer runs. Both are usage errors.
    """
    runs = int(text)
    if runs < 1:
        raise argparse.ArgumentTypeError(f"a number of runs must be 1 or more: {text!r}")
    return str(runs)


def parse_arguments(arguments: ct.Sequence[str]) -> Options:
    """Read the command line.

    The options that reach `claude plugin eval` are named here, and each of
    their values can name a case, a model, a tool or a number of runs, so
    that no word of the command line can publish a report, move the result
    this program reads, or leave the harness to guess what an empty word
    means.
    """
    parser = argparse.ArgumentParser(
        prog="compare-evals",
        # The base comes first: the list of tools takes every word that follows it.
        usage="%(prog)s base [-h] [--case GLOB] [--runs N] [--model MODEL] [--allow-tools TOOL [TOOL ...]]",
        description=(
            "Run the eval suite at a base commit and in the working tree, "
            "and print each case's score at both. Every run is a model call on your account, "
            "and a case that seeds its working directory runs its script as you, at both commits."
        ),
    )
    _ = parser.add_argument("base", help="the commit to compare the working tree with, such as origin/main")
    _ = parser.add_argument("--case", type=value, metavar="GLOB", help="run only the cases whose name matches")
    _ = parser.add_argument(
        "--runs", type=number, metavar="N", help="runs per case, in place of each case's own number"
    )
    _ = parser.add_argument("--model", type=value, help="the model for every case, in place of each case's own")
    _ = parser.add_argument(
        "--allow-tools",
        action="extend",
        nargs="+",
        type=value,
        default=[],
        metavar="TOOL",
        help="grant gated tools, such as Write, to every case",
    )
    parsed = parser.parse_args(arguments)
    # A namespace types every value as Any; argparse has run each given one through its type.
    base = t.cast("str", parsed.base)
    case = t.cast("str | None", parsed.case)
    runs = t.cast("str | None", parsed.runs)
    model = t.cast("str | None", parsed.model)
    allow_tools = t.cast("list[str]", parsed.allow_tools)
    eval_options: list[str] = []
    if case is not None:
        eval_options += ["--case", case]
    if runs is not None:
        eval_options += ["--runs", runs]
    if model is not None:
        eval_options += ["--model", model]
    if allow_tools:
        eval_options += ["--allow-tools", *allow_tools]
    return Options(base=base, granted=tuple(allow_tools), eval_options=tuple(eval_options))


def git(directory: pathlib.Path, *arguments: str) -> subprocess.CompletedProcess[str]:
    """Run git in a directory and hand back its exit status and output, without raising."""
    return subprocess.run(["git", "-C", str(directory), *arguments], capture_output=True, text=True, check=False)


def commit_of(root: pathlib.Path, revision: str) -> str | None:
    """Return the hash of the commit that a revision names, or None when it names none, such as a file.

    The revision is resolved before it is peeled to a commit, since after
    `:/` a suffix such as `^{commit}` would become part of the text that git
    searches for.
    """
    named = git(root, "rev-parse", "--verify", "--quiet", "--end-of-options", revision)
    if named.returncode != 0:
        return None
    peeled = git(root, "rev-parse", "--verify", "--quiet", f"{named.stdout.strip()}^{{commit}}")
    return peeled.stdout.strip() if peeled.returncode == 0 else None


def commit_has_case(root: pathlib.Path, commit: str, directory: str) -> bool:
    """Whether the commit holds a case in the directory, a path from the root.

    A case is a directory with a `prompt.md`, as the README defines one.
    """
    return git(root, "cat-file", "-e", f"{commit}:{directory}/prompt.md").returncode == 0


def working_tree_has_case(root: pathlib.Path, directory: str) -> bool:
    """Whether the working tree holds a case in the directory; it counts as head with its uncommitted changes."""
    return (root / directory / "prompt.md").is_file()


def clone_of(root: pathlib.Path, commit: str, path: pathlib.Path) -> pathlib.Path:
    """Check out the commit at the path, in a repository of its own, and return the path.

    The repository borrows the objects of the root's, and goes with the
    directory that holds it.

    Entering the environment of the commit writes its git hook shims into the
    hooks of the repository that holds the checkout. Before 7e4605f the
    baseline had them name the checkout by its absolute path, so in a
    worktree of the root's repository they would outlive the checkout and
    fail every commit of the root's clone. In a repository of its own they go
    with it.
    """
    cloned = subprocess.run(
        ["git", "clone", "--quiet", "--shared", "--no-checkout", "--", str(root), str(path)],
        capture_output=True,
        text=True,
        check=False,
    )
    checked = git(path, "checkout", "--quiet", "--detach", commit) if cloned.returncode == 0 else cloned
    if checked.returncode != 0:
        raise CompareError(f"cannot check out {commit}: {checked.stderr.strip()}")
    return path


def without_nix_shell(environment: ct.Mapping[str, str]) -> dict[str, str]:
    """Return the environment with the entries of its PATH that lie in the Nix store left out.

    A Nix shell, such as the devenv shell of the working tree that this
    program starts from, puts the directories of its commands in the store,
    and the system keeps its own in profiles outside it. A run that enters the
    environment of another commit then finds that commit's commands and the
    system's, and none that only the working tree has.
    """
    store = environment.get("NIX_STORE", "/nix/store").rstrip("/") + "/"
    kept = [entry for entry in environment.get("PATH", "").split(os.pathsep) if not entry.startswith(store)]
    return {**environment, "PATH": os.pathsep.join(kept)}


@dataclasses.dataclass(frozen=True, slots=True)
class Launcher:
    """How a run starts the harness.

    That is the words in front of its options, what an error calls them, and
    the environment that the run starts in.
    """

    name: str
    words: tuple[str, ...]
    environment: ct.Mapping[str, str]


def run_suite(
    checkout: pathlib.Path, side: str, scratch: pathlib.Path, launcher: Launcher, eval_options: ct.Sequence[str]
) -> Result:
    """Run the suite of a checkout and read its result.

    The harness prints the progress of a run only when no `--json` names a
    file for the result, so the result is read from the output directory
    instead. All that the run prints goes to stderr as it comes. Without
    `--json` the harness also keeps the sandbox of a run that ended in an
    error, so the run gets a temporary directory inside the scratch directory
    and the sandbox goes with it.

    A run that found no case writes no result, and is read as a result
    without a case. Raises RunError, with what the run said about its suite,
    when any other run writes no result that this program can read. The exit
    status of `claude` alone does not decide that: it is 1 for a case below
    the threshold too.
    """
    output, temporary = scratch / side, scratch / "tmp"
    temporary.mkdir(exist_ok=True)
    command = [*launcher.words, "plugin", "eval", ".", "--output-dir", str(output)]
    command += ["--no-publish", "--ablation", "none", "--trust-plugin", "--scaffold", *eval_options]
    print(f"compare-evals: running the suite at {side}", file=sys.stderr)
    progress: list[str] = []
    with subprocess.Popen(
        command,
        cwd=checkout,
        env={**launcher.environment, "TMPDIR": str(temporary)},
        stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        encoding="utf-8",
        errors="replace",
        process_group=0,
    ) as run:
        try:
            # A pipe of text, which the type of the attribute cannot say.
            for line in t.cast("ct.Iterable[str]", run.stdout or ()):
                print(line, end="", file=sys.stderr)
                progress.append(line.rstrip("\n"))
        except BaseException:  # an interrupt too: no process of the run may outlive the scratch directory
            os.killpg(run.pid, signal.SIGKILL)
            raise
    said = Said(load_failures_in(checkout, progress), grant_refusals_in(progress))
    result = output / "aggregate-result.json"
    data: object
    if result.is_file():
        try:
            data = t.cast("object", json.loads(result.read_text()))
        except json.JSONDecodeError as error:
            raise RunError(f"the result at {side} is not JSON: {error}", said) from error
    elif found_no_case(progress, run.returncode):
        data = {"cases": [], "costUsd": 0.0, "partial": False}
    else:
        status = f"{launcher.name} exited with status {run.returncode}"
        raise RunError(f"the eval run at {side} wrote no result ({status})", said)
    return parse_result(data, side, progress, said)


def found_no_case(progress: ct.Iterable[str], status: int) -> bool:
    """Whether a run that wrote no result said that it found no case.

    That is no case in its suite, or none that the filter matches and that
    loads. The harness writes no result then, as it does when it dies, and
    only its words and its exit status tell the two apart (measured on Claude
    Code 2.1.283). It exits with status 1 and says `No eval cases found`,
    unless a case file failed to load: then it prints the summary of a suite
    in which no case ran, which opens with `0 case(s)`. A suite that it ended
    before its first case finished prints that summary too, marked partial,
    and exits with another status. When the words change, a commit without a
    case counts as a run that died.
    """
    return status == 1 and any(line.startswith(("No eval cases found", "0 case(s) ")) for line in progress)


def notes_about(name: str, progress: ct.Iterable[str]) -> tuple[str, ...]:
    """Return what the run said about a case as a whole, in the harness's own words.

    These are its lines that open with two spaces, the name of the case and a
    colon (measured on Claude Code 2.1.283), which is how it names a gated
    tool that the case lists and the run did not grant. None of the words that
    follow are read, so a line that the harness words anew is still found.
    """
    opening = f"  {name}: "
    return tuple(line.removeprefix(opening) for line in progress if line.startswith(opening))


def load_failures_in(checkout: pathlib.Path, progress: ct.Iterable[str]) -> tuple[str, ...]:
    """Return what the run said about each case file of the checkout that it failed to load.

    The words are the harness's from the path of the case on, which is given
    from the root.

    The harness leaves such a case out of its result and names it in a line
    of its own: a cross, a space, the absolute path without symbolic links of
    the directory of the case, or of its case.yaml where it has one, a colon
    and the error (measured on Claude Code 2.1.283). The checkout of the base
    commit is gone when the comparison is read, so the path of the checkout
    is dropped. None of the words after it are read.
    """
    opening = f"✗ {checkout.resolve()}/"
    return tuple(line.removeprefix(opening) for line in progress if line.startswith(opening))


def grant_refusals_in(progress: ct.Iterable[str]) -> tuple[str, ...]:
    """Return what the run said about each entry of `--allow-tools` that it refused to grant.

    The words are the harness's from the option on.

    The harness names such an entry in a line of its own that opens with a
    cross, a space and `--allow-tools:`, and the runs go on without the tool
    (measured on Claude Code 2.1.283). None of the words after the option are
    read.
    """
    opening = "✗ --allow-tools: "
    return tuple(line.removeprefix("✗ ") for line in progress if line.startswith(opening))


def json_field(value: object, key: str) -> object:
    """Return the member of a JSON object under the key, as indexing the object does.

    Raises KeyError for a key that the object lacks, and TypeError for a value that is no object.
    """
    if not isinstance(value, dict):
        raise TypeError(f"a {type(value).__name__} where an object belongs")
    # The keys of a JSON object are strings.
    return t.cast("dict[str, object]", value)[key]


def json_array(value: object) -> list[object]:
    """Return the items of a JSON array. Raises TypeError for a value that is no array."""
    if not isinstance(value, list):
        raise TypeError(f"a {type(value).__name__} where an array belongs")
    return t.cast("list[object]", value)


def json_number(value: object) -> float:
    """Return a JSON number, or a string of one, as float() reads it.

    Raises TypeError for a value of another type, and ValueError for a string that is no number.
    """
    if not isinstance(value, int | float | str):
        raise TypeError(f"a {type(value).__name__} where a number belongs")
    return float(value)


def parse_result(data: object, side: str, progress: ct.Sequence[str], said: Said) -> Result:
    """Turn what a run of `claude plugin eval` wrote and said into a Result.

    That is the result it wrote, what it said about each case in its progress
    and what it said about its suite. The result is narrowed here, once.
    Raises RunError when it has another shape than the one this program was
    written against.
    """
    if not isinstance(data, dict):
        raise RunError(f"the result at {side} is not a JSON object", said)
    # The keys of a JSON object are strings.
    fields = t.cast("dict[str, object]", data)
    cases = fields.get("cases")
    if not isinstance(cases, list):
        schema = fields.get("schemaVersion")
        raise RunError(f"the result at {side} has no list 'cases' (schemaVersion {schema})", said)
    parsed: dict[str, Case] = {}
    try:
        for entry in t.cast("list[object]", cases):
            runs = json_array(json_field(json_field(entry, "arms"), "with"))
            verdicts = [
                (str(json_field(grader, "name")), bool(json_field(grader, "passed")))
                for run in runs
                for grader in json_array(json_field(run, "graders"))
            ]
            failures = {name: verdicts.count((name, False)) for name, _ in verdicts}
            parsed[str(json_field(entry, "dir"))] = Case(
                score=json_number(json_field(json_field(entry, "aggregates"), "score")),
                runs=len(runs),
                notes=notes_about(str(json_field(entry, "name")), progress),
                errors=tuple(str(json_field(run, "error")) for run in runs if json_field(run, "error") is not None),
                failed_graders={name: count for name, count in failures.items() if count > 0},
            )
        return Result(
            cases=parsed,
            cost_usd=json_number(json_field(fields, "costUsd")),
            cut_short_reason=str(json_field(fields, "partialReason")) if json_field(fields, "partial") else None,
            said=said,
        )
    except (KeyError, TypeError, ValueError) as error:
        raise RunError(f"the result at {side} holds a field this program cannot read: {error!r}", said) from error


def counted(number: int, noun: str) -> str:
    """Return a number with its noun, in the plural unless the number is 1."""
    return f"{number} {noun}" if number == 1 else f"{number} {noun}s"


def cell(column: Column, name: str) -> str:
    """Return one cell of the table.

    It holds the score of the case with the number of runs behind it, how
    many notes the harness left about the case and how many of the runs ended
    in an error. A case that the run gave no result for has the words
    `no result` when it is present at the commit, and a dash when it is not.
    """
    case = column.result.cases.get(name)
    if case is None:
        return "no result" if name in column.present else "-"
    counts = [counted(case.runs, "run")]
    if case.notes:
        counts.append(counted(len(case.notes), "note"))
    if case.errors:
        counts.append(counted(len(case.errors), "error"))
    return f"{case.score:.2f} ({', '.join(counts)})"


def reasons(case: Case) -> list[str]:
    """Return what stands behind a score.

    That is what the harness said about the case, each distinct run error,
    and each grader that failed with the number of runs it failed in.
    """
    return [
        *case.notes,
        *(f"run error: {error}" for error in dict.fromkeys(case.errors)),
        *(f"grader {name} failed in {count} of {case.runs} runs" for name, count in case.failed_graders.items()),
    ]


def about_suite(side: str, said: Said, cut_short_reason: str | None = None) -> list[str]:
    """Return what the run at a commit said about its suite as a whole.

    That is each case file that it failed to load, each entry of
    `--allow-tools` that it refused to grant, and the reason it was cut
    short. The first and the last leave a case without a result, and a
    refused grant leaves a run without a tool that the header names.
    """
    run = f"the eval run at {side}"
    lines = [f"{run} failed to load {failure}" for failure in said.load_failures]
    lines += [f"{run} said {refusal}" for refusal in said.grant_refusals]
    if cut_short_reason is not None:
        lines.append(f"{run} was cut short ({cut_short_reason}): the table may lack cases")
    return lines


def report(columns: ct.Sequence[Column], without_result: ct.Sequence[str] = ()) -> list[str]:
    """Return the lines of the report.

    They are the table of every case that a run gave a result for, with a
    column for each run, what each run said about its suite as a whole, the
    lines about a run that gave no result, what stands behind each score, and
    what the runs that gave a result cost.
    """
    names = sorted({name for column in columns for name in column.result.cases})
    header = ("case", *(column.side for column in columns))
    rows = [header, *((name, *(cell(column, name) for column in columns)) for name in names)]
    widths = [max(len(row[index]) for row in rows) for index in range(len(header))]
    lines = ["  ".join(text.ljust(width) for text, width in zip(row, widths, strict=True)).rstrip() for row in rows]
    about_suites = [
        *(line for c in columns for line in about_suite(c.side, c.result.said, c.result.cut_short_reason)),
        *without_result,
    ]
    behind = [
        f"{name} at {column.side}: {reason}"
        for name in names
        for column in columns
        if (case := column.result.cases.get(name)) is not None
        for reason in reasons(case)
    ]
    for block in (about_suites, behind):
        if block:
            lines += ["", *block]
    costs = ", ".join(f"{column.side} {column.result.cost_usd:.2f} USD" for column in columns)
    return [*lines, "", f"cost: {costs}"]


def working_tree_root() -> pathlib.Path:
    """Return the root of the working tree that this program runs in.

    Raises CompareError outside a git repository, and outside the devenv
    shell of the working tree.
    """
    toplevel = git(pathlib.Path.cwd(), "rev-parse", "--show-toplevel")
    if toplevel.returncode != 0:
        raise CompareError("not inside a git repository")
    root = pathlib.Path(toplevel.stdout.strip())
    shell = os.environ.get("DEVENV_ROOT")
    if not shell or pathlib.Path(shell).resolve() != root.resolve():
        where = f"the devenv shell of {shell}" if shell else "a shell without devenv"
        raise CompareError(f"start compare-evals from the devenv shell of the working tree {root}, not from {where}")
    return root


def launchers() -> tuple[Launcher, Launcher]:
    """Return how the run at the base commit and the run in the working tree start the harness.

    Both runs start the same harness. The base run enters the environment of
    the base commit, and the head run keeps the one it was started from, the
    working tree's. Raises CompareError without `claude` or `devenv` on the
    PATH.
    """
    claude, devenv = shutil.which("claude"), shutil.which("devenv")
    if claude is None:
        raise CompareError("claude is not on the PATH")
    if devenv is None:
        raise CompareError("devenv is not on the PATH")
    at_base = Launcher("devenv shell", (devenv, "shell", "--", claude), without_nix_shell(os.environ))
    at_head = Launcher("claude", (claude,), os.environ)
    return at_base, at_head


def compare(options: Options) -> Comparison:
    """Run the suite at the base commit and in the working tree, and return what to print.

    The run at the base commit enters that commit's environment, and the run
    in the working tree keeps the one this program starts in, which must be
    the devenv shell of the working tree. When the run in the working tree
    writes no result that this program can read after the base run gave one,
    the comparison holds the table of the base run, which was paid for, and
    below it what the other run said and the reason.

    Raises CompareError outside a git repository, outside the devenv shell of
    the working tree, for a base that names no commit, without `claude` or
    `devenv` on the PATH, when the base run writes no readable result, which
    spares the cost of the run in the working tree, and when no case ran at
    either commit, each with what the runs said about their suites. Raises it
    too when the head result names a case that the working tree does not
    hold. The cases are looked up by the paths that the results give, so such
    a result means that the program reads the harness wrongly, and no table
    it prints, the base column included, could be trusted.
    """
    root = working_tree_root()
    base_commit = commit_of(root, options.base)
    if base_commit is None:
        raise CompareError(f"'{options.base}' names no commit")
    at_base, at_head = launchers()
    head_commit = git(root, "rev-parse", "HEAD").stdout.strip()
    uncommitted = git(root, "status", "--porcelain").stdout.strip() != ""
    header = (
        f"base: {base_commit}" + ("" if options.base == base_commit else f" ({options.base})"),
        f"head: {head_commit}" + (" with uncommitted changes" if uncommitted else ""),
        f"granted tools: {', '.join(options.granted) or 'none'}",
        "",
    )

    with tempfile.TemporaryDirectory(prefix="compare-evals-") as directory:
        scratch = pathlib.Path(directory)
        checkout = clone_of(root, base_commit, scratch / "checkout")
        try:
            base = run_suite(checkout, "base", scratch, at_base, options.eval_options)
        except RunError as error:
            raise CompareError("\n".join([str(error), *about_suite("base", error.said)])) from error
        try:
            head = run_suite(root, "head", scratch, at_head, options.eval_options)
        except RunError as error:
            base_said = about_suite("base", base.said, base.cut_short_reason)
            if not base.cases:
                raise CompareError("\n".join([str(error), *base_said, *about_suite("head", error.said)])) from error
            without_result = [*about_suite("head", error.said), str(error)]
            return Comparison((*header, *report([Column("base", base, frozenset())], without_result)), str(error))
    if not base.cases and not head.cases:
        why = [
            *about_suite("base", base.said, base.cut_short_reason),
            *about_suite("head", head.said, head.cut_short_reason),
        ]
        raise CompareError("\n".join(["no eval case ran at either commit", *why]))
    for name in head.cases:
        if not working_tree_has_case(root, name):
            raise CompareError(
                f"the result at head names the case {name}, which holds no prompt.md in the working tree",
            )
    only_base, only_head = base.cases.keys() - head.cases.keys(), head.cases.keys() - base.cases.keys()
    columns = [
        Column("base", base, frozenset(name for name in only_head if commit_has_case(root, base_commit, name))),
        Column("head", head, frozenset(name for name in only_base if working_tree_has_case(root, name))),
    ]
    return Comparison((*header, *report(columns)), None)


def main(arguments: ct.Sequence[str]) -> int:
    """Print the comparison and return the exit status.

    The status is 0 for a comparison, and 1 for none, after the table of the
    base run when that run gave a result.
    """
    options = parse_arguments(arguments)
    try:
        comparison = compare(options)
    except CompareError as error:
        comparison = Comparison((), str(error))
    if comparison.lines:
        print("\n".join(comparison.lines), flush=True)
    if comparison.error is None:
        return 0
    print(f"compare-evals: {comparison.error}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
