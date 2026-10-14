#!/usr/bin/env python3
"""Run the eval suite at a base commit and in the working tree, and print each case's score at both.

The base commit is checked out into a detached worktree in a temporary
directory. Both runs are `claude plugin eval .` from the root of their
checkout: a model call on the account of whoever runs this, with the report
kept off claude.ai and no baseline arm. A case that seeds its working
directory does so with a script of its own, which runs as whoever runs this,
at both commits. The worktree and everything a run writes are removed again.
Exits 0 when it prints a comparison, whatever the scores are, since a red
case at the base commit is the point.
"""

import argparse
import collections.abc as ct
import contextlib
import dataclasses
import json
import os
import pathlib
import shutil
import subprocess
import sys
import tempfile


class CompareError(Exception):
    """A comparison that cannot be made. The message is what the operator reads."""


@dataclasses.dataclass(frozen=True, slots=True)
class Options:
    """What the operator asked for: the base commit, the gated tools that both runs are
    granted, and the options both runs get, the grant among them."""

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
    """The cases of one run of the suite, by their directory, and what the run cost."""

    cases: ct.Mapping[str, Case]
    cost_usd: float


def value(text: str) -> str:
    """A value of an option that reaches `claude plugin eval`, as it stands.

    The harness gets each value as a word of its own, and could read one that
    starts with a dash as an option. No case, model, tool or number of runs
    starts with one, so such a value raises argparse.ArgumentTypeError, which
    makes it a usage error.
    """
    if text.startswith("-"):
        raise argparse.ArgumentTypeError(f"a value cannot start with a dash: '{text}'")
    return text


def number(text: str) -> int:
    """A value that is a whole number. Raises ValueError for any other text, which is a
    usage error as well."""
    return int(value(text))


def parse_arguments(arguments: ct.Sequence[str]) -> Options:
    """Read the command line. The options that reach `claude plugin eval` are named here, and
    none of their values starts with a dash, so that no word of the command line can publish a
    report or move the result this program reads."""
    parser = argparse.ArgumentParser(
        prog="compare-evals",
        # The base comes first: the list of tools takes every word that follows it.
        usage="%(prog)s base [-h] [--case GLOB] [--runs N] [--model MODEL] [--allow-tools TOOL [TOOL ...]]",
        description="Run the eval suite at a base commit and in the working tree, "
        "and print each case's score at both. Every run is a model call on your account, "
        "and a case that seeds its working directory runs its script as you, at both commits.",
    )
    parser.add_argument("base", help="the commit to compare the working tree with, such as origin/main")
    parser.add_argument("--case", type=value, metavar="GLOB", help="run only the cases whose name matches")
    parser.add_argument("--runs", type=number, metavar="N", help="runs per case, in place of each case's own number")
    parser.add_argument("--model", type=value, help="the model for every case, in place of each case's own")
    parser.add_argument(
        "--allow-tools",
        action="extend",
        nargs="+",
        type=value,
        default=[],
        metavar="TOOL",
        help="grant gated tools, such as Write, to every case",
    )
    parsed = parser.parse_args(arguments)
    eval_options: list[str] = []
    if parsed.case is not None:
        eval_options += ["--case", parsed.case]
    if parsed.runs is not None:
        eval_options += ["--runs", str(parsed.runs)]
    if parsed.model is not None:
        eval_options += ["--model", parsed.model]
    if parsed.allow_tools:
        eval_options += ["--allow-tools", *parsed.allow_tools]
    return Options(base=parsed.base, granted=tuple(parsed.allow_tools), eval_options=tuple(eval_options))


def git(directory: pathlib.Path, *arguments: str) -> subprocess.CompletedProcess[str]:
    """Run git in a directory and hand back its exit status and output, without raising."""
    return subprocess.run(["git", "-C", str(directory), *arguments], capture_output=True, text=True, check=False)


@contextlib.contextmanager
def checkout_of(root: pathlib.Path, commit: str, path: pathlib.Path) -> ct.Iterator[pathlib.Path]:
    """A detached worktree of the commit at the path, removed again on the way out."""
    added = git(root, "worktree", "add", "--detach", str(path), commit)
    if added.returncode != 0:
        raise CompareError(f"cannot check out {commit}: {added.stderr.strip()}")
    try:
        yield path
    finally:
        removed = git(root, "worktree", "remove", "--force", str(path))
        if removed.returncode != 0:
            print(f"compare-evals: cannot remove the worktree {path}: {removed.stderr.strip()}", file=sys.stderr)


