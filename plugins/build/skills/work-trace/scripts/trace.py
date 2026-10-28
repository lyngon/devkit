#!/usr/bin/env python3
"""Write the decision log of build:work-trace, and print it as a Markdown table.

    trace.py append <logfile> <phase> <decision> <why> <evidence> <result>
    trace.py table <logfile>

The log is a TSV file whose first line is the header and whose every other
line is one decision. `append` adds a row stamped with the time in UTC, and
writes the header first when the log is new or empty. `table` prints the log as
a Markdown table, for a terminal or a pull request comment, and exits 1 without
printing anything when a line of the log is no row of six cells.

Every cell stays on one line, so a tab, a line feed or a carriage return in it
becomes a space. A cell that starts with =, +, - or @ gets a single quote in
front, because a spreadsheet runs such a cell as a formula and a cell can
carry text from anyone, such as a pull request title or a file name. A file
name can also hold bytes that are no UTF-8: `append` writes them as they came,
and `table` prints each as the replacement character, since a pull request
comment is UTF-8. The arguments are read by their position, so a cell may
start with a dash. Imports
the standard library only, because the baseline promises a shipped script the
interpreter and nothing else.
"""

import collections.abc as ct
import datetime as dt
import pathlib
import sys

COLUMNS: tuple[str, ...] = ("ts", "phase", "decision", "why", "evidence", "result")
FORMULA_STARTS: tuple[str, ...] = ("=", "+", "-", "@")
USAGE: str = (
    "usage: trace.py append <logfile> <phase> <decision> <why> <evidence> <result>\n       trace.py table <logfile>"
)


class TraceError(Exception):
    """A log that cannot be read as rows. The message is what the operator reads."""


def cell(value: str) -> str:
    """Return the value as one cell: on one line, and never run as a formula by a spreadsheet."""
    flat = value.translate(str.maketrans("\t\n\r", "   "))
    return f"'{flat}" if flat.startswith(FORMULA_STARTS) else flat


def append(log: pathlib.Path, values: ct.Sequence[str], now: dt.datetime) -> None:
    """Append one row stamped with the time, after the header when the log is new or empty."""
    log.parent.mkdir(parents=True, exist_ok=True)
    with log.open("a", encoding="utf-8", errors="surrogateescape") as file:
        if file.tell() == 0:
            _ = file.write("\t".join(COLUMNS) + "\n")
        stamp = now.astimezone(dt.UTC).strftime("%Y-%m-%dT%H:%M:%SZ")
        _ = file.write("\t".join([stamp, *map(cell, values)]) + "\n")


def table(log: pathlib.Path) -> str:
    """Return the log as a Markdown table. Raises TraceError when it is missing or a line is no row."""
    try:
        lines = log.read_text(encoding="utf-8", errors="replace").splitlines()
    except FileNotFoundError as error:
        raise TraceError(f"{log}: no such log") from error
    if not lines or lines[0].split("\t") != list(COLUMNS):
        raise TraceError(f"{log}:1: the header is not {' '.join(COLUMNS)}")
    rows: list[list[str]] = []
    for number, line in enumerate(lines[1:], 2):
        cells = line.split("\t")
        if len(cells) != len(COLUMNS):
            raise TraceError(f"{log}:{number}: has {len(cells)} cells, a row has {len(COLUMNS)}")
        rows.append(cells)
    rendered = [COLUMNS, ("---",) * len(COLUMNS), *rows]
    return "".join("| " + " | ".join(value.replace("|", "\\|") for value in row) + " |\n" for row in rendered)


def main(argv: ct.Sequence[str]) -> int:
    """Run the command that the arguments name. Returns the exit status."""
    match list(argv):
        case ["append", log, *values] if len(values) == len(COLUMNS) - 1:
            append(pathlib.Path(log), values, dt.datetime.now(dt.UTC))
        case ["table", log]:
            try:
                _ = sys.stdout.write(table(pathlib.Path(log)))
            except TraceError as error:
                print(f"trace.py: {error}", file=sys.stderr)
                return 1
        case _:
            print(USAGE, file=sys.stderr)
            return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
