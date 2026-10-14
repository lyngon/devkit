#!/usr/bin/env python3
"""Run the eval suite at a base commit and in the working tree, and print each case's score at both.

The base commit is checked out into a detached worktree in a temporary
directory. Both runs are `claude plugin eval .` from the root of their
checkout: a model call on the account of whoever runs this, with the report
kept off claude.ai and no baseline arm. A case that seeds its working
directory does so with a script of its own, which runs as whoever runs this,
at both commits. The worktree and everything a run writes are removed again.
Exits 0 when it prints a comparison, whatever the scores are, since a red
case at the base commit is the point. The status says that there is a
comparison to read and nothing about what it is worth. The comparison says
that itself: a tool that a suite lacked, an error that ended a run of a
case, a case that the commit has and its suite gave no result for, a case
file that a suite failed to load, and a suite that the harness cut short.
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
    """The cases of one run of the suite, by their directory, what the run cost, the
    harness's reason when it cut the suite short, and what it said about each case file
    that it failed to load."""

    cases: ct.Mapping[str, Case]
    cost_usd: float
    cut_short_reason: str | None
    load_failures: tuple[str, ...]


@dataclasses.dataclass(frozen=True, slots=True)
class Column:
    """One column of the table: the side it stands for, the result of the run at that
    commit, and the cases present at the commit that the run gave no result for.

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


