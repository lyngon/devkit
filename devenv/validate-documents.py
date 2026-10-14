#!/usr/bin/env python3
"""Check a repository's steering documents against the Lyngon document rules.

Each message names its rule and the fix:

  agent-file-imports-intent        .claude/CLAUDE.md is tracked and holds the
                                   line @../INTENT.md, whatever else it holds
  no-agents-md                     no file is named AGENTS.md
  no-claude-md-outside-dot-claude  the only CLAUDE.md is .claude/CLAUDE.md
  no-docs-adr                      no docs/adr/ directory, in the root or a package
  decision-record-shape            a file in docs/decisions/ is named after its
                                   decision, ends with `Enforced by:` and has no
                                   Status line and no change log
  intent-shape                     INTENT.md has at most 50 lines and only its
                                   own sections
  rule-file-shape                  a file under .claude/rules/ has a kebab-case
                                   name and at most 100 lines
  ledger-file-shape                a file under docs/mistakes/ at the root lies
                                   directly in it, is named after its mistake,
                                   starts with a heading, has one date line
                                   with a day that exists, and writes what it
                                   was caught in as a link

Runs at pre-commit from the repository root with the files to check as
arguments, so a hook's `excludes` keeps a fixture tree out. Without arguments
it checks every tracked file. The agent file is checked on every run, since a
missing file is never among the arguments. A path inside a vendor/ or
generated/ directory is skipped, and so is one that is gone from the working
tree. It exits 1 on a violation and 2 when it cannot check what it was asked
to.
"""

import datetime as dt
import os
import pathlib
import re
import subprocess
import sys
import typing as t

KEBAB: t.Final = re.compile(r"[a-z0-9]+(-[a-z0-9]+)*")
NUMBERED: t.Final = re.compile(r"[0-9]+-")
ENFORCED_BY: t.Final = re.compile(r"Enforced by: \S")
INTENT_SECTIONS: t.Final = (
    "Product",
    "For whom",
    "Done means",
    "Failure means",
    "Non-goals",
    "Priorities",
    "Horizon",
)
INTENT_MAX_LINES: t.Final = 50
RULE_MAX_LINES: t.Final = 100
# The two lines below the heading of a file in the mistake ledger. The build
# plugin's prune-mistakes.py ages a file by its date line, and stops at a
# ledger with a date it cannot read. It reads the Markdown files directly in
# docs/mistakes/ and decodes them as read_lines below does, so a ledger that
# passes here never stops it; plugins/build/tests/prune-mistakes.sh holds the
# two to that.
LEDGER_DATE: t.Final = re.compile(r"- \*\*Date\*\*: (.*)")
LEDGER_CAUGHT_IN: t.Final = re.compile(r"- \*\*Caught in\*\*: (.*)")
ISO_DAY: t.Final = re.compile(r"\d{4}-\d{2}-\d{2}")
# The title of a pull request may hold brackets of its own.
LINK: t.Final = re.compile(r"\[.+\]\(\S+\)")
SKIPPED_DIRECTORIES: t.Final = frozenset({"vendor", "generated"})
RULES_DIRECTORY: t.Final = pathlib.PurePosixPath(".claude/rules")
LEDGER_DIRECTORY: t.Final = pathlib.PurePosixPath("docs/mistakes")
AGENT_FILE: t.Final = pathlib.PurePosixPath(".claude/CLAUDE.md")
IMPORT_LINE: t.Final = "@../INTENT.md"
MOVE_LINES: t.Final = (
    f"move what must stay to {AGENT_FILE}, below the line {IMPORT_LINE}, or to "
    ".claude/rules/<principle>.md with paths: when it concerns part of the tree, and delete the file"
)


class RefusalError(Exception):
    """The run cannot check what it was asked to check."""


def error(path: pathlib.PurePosixPath | str, rule: str, fix: str, line: int | None = None) -> str:
    """One line of output: where, the rule's name, and how to fix it."""
    where = f"{path}" if line is None else f"{path}:{line}"
    return f"error: {where}: {rule}: {fix}"


def git(*arguments: str) -> str | None:
    """Return the output of a git command, or None when git refuses or is missing."""
    try:
        return subprocess.run(["git", *arguments], capture_output=True, text=True, check=True).stdout
    except (OSError, subprocess.CalledProcessError):
        return None


def tracked_files(root: pathlib.Path) -> list[pathlib.PurePosixPath]:
    """Every file git tracks, relative to the root."""
    out = git("-C", str(root), "ls-files", "-z")
    if out is None:
        raise RefusalError(f"git cannot list the tracked files of {root}")
    return [pathlib.PurePosixPath(name) for name in out.split("\0") if name]


def given_files(root: pathlib.Path, arguments: list[str]) -> list[pathlib.PurePosixPath]:
    """Return the arguments as paths relative to the root, wherever they were given from."""
    paths: list[pathlib.PurePosixPath] = []
    for argument in arguments:
        absolute = pathlib.Path(os.path.normpath(pathlib.Path.cwd() / argument))
        if not absolute.is_relative_to(root):
            raise RefusalError(f"{absolute} is outside the repository")
        paths.append(pathlib.PurePosixPath(absolute.relative_to(root).as_posix()))
    return paths


