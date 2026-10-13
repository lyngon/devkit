#!/usr/bin/env python3
"""Delete the files of the mistake ledger that are older than the repository's limit.

The ledger is the Markdown files directly in docs/mistakes/ of the repository
whose root is the working directory, one file per mistake, each with a line
`- **Date**: YYYY-MM-DD`. A file is deleted when its date lies more than
LYNGON_MISTAKES_MAX_AGE_DAYS days back. The baseline sets that variable from
its option lyngon.mistakes.maxAgeDays, so the limit has one home and this
program has no default of its own.

Every date is read before any file is deleted. Exits 1 and deletes nothing
outside the root of a repository, when the variable is missing or is no
positive number of days, and when a file has no date that can be read. It
reads a file as the baseline's validate-documents does, so a ledger that the
validator passes never stops it. Imports the standard library only, because
the baseline promises a shipped script the interpreter and nothing else.
"""

import argparse
import collections.abc as ct
import datetime as dt
import os
import pathlib
import re
import sys

LEDGER: pathlib.Path = pathlib.Path("docs/mistakes")
LIMIT_VARIABLE: str = "LYNGON_MISTAKES_MAX_AGE_DAYS"
DATE_LINE: re.Pattern[str] = re.compile(r"- \*\*Date\*\*: (\d{4}-\d{2}-\d{2})")


class PruneError(Exception):
    """A ledger that cannot be pruned. The message is what the operator reads."""


def limit_in_days(environment: ct.Mapping[str, str]) -> int:
    """The limit from the environment. Raises PruneError when it is missing or no positive whole number."""
    value = environment.get(LIMIT_VARIABLE)
    if value is None:
        raise PruneError(
            f"{LIMIT_VARIABLE} is not set; the baseline sets it from lyngon.mistakes.maxAgeDays, "
            "so run this in the devenv shell of the repository, and where that shell lacks it too, "
            "the repository's baseline is older than this script: run 'devenv update lyngon'"
        )
    if not (value.isascii() and value.isdigit()) or int(value) == 0:
        raise PruneError(f"{LIMIT_VARIABLE} is '{value}', and the limit is a positive whole number of days")
    return int(value)


def date_of(path: pathlib.Path) -> dt.date:
    """The date of a ledger file. Raises PruneError unless the file has exactly one date line, with a day that exists."""
    try:
        lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError as error:
        raise PruneError(f"{path}: cannot be read: {error}") from error
    found = [match.group(1) for line in lines if (match := DATE_LINE.fullmatch(line)) is not None]
    if len(found) != 1:
        raise PruneError(f"{path}: needs exactly one line '- **Date**: <YYYY-MM-DD>', and has {len(found)}")
    try:
        return dt.date.fromisoformat(found[0])
    except ValueError as error:
        raise PruneError(f"{path}: '{found[0]}' is no date") from error


def prune(today: dt.date, limit: int) -> list[str]:
    """Delete the ledger files dated more than the limit before today, and return the lines to print.

    Raises PruneError before it deletes anything, when the working directory is not the root of a
    repository and when one file has no date that can be read.
    """
    # A run from another directory would find no ledger and report that it pruned one.
    if not pathlib.Path(".git").exists():
        raise PruneError(f"{pathlib.Path.cwd()} has no .git; run this from the root of the repository")
    if not LEDGER.is_dir():
        return [f"prune-mistakes: no {LEDGER}/ in this repository, so nothing to prune"]
    dated = [(path, date_of(path)) for path in sorted(LEDGER.glob("*.md")) if path.is_file()]
    old = [(path, date) for path, date in dated if (today - date).days > limit]
    for path, _ in old:
        path.unlink()
    return [
        *(f"prune-mistakes: deleted {path}, dated {date.isoformat()}" for path, date in old),
        f"prune-mistakes: deleted {len(old)} of {len(dated)} ledger files, the limit is {limit} days",
    ]


def main(arguments: ct.Sequence[str]) -> int:
    """Prune the ledger below the working directory and return the exit status: 0 when pruned, 1 when refused."""
    parser = argparse.ArgumentParser(
        prog="prune-mistakes",
        description="Delete the Markdown files in docs/mistakes/ that are older than the repository's limit. "
        "Run it from the root of the repository.",
    )
    parser.add_argument(
        "--today",
        type=dt.date.fromisoformat,
        metavar="YYYY-MM-DD",
        help="the day to count the age from, in place of today",
    )
    parsed = parser.parse_args(arguments)
    today: dt.date = parsed.today if parsed.today is not None else dt.date.today()
    try:
        lines = prune(today, limit_in_days(os.environ))
    except PruneError as error:
        print(f"prune-mistakes: {error}; nothing was deleted", file=sys.stderr)
        return 1
    print("\n".join(lines))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