def run_suite(checkout: pathlib.Path, side: str, scratch: pathlib.Path, eval_options: ct.Sequence[str]) -> Result:
    """Run the suite of a checkout and read its result.

    The harness prints the progress of a run only when no `--json` names a
    file for the result, so the result is read from the output directory
    instead. All that the run prints goes to stderr as it comes. Without
    `--json` the harness also keeps the sandbox of a run that ended in an
    error, so the run gets a temporary directory inside the scratch directory
    and the sandbox goes with it.

    Raises CompareError when the run writes no result this program can read,
    unless it found no case. The exit status of `claude` does not decide that:
    it is 1 for a case below the threshold too.
    """
    output, temporary = scratch / side, scratch / "tmp"
    temporary.mkdir(exist_ok=True)
    command = ["claude", "plugin", "eval", ".", "--output-dir", str(output)]
    command += ["--no-publish", "--ablation", "none", "--trust-plugin", "--scaffold", *eval_options]
    print(f"compare-evals: running the suite at {side}", file=sys.stderr)
    progress: list[str] = []
    with subprocess.Popen(
        command,
        cwd=checkout,
        env={**os.environ, "TMPDIR": str(temporary)},
        stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        encoding="utf-8",
        errors="replace",
    ) as run:
        try:
            for line in run.stdout or ():  # a pipe, which the type of the attribute cannot say
                print(line, end="", file=sys.stderr)
                progress.append(line.rstrip("\n"))
        except BaseException:  # an interrupt too: the run must not outlive the scratch directory
            run.kill()
            raise
    result = output / "aggregate-result.json"
    if not result.is_file():
        if found_no_case(progress):
            return Result(cases={}, cost_usd=0.0)
        raise CompareError(f"the eval run at {side} wrote no result (claude exited with status {run.returncode})")
    try:
        data = json.loads(result.read_text())
    except json.JSONDecodeError as error:
        raise CompareError(f"the result at {side} is not JSON: {error}") from error
    return parse_result(data, side, progress)


def found_no_case(progress: ct.Iterable[str]) -> bool:
    """Whether the run said that its suite has no case, or none that the filter matches.

    The harness then writes no result, as it does when it dies, and only its
    words tell the two apart (measured on Claude Code 2.1.283). When they
    change, a commit without a case counts as a run that died.
    """
    return any(line.startswith("No eval cases found") for line in progress)


def notes_about(name: str, progress: ct.Iterable[str]) -> tuple[str, ...]:
    """What the run said about a case as a whole, in the harness's own words.

    These are its lines that open with two spaces, the name of the case and a
    colon (measured on Claude Code 2.1.283), which is how it names a gated
    tool that the case lists and the run did not grant. None of the words that
    follow are read, so a line that the harness words anew is still found.
    """
    opening = f"  {name}: "
    return tuple(line.removeprefix(opening) for line in progress if line.startswith(opening))


def parse_result(data: object, side: str, progress: ct.Sequence[str]) -> Result:
    """Turn the result that `claude plugin eval` wrote, and what it said about each case in its
    progress, into a Result, or raise CompareError when the result has another shape than the one
    this program was written against."""
    if not isinstance(data, dict):
        raise CompareError(f"the result at {side} is not a JSON object")
    cases = data.get("cases")
    if not isinstance(cases, list):
        raise CompareError(f"the result at {side} has no list 'cases' (schemaVersion {data.get('schemaVersion')})")
    parsed: dict[str, Case] = {}
    try:
        for entry in cases:
            runs = entry["arms"]["with"]
            verdicts = [(str(grader["name"]), bool(grader["passed"])) for run in runs for grader in run["graders"]]
            failures = {name: verdicts.count((name, False)) for name, _ in verdicts}
            parsed[str(entry["dir"])] = Case(
                score=float(entry["aggregates"]["score"]),
                runs=len(runs),
                notes=notes_about(str(entry["name"]), progress),
                errors=tuple(str(run["error"]) for run in runs if run["error"] is not None),
                failed_graders={name: count for name, count in failures.items() if count > 0},
            )
        return Result(cases=parsed, cost_usd=float(data["costUsd"]))
    except (KeyError, TypeError, ValueError) as error:
        raise CompareError(f"the result at {side} holds a field this program cannot read: {error!r}") from error