def read_lines(root: pathlib.Path, path: pathlib.PurePosixPath) -> list[str] | None:
    """Return the file's lines, or None when it cannot be read as a file."""
    try:
        return (root / path).read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError:
        return None


def check_agent_file(root: pathlib.Path) -> list[str]:
    """Check that the agent file is tracked and imports the intent, whatever else it holds."""
    rule = "agent-file-imports-intent"
    untracked = git("-C", str(root), "ls-files", "--", str(AGENT_FILE)) == ""
    lines = read_lines(root, AGENT_FILE)
    if untracked or lines is None:
        return [
            error(
                AGENT_FILE,
                rule,
                f"create it with the line {IMPORT_LINE}, so that every session starts from the intent",
            )
        ]
    if not any(line.strip() == IMPORT_LINE for line in lines):
        return [
            error(
                AGENT_FILE,
                rule,
                f"add the line {IMPORT_LINE}; what else the file holds is the authors' choice",
            )
        ]
    return []


def adr_directory(path: pathlib.PurePosixPath) -> pathlib.PurePosixPath | None:
    """Return the docs/adr directory the path lies in or, as a link, stands for."""
    parts = path.parts
    for index in range(len(parts) - 1):
        if parts[index : index + 2] == ("docs", "adr"):
            return pathlib.PurePosixPath(*parts[: index + 2])
    return None


def check_decision_record(root: pathlib.Path, path: pathlib.PurePosixPath) -> list[str]:
    """Check that a decision record is named after its decision, ends with `Enforced by:` and has no history."""
    rule = "decision-record-shape"
    found: list[str] = []
    if NUMBERED.match(path.name):
        found.append(error(path, rule, "drop the number from the name; a record is referred to by its decision"))
    elif path.suffix != ".md" or not KEBAB.fullmatch(path.stem):
        found.append(error(path, rule, "name the file after its decision, <decision-in-kebab-case>.md"))
    lines = read_lines(root, path)
    if lines is None:
        return found
    written = [line for line in lines if line.strip()]
    if not written or not ENFORCED_BY.match(written[-1]):
        found.append(
            error(
                path,
                rule,
                "end the record with the line 'Enforced by: <name of the check>' or 'Enforced by: judgment'",
            )
        )
    for number, line in enumerate(lines, 1):
        if line.startswith("Status:"):
            found.append(
                error(
                    path,
                    rule,
                    "delete the Status line; a record exists only while its decision holds",
                    number,
                )
            )
            break
    for number, line in enumerate(lines, 1):
        if line.rstrip() == "## Change log":
            found.append(error(path, rule, "delete the change log; git holds the history of a record", number))
            break
    return found


def check_intent(root: pathlib.Path, path: pathlib.PurePosixPath) -> list[str]:
    """Check that INTENT.md is short and holds only its own sections."""
    rule = "intent-shape"
    lines = read_lines(root, path)
    if lines is None:
        return []
    found: list[str] = []
    if len(lines) > INTENT_MAX_LINES:
        found.append(
            error(
                path,
                rule,
                (
                    f"{len(lines)} lines; cut it to {INTENT_MAX_LINES} at most: it holds the product, "
                    "its audiences, done, failure, non-goals, priorities and horizon, and nothing else"
                ),
            )
        )
    sections = ", ".join(INTENT_SECTIONS[:-1]) + f" or {INTENT_SECTIONS[-1]}"
    for number, line in enumerate(lines, 1):
        if line.startswith("## ") and line[3:].strip() not in INTENT_SECTIONS:
            found.append(
                error(
                    path,
                    rule,
                    f"'{line.strip()}' is not a section of INTENT.md; use {sections}, or move the text out",
                    number,
                )
            )
    return found


def check_rule_file(root: pathlib.Path, path: pathlib.PurePosixPath) -> list[str]:
    """Check that a rule file has a kebab-case name and stays short."""
    rule = "rule-file-shape"
    found: list[str] = []
    if path.suffix != ".md" or not KEBAB.fullmatch(path.stem):
        found.append(error(path, rule, "name the file after its principle, <principle-in-kebab-case>.md"))
    lines = read_lines(root, path)
    if lines is not None and len(lines) > RULE_MAX_LINES:
        found.append(
            error(
                path,
                rule,
                (
                    f"{len(lines)} lines; cut it to {RULE_MAX_LINES} at most: a rule file states one principle in one "
                    "or two sentences and its reason in one, "
                    "and a longer convention goes to docs/conventions/<topic>.md"
                ),
            )
        )
    return found


def is_day(text: str) -> bool:
    """Whether the text is a day that exists, written as YYYY-MM-DD."""
    if not ISO_DAY.fullmatch(text):
        return False
    try:
        _ = dt.date.fromisoformat(text)
    except ValueError:
        return False
    return True


