#!/usr/bin/env python3
"""Run the eval suite at a base commit and in the working tree, and print each case's score at both.

The base commit is checked out into a detached worktree in a temporary
directory. Both runs are `claude plugin eval .` from the root of their
checkout: a model call on the account of whoever runs this, with the report
kept off claude.ai and no baseline arm. The worktree and everything a run
writes are removed again. Exits 0 when both runs wrote a result, whatever the
scores are, since a red case at the base commit is the point.
"""

import argparse
import collections.abc as ct
import contextlib
import dataclasses
import json
import pathlib
import shutil
import subprocess
import sys
import tempfile


class CompareError(Exception):
    """A comparison that cannot be made. The message is what the operator reads."""


@dataclasses.dataclass(frozen=True, slots=True)
class Options:
    """What the operator asked for: the base commit, and the options both runs get."""

    base: str
    eval_options: tuple[str, ...]


@dataclasses.dataclass(frozen=True, slots=True)
class Case:
    """What one eval case did at one commit. An error is the harness's reason for a run it refused."""

    score: float
    runs: int
    errors: tuple[str, ...]


@dataclasses.dataclass(frozen=True, slots=True)
class Result:
    """The cases of one run of the suite, by their directory, and what the run cost."""

    cases: ct.Mapping[str, Case]
    cost_usd: float


def parse_arguments(arguments: ct.Sequence[str]) -> Options:
    """Read the command line. The options that reach `claude plugin eval` are named here, so
    that none of them can publish a report or move the result this program reads."""
    parser = argparse.ArgumentParser(
        prog="compare-evals",
        description="Run the eval suite at a base commit and in the working tree, "
        "and print each case's score at both. Every run is a model call on your account.",
    )
    parser.add_argument("base", help="the commit to compare the working tree with, such as origin/main")
    parser.add_argument("--case", metavar="GLOB", help="run only the cases whose name matches")
    parser.add_argument(
        "--allow-tools", nargs="+", default=[], metavar="TOOL", help="grant gated tools that cases list, such as Write"
    )
    parser.add_argument("--runs", type=int, metavar="N", help="runs per case, in place of each case's own number")
    parser.add_argument("--model", help="the model for every case, in place of each case's own")
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
    return Options(base=parsed.base, eval_options=tuple(eval_options))


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

    The run's own output goes to stderr, and its report into the scratch
    directory. Raises CompareError when the run writes no result this program
    can read. The exit status of `claude` does not decide that: it is 1 for a
    case below the threshold too.
    """
    result = scratch / f"{side}.json"
    command = ["claude", "plugin", "eval", ".", "--json", str(result), "--output-dir", str(scratch / side)]
    command += ["--no-publish", "--ablation", "none", "--trust-plugin", *eval_options]
    print(f"compare-evals: running the suite at {side}", file=sys.stderr)
    done = subprocess.run(command, cwd=checkout, stdin=subprocess.DEVNULL, stdout=sys.stderr, check=False)
    if not result.is_file():
        raise CompareError(f"the eval run at {side} wrote no result (claude exited with status {done.returncode})")
    try:
        data = json.loads(result.read_text())
    except json.JSONDecodeError as error:
        raise CompareError(f"the result at {side} is not JSON: {error}") from error
    return parse_result(data, side)


def parse_result(data: object, side: str) -> Result:
    """Turn the JSON of `claude plugin eval --json` into a Result, or raise CompareError
    when it has another shape than the one this program was written against."""
    if not isinstance(data, dict):
        raise CompareError(f"the result at {side} is not a JSON object")
    cases = data.get("cases")
    if not isinstance(cases, list):
        raise CompareError(f"the result at {side} has no list 'cases' (schemaVersion {data.get('schemaVersion')})")
    parsed: dict[str, Case] = {}
    try:
        for entry in cases:
            runs = entry["arms"]["with"]
            parsed[str(entry["dir"])] = Case(
                score=float(entry["aggregates"]["score"]),
                runs=len(runs),
                errors=tuple(dict.fromkeys(str(run["error"]) for run in runs if run["error"] is not None)),
            )
        return Result(cases=parsed, cost_usd=float(data["costUsd"]))
    except (KeyError, TypeError, ValueError) as error:
        raise CompareError(f"the result at {side} holds a field this program cannot read: {error!r}") from error


def cell(case: Case | None) -> str:
    """One cell of the table: a dash for a case the commit does not have, the word
    error for a case with a run the harness refused, otherwise the score and its runs."""
    if case is None:
        return "-"
    if case.errors:
        return "error"
    return f"{case.score:.2f} ({case.runs} {'run' if case.runs == 1 else 'runs'})"


def report(base: Result, head: Result) -> list[str]:
    """The table of every case of either run, the reason of each refused run, and
    what the two runs cost."""
    names = sorted(base.cases.keys() | head.cases.keys())
    rows = [("case", "base", "head"), *((name, cell(base.cases.get(name)), cell(head.cases.get(name))) for name in names)]
    widths = [max(len(row[column]) for row in rows) for column in range(3)]
    lines = ["  ".join(text.ljust(width) for text, width in zip(row, widths, strict=True)).rstrip() for row in rows]
    errors = [
        f"{name} at {side}: {error}"
        for name in names
        for side, result in (("base", base), ("head", head))
        if (case := result.cases.get(name)) is not None
        for error in case.errors
    ]
    if errors:
        lines += ["", *errors]
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