def counted(number: int, noun: str) -> str:
    """A number with its noun, in the plural unless the number is 1."""
    return f"{number} {noun}" if number == 1 else f"{number} {noun}s"


def cell(case: Case | None) -> str:
    """One cell of the table: a dash for a case the commit does not have, otherwise the
    score with the number of runs behind it, how many notes the harness left about the
    case and how many of the runs ended in an error."""
    if case is None:
        return "-"
    counts = [counted(case.runs, "run")]
    if case.notes:
        counts.append(counted(len(case.notes), "note"))
    if case.errors:
        counts.append(counted(len(case.errors), "error"))
    return f"{case.score:.2f} ({', '.join(counts)})"


def reasons(case: Case) -> list[str]:
    """What stands behind a score: what the harness said about the case, each distinct
    run error, and each grader that failed with the number of runs it failed in."""
    return [
        *case.notes,
        *(f"run error: {error}" for error in dict.fromkeys(case.errors)),
        *(f"grader {name} failed in {count} of {case.runs} runs" for name, count in case.failed_graders.items()),
    ]


def report(base: Result, head: Result) -> list[str]:
    """The table of every case of either run, what stands behind each score, and what
    the two runs cost."""
    names = sorted(base.cases.keys() | head.cases.keys())
    rows = [("case", "base", "head"), *((name, cell(base.cases.get(name)), cell(head.cases.get(name))) for name in names)]
    widths = [max(len(row[column]) for row in rows) for column in range(3)]
    lines = ["  ".join(text.ljust(width) for text, width in zip(row, widths, strict=True)).rstrip() for row in rows]
    behind = [
        f"{name} at {side}: {reason}"
        for name in names
        for side, result in (("base", base), ("head", head))
        if (case := result.cases.get(name)) is not None
        for reason in reasons(case)
    ]
    if behind:
        lines += ["", *behind]
    return [*lines, "", f"cost: base {base.cost_usd:.2f} USD, head {head.cost_usd:.2f} USD"]


def compare(options: Options) -> list[str]:
    """Run the suite at the base commit and in the working tree, and return the lines to print.

    Raises CompareError outside a git repository, for a base that names no
    commit, without `claude` on the PATH, when a run writes no readable
    result, and when no case ran at either commit.
    """
    toplevel = git(pathlib.Path.cwd(), "rev-parse", "--show-toplevel")
    if toplevel.returncode != 0:
        raise CompareError("not inside a git repository")
    root = pathlib.Path(toplevel.stdout.strip())
    resolved = git(root, "rev-parse", "--verify", "--quiet", "--end-of-options", f"{options.base}^{{commit}}")
    if resolved.returncode != 0:
        raise CompareError(f"'{options.base}' names no commit")
    base_commit = resolved.stdout.strip()
    if shutil.which("claude") is None:
        raise CompareError("claude is not on the PATH")
    head_commit = git(root, "rev-parse", "HEAD").stdout.strip()
    uncommitted = git(root, "status", "--porcelain").stdout.strip() != ""

    with tempfile.TemporaryDirectory(prefix="compare-evals-") as directory:
        scratch = pathlib.Path(directory)
        with checkout_of(root, base_commit, scratch / "checkout") as checkout:
            base = run_suite(checkout, "base", scratch, options.eval_options)
        head = run_suite(root, "head", scratch, options.eval_options)
    if not base.cases and not head.cases:
        raise CompareError("no eval case ran at either commit")
    return [
        f"base: {base_commit}" + ("" if options.base == base_commit else f" ({options.base})"),
        f"head: {head_commit}" + (" with uncommitted changes" if uncommitted else ""),
        f"granted tools: {', '.join(options.granted) or 'none'}",
        "",
        *report(base, head),
    ]


def main(arguments: ct.Sequence[str]) -> int:
    """Print the comparison and return the exit status: 0 for a comparison, 1 for none."""
    options = parse_arguments(arguments)
    try:
        lines = compare(options)
    except CompareError as error:
        print(f"compare-evals: {error}", file=sys.stderr)
        return 1
    print("\n".join(lines))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