def check_ledger_file(root: pathlib.Path, path: pathlib.PurePosixPath) -> list[str]:
    """Check that a ledger file lies directly in the ledger, is named after its mistake and has its heading and lines.

    The lines are one date line with a day that exists, and what the mistake was caught in as a link.
    """
    rule = "ledger-file-shape"
    found: list[str] = []
    if path.parent != LEDGER_DIRECTORY or path.suffix != ".md" or not KEBAB.fullmatch(path.stem):
        found.append(
            error(
                path,
                rule,
                "name the file after its mistake, docs/mistakes/<mistake-in-kebab-case>.md, with no directory between",
            )
        )
    lines = read_lines(root, path)
    if lines is None:
        return found
    if not lines or not lines[0].startswith("# "):
        found.append(error(path, rule, "start the file with the heading '# <the mistake, as a sentence>'", 1))
    dates = [
        (number, match.group(1))
        for number, line in enumerate(lines, 1)
        if (match := LEDGER_DATE.fullmatch(line)) is not None
    ]
    if len(dates) != 1:
        found.append(
            error(
                path,
                rule,
                (
                    f"{len(dates)} lines '- **Date**: <YYYY-MM-DD>'; give the file exactly one, "
                    "with the day the mistake was caught, because the ledger is pruned by it"
                ),
            )
        )
    for number, day in dates:
        if not is_day(day):
            found.append(
                error(
                    path,
                    rule,
                    f"'{day}' is no day; write the day the mistake was caught as YYYY-MM-DD",
                    number,
                )
            )
    for number, line in enumerate(lines, 1):
        caught_in = LEDGER_CAUGHT_IN.fullmatch(line)
        if caught_in is not None and not LINK.fullmatch(caught_in.group(1)):
            found.append(
                error(
                    path,
                    rule,
                    (
                        "write the line as '- **Caught in**: [<pull request title>](<pull request link>)', or leave it "
                        "out until the pull request exists"
                    ),
                    number,
                )
            )
    return found


def check_shape(root: pathlib.Path, path: pathlib.PurePosixPath) -> list[str]:
    """Check the shape that a file's place gives it: decision record, INTENT.md, rule file or ledger file."""
    found: list[str] = []
    if path.parent.parts[-2:] == ("docs", "decisions"):
        found += check_decision_record(root, path)
    if path.name == "INTENT.md":
        found += check_intent(root, path)
    if RULES_DIRECTORY in path.parents:
        found += check_rule_file(root, path)
    if LEDGER_DIRECTORY in path.parents:
        found += check_ledger_file(root, path)
    return found


def check(root: pathlib.Path, paths: list[pathlib.PurePosixPath]) -> list[str]:
    """Every violation among the paths, one line each, in path order."""
    found: list[str] = []
    adr_directories: set[pathlib.PurePosixPath] = set()
    for path in sorted(set(paths)):
        if SKIPPED_DIRECTORIES.intersection(path.parts[:-1]):
            continue
        if not (root / path).exists(follow_symlinks=False):
            continue
        if path.name == "AGENTS.md":
            fix = "delete the link" if (root / path).is_symlink() else MOVE_LINES
            found.append(
                error(
                    path,
                    "no-agents-md",
                    f"{fix}; Claude Code reads {AGENT_FILE}, and no other agent harness is supported",
                )
            )
        if path.name == "CLAUDE.md" and path != AGENT_FILE:
            found.append(
                error(
                    path,
                    "no-claude-md-outside-dot-claude",
                    MOVE_LINES,
                )
            )
        directory = adr_directory(path)
        if directory is not None and directory not in adr_directories:
            adr_directories.add(directory)
            found.append(
                error(
                    f"{directory}/",
                    "no-docs-adr",
                    (
                        "move each record that passes the admission test to "
                        f"{directory.parent / 'decisions'}/<decision-in-kebab-case>.md and delete the directory"
                    ),
                )
            )
        found += check_shape(root, path)
    return found


def files_to_check(top: str | None, arguments: list[str]) -> tuple[pathlib.Path, list[pathlib.PurePosixPath]]:
    """Return the root and the files to check: the arguments, or every tracked file when there are none.

    The root is the top of the repository that git names, or the working directory for arguments outside one.
    Raises RefusalError without arguments outside a repository.
    """
    if arguments:
        root = pathlib.Path(top.strip()) if top else pathlib.Path.cwd()
        return root, given_files(root, arguments)
    if top:
        root = pathlib.Path(top.strip())
        return root, tracked_files(root)
    raise RefusalError("not inside a git repository, so no tracked files to check; pass the files as arguments")


def main(arguments: list[str]) -> int:
    """Check the files and return the exit status: 0 when all holds, 1 on a violation, 2 when the run cannot check."""
    top = git("rev-parse", "--show-toplevel")
    try:
        root, paths = files_to_check(top, arguments)
    except RefusalError as refusal:
        print(f"validate-documents: {refusal}", file=sys.stderr)
        return 2
    found = check_agent_file(root) + check(root, paths)
    for line in found:
        print(line, file=sys.stderr)
    if found:
        print(f"validate-documents: {len(found)} error(s)", file=sys.stderr)
        return 1
    print("validate-documents: ok")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