def value(text: str) -> str:
    """A value of an option that reaches `claude plugin eval`, as it stands.

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
        raise argparse.ArgumentTypeError(f"a value cannot open or end with white space: '{text}'")
    if text.startswith("-"):
        raise argparse.ArgumentTypeError(f"a value cannot start with a dash: '{text}'")
    return text


def number(text: str) -> str:
    """A number of runs, as the digits that the harness gets in its place.

    The digits can differ from the text, which may open with white space.
    Raises ValueError for text that is no whole number, and
    argparse.ArgumentTypeError for a number below 1, since no comparison has
    fewer runs. Both are usage errors.
    """
    runs = int(text)
    if runs < 1:
        raise argparse.ArgumentTypeError(f"a number of runs must be 1 or more: '{text}'")
    return str(runs)


def parse_arguments(arguments: ct.Sequence[str]) -> Options:
    """Read the command line. The options that reach `claude plugin eval` are named here, and
    each of their values names a case, a model, a tool or a number of runs, so that no word of
    the command line can publish a report, move the result this program reads, or leave the
    harness to guess what an empty word means."""
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
        eval_options += ["--runs", parsed.runs]
    if parsed.model is not None:
        eval_options += ["--model", parsed.model]
    if parsed.allow_tools:
        eval_options += ["--allow-tools", *parsed.allow_tools]
    return Options(base=parsed.base, granted=tuple(parsed.allow_tools), eval_options=tuple(eval_options))


def git(directory: pathlib.Path, *arguments: str) -> subprocess.CompletedProcess[str]:
    """Run git in a directory and hand back its exit status and output, without raising."""
    return subprocess.run(["git", "-C", str(directory), *arguments], capture_output=True, text=True, check=False)


def commit_of(root: pathlib.Path, revision: str) -> str | None:
    """The hash of the commit that a revision names, or None when it names none, such as a
    file. The revision is resolved before it is peeled to a commit, since after `:/` a
    suffix such as `^{commit}` would become part of the text that git searches for."""
    named = git(root, "rev-parse", "--verify", "--quiet", "--end-of-options", revision)
    if named.returncode != 0:
        return None
    peeled = git(root, "rev-parse", "--verify", "--quiet", f"{named.stdout.strip()}^{{commit}}")
    return peeled.stdout.strip() if peeled.returncode == 0 else None


def commit_has_case(root: pathlib.Path, commit: str, directory: str) -> bool:
    """Whether the commit holds a case in the directory, a path from the root. A case is a
    directory with a `prompt.md`, as the README defines one."""
    return git(root, "cat-file", "-e", f"{commit}:{directory}/prompt.md").returncode == 0


def working_tree_has_case(root: pathlib.Path, directory: str) -> bool:
    """The same for the working tree, which counts as head with its uncommitted changes."""
    return (root / directory / "prompt.md").is_file()


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
        if found_no_case(progress, run.returncode):
            load_failures = load_failures_in(checkout, progress)
            return Result(cases={}, cost_usd=0.0, cut_short_reason=None, load_failures=load_failures)
        raise CompareError(f"the eval run at {side} wrote no result (claude exited with status {run.returncode})")
    try:
        data = json.loads(result.read_text())
    except json.JSONDecodeError as error:
        raise CompareError(f"the result at {side} is not JSON: {error}") from error
    return parse_result(data, side, progress, load_failures_in(checkout, progress))


def found_no_case(progress: ct.Iterable[str], status: int) -> bool:
    """Whether a run that wrote no result said that its suite has no case, or none that the
    filter matches and that loads.

    The harness writes no result then, as it does when it dies, and only its
    words and its exit status tell the two apart (measured on Claude Code
    2.1.283). It exits with status 1 and says `No eval cases found`, unless a
    case file failed to load: then it prints the summary of a suite in which
    no case ran, which opens with `0 case(s)`. A suite that it ended before
    its first case finished prints that summary too, marked partial, and
    exits with another status. When the words change, a commit without a
    case counts as a run that died.
    """
    return status == 1 and any(line.startswith(("No eval cases found", "0 case(s) ")) for line in progress)


def notes_about(name: str, progress: ct.Iterable[str]) -> tuple[str, ...]:
    """What the run said about a case as a whole, in the harness's own words.

    These are its lines that open with two spaces, the name of the case and a
    colon (measured on Claude Code 2.1.283), which is how it names a gated
    tool that the case lists and the run did not grant. None of the words that
    follow are read, so a line that the harness words anew is still found.
    """
    opening = f"  {name}: "
    return tuple(line.removeprefix(opening) for line in progress if line.startswith(opening))


def load_failures_in(checkout: pathlib.Path, progress: ct.Iterable[str]) -> tuple[str, ...]:
    """What the run said about each case file of the checkout that it failed to load, in the
    harness's words from the path of the case on, which is given from the root.

    The harness leaves such a case out of its result and names it in a line
    of its own: a cross, a space, the absolute path without symbolic links of
    the directory of the case, or of its case.yaml where it has one, a colon
    and the error (measured on Claude Code 2.1.283). The checkout of the base
    commit is gone when the comparison is read, so the path of the checkout
    is dropped. None of the words after it are read.
    """
    opening = f"✗ {checkout.resolve()}/"
    return tuple(line.removeprefix(opening) for line in progress if line.startswith(opening))


def parse_result(data: object, side: str, progress: ct.Sequence[str], load_failures: tuple[str, ...]) -> Result:
    """Turn the result that `claude plugin eval` wrote, what it said about each case in its
    progress and what it said about each case file that it failed to load into a Result, or
    raise CompareError when the result has another shape than the one this program was written
    against."""
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
        return Result(
            cases=parsed,
            cost_usd=float(data["costUsd"]),
            cut_short_reason=str(data["partialReason"]) if data["partial"] else None,
            load_failures=load_failures,
        )
    except (KeyError, TypeError, ValueError) as error:
        raise CompareError(f"the result at {side} holds a field this program cannot read: {error!r}") from error


def counted(number: int, noun: str) -> str:
    """A number with its noun, in the plural unless the number is 1."""
    return f"{number} {noun}" if number == 1 else f"{number} {noun}s"


def cell(column: Column, name: str) -> str:
    """One cell of the table: the score of the case with the number of runs behind it, how
    many notes the harness left about the case and how many of the runs ended in an error.
    A case that the run gave no result for has the words `no result` when it is present at
    the commit, and a dash when it is not."""
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
    """What stands behind a score: what the harness said about the case, each distinct
    run error, and each grader that failed with the number of runs it failed in."""
    return [
        *case.notes,
        *(f"run error: {error}" for error in dict.fromkeys(case.errors)),
        *(f"grader {name} failed in {count} of {case.runs} runs" for name, count in case.failed_graders.items()),
    ]


def about_suite(side: str, result: Result) -> list[str]:
    """What the run at a commit said about its suite as a whole: each case file that it failed
    to load, and the reason it was cut short. Either leaves a case without a result."""
    run = f"the eval run at {side}"
    lines = [f"{run} failed to load {failure}" for failure in result.load_failures]
    if result.cut_short_reason is not None:
        lines.append(f"{run} was cut short ({result.cut_short_reason}): the table may lack cases")
    return lines


def report(base: Column, head: Column) -> list[str]:
    """The table of every case that either run gave a result for, what each run said about
    its suite as a whole, what stands behind each score, and what the two runs cost."""
    columns = (base, head)
    names = sorted(base.result.cases.keys() | head.result.cases.keys())
    rows = [("case", base.side, head.side), *((name, cell(base, name), cell(head, name)) for name in names)]
    widths = [max(len(row[index]) for row in rows) for index in range(3)]
    lines = ["  ".join(text.ljust(width) for text, width in zip(row, widths, strict=True)).rstrip() for row in rows]
    about_suites = [line for column in columns for line in about_suite(column.side, column.result)]
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


def compare(options: Options) -> list[str]:
    """Run the suite at the base commit and in the working tree, and return the lines to print.

    Raises CompareError outside a git repository, for a base that names no
    commit, without `claude` on the PATH, when a run writes no readable
    result, when no case ran at either commit, with what each run said about
    its suite, and when the head result names a case that the working tree
    does not hold. The cases are looked up by the paths that the results
    give, so a path in another form would bring back the dash for a case that
    did not run.
    """
    toplevel = git(pathlib.Path.cwd(), "rev-parse", "--show-toplevel")
    if toplevel.returncode != 0:
        raise CompareError("not inside a git repository")
    root = pathlib.Path(toplevel.stdout.strip())
    base_commit = commit_of(root, options.base)
    if base_commit is None:
        raise CompareError(f"'{options.base}' names no commit")
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
        why = [*about_suite("base", base), *about_suite("head", head)]
        raise CompareError("\n".join(["no eval case ran at either commit", *why]))
    for name in head.cases:
        if not working_tree_has_case(root, name):
            raise CompareError(f"the result at head names the case {name}, which holds no prompt.md in the working tree")
    only_base, only_head = base.cases.keys() - head.cases.keys(), head.cases.keys() - base.cases.keys()
    return [
        f"base: {base_commit}" + ("" if options.base == base_commit else f" ({options.base})"),
        f"head: {head_commit}" + (" with uncommitted changes" if uncommitted else ""),
        f"granted tools: {', '.join(options.granted) or 'none'}",
        "",
        *report(
            Column("base", base, frozenset(name for name in only_head if commit_has_case(root, base_commit, name))),
            Column("head", head, frozenset(name for name in only_base if working_tree_has_case(root, name))),
        ),
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
