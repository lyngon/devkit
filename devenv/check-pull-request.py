#!/usr/bin/env python3
"""Check the title and the body of a pull request.

The two become the subject and the message of the one commit the pull
request lands as. Each message says what is wrong and what to do:

  title     one line that commitizen accepts as a Conventional Commits subject,
            under the repository's own commitizen configuration when it has one
  headings  the body's second-level headings are exactly the seven sections,
            each once, in order; a line inside a fenced code block is no heading
  why       the section ## Why ends with the line "Closes nothing." or with
            each issue the change fixes, as "Closes #12, closes #15.", the
            form in which GitHub closes every issue it names when the pull
            request merges; no other line of the body and not the title holds
            a closing keyword before an issue, since GitHub would close that
            issue too, in code as well
  scope     the section ## Scope ends with the line "Met on the way:", then
            "nothing" or each issue and pull request for a problem the work
            met, as #12 or owner/repository#12; only the form is checked,
            since the check runs without a network, and the forge shows a
            reference to nothing as plain text
  length    the body's content lines (neither blank nor one of the seven
            headings) stay within the limit, the target plus the headroom;
            above the target they get a warning
  marks     no em dash, en dash or curly quote in either, as prose-lint finds them

The title is read from PR_TITLE and the body from PR_BODY. Both are untrusted,
since anyone can write them in a public repository: neither reaches a shell or
a command line, and no message repeats their text, except a heading reduced to
plain characters.

The baseline module builds the command check-pull-request from this file and
writes the target and the headroom into it as arguments, so a local shell and
CI check against the same numbers. cz and prose-lint come from its PATH. It
prints nothing when all holds, exits 1 on an error and 2 when it cannot check.
A warning leaves the exit status at 0, and with GITHUB_ACTIONS set it is also
printed as a workflow annotation.
"""

import argparse
import os
import pathlib
import re
import subprocess
import sys
import tempfile
import typing as t

HEADINGS: t.Final = (
    "## Why",
    "## Decisions",
    "## What changed",
    "## Scope",
    "## Blast radius",
    "## Verified",
    "## Not verified",
)
ORDER: t.Final = ", ".join(HEADINGS)
# An issue or a pull request as the forge links it, in this repository or in another.
REFERENCE: t.Final = r"(?:[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)?#[1-9][0-9]*"
WHY: t.Final = "## Why"
# The keywords before an issue that GitHub closes the issue for when the pull request merges, in any case.
CLOSING_KEYWORD: t.Final = re.compile(
    (
        rf"\b(?:close[sd]?|fix(?:e[sd])?|resolve[sd]?):?\s+"
        rf"(?:{REFERENCE}|https://github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/issues/[1-9][0-9]*)"
    ),
    re.IGNORECASE,
)
NO_KEYWORD: t.Final = 'so that no "close", "fix" or "resolve" comes right before an issue'


class EndingLine(t.NamedTuple):
    """The line that a section must end with: the word it starts with, its whole form, and what to write."""

    start: str
    form: re.Pattern[str]
    missing: str
    malformed: str


ENDING_LINES: t.Final = {
    WHY: EndingLine(
        "Closes",
        re.compile(rf"Closes (?:nothing|{REFERENCE}(?:, closes {REFERENCE})*)\.?"),
        (
            "'## Why' does not end with a line that says which issues the change closes: "
            'end the section with "Closes nothing." or with each issue that the change fixes, '
            'as "Closes #12, closes #15."'
        ),
        (
            'the line "Closes" says neither "nothing" nor a list of issues that GitHub closes: '
            'write "Closes nothing." or name each issue as #12 or owner/repository#12, '
            'with "closes" before each one, as "Closes #12, closes #15."'
        ),
    ),
    "## Scope": EndingLine(
        "Met on the way:",
        re.compile(rf"Met on the way: (?:nothing|{REFERENCE}(?:(?:,| and|, and) {REFERENCE})*)\.?"),
        (
            "'## Scope' does not end with a line that says what the work met on the way: "
            'end the section with "Met on the way: nothing." or with each issue and pull request '
            'for a problem the work met, as "Met on the way: #12 and #15."'
        ),
        (
            'the line "Met on the way:" says neither "nothing" nor a list of issues and pull requests: '
            'write "Met on the way: nothing." or name each one as #12 or owner/repository#12, '
            'joined by commas and "and"'
        ),
    ),
}
# CommonMark: up to three spaces, the two marks, then a space or the end of the line.
SECOND_LEVEL_HEADING: t.Final = re.compile(r" {0,3}##(?:[ \t]|$)")
# CommonMark: up to three spaces, then three or more backticks or tildes.
FENCE: t.Final = re.compile(r" {0,3}(`{3,}|~{3,})(.*)")
# The exit status of `cz check` for a message that does not match its pattern.
COMMITIZEN_REJECTS: t.Final = 14
WAYS_OUT: t.Final = (
    "to shorten it, move a decision into a decision record, move evidence into a pull request comment, "
    "or split the change"
)
SHOWN_CHARACTERS: t.Final = 60


class RefusalError(Exception):
    """The run cannot check what it was asked to check."""


def from_environment(name: str) -> str:
    """Return the variable's text, empty when it is unset; bytes that are not UTF-8 are replaced."""
    return os.environb.get(name.encode(), b"").decode("utf-8", errors="replace")


def plain(text: str) -> str:
    """Untrusted text made safe to print: nothing a workflow or a terminal would take for a command."""
    return re.sub(r"[^A-Za-z0-9 #.,()/_-]", "?", text)[:SHOWN_CHARACTERS]


def run(arguments: list[str], directory: pathlib.Path | None = None) -> subprocess.CompletedProcess[str]:
    """Return the finished tool with what it printed, or raise a refusal when it cannot be started."""
    try:
        return subprocess.run(arguments, cwd=directory, capture_output=True, text=True, check=False)
    except OSError as error:
        raise RefusalError(f"cannot run {arguments[0]}: {error.strerror}") from error


def check_title(title: str, file: pathlib.Path) -> list[str]:
    """Check that the title is one line that commitizen accepts; the file holds the title."""
    if not title.strip():
        return ["title: PR_TITLE is empty: set it to the title of the pull request, <type>(<scope>): <subject>"]
    if len(title.splitlines()) > 1:
        return ["title: it has more than one line: keep the subject on one line and move the rest into the body"]
    # No prefix is exempt: commitizen lets "Merge" and "Revert" through for a commit that git writes.
    result = run(["cz", "check", "--allowed-prefixes", "--commit-msg-file", str(file)])
    if result.returncode == COMMITIZEN_REJECTS:
        return [
            (
                "title: commitizen rejects it as a Conventional Commits subject: write it as "
                '<type>(<scope>): <subject>, such as "fix(orders): reject a negative quantity"'
            ),
        ]
    if result.returncode != 0:
        raise RefusalError(
            (
                f"cz exited with status {result.returncode}, so the title was not checked; "
                "run cz check in the repository to see why"
            ),
        )
    return []


def check_marks(directory: pathlib.Path) -> list[str]:
    """Em and en dashes and curly quotes in the files title and body of the directory, as prose-lint reports them."""
    result = run(["prose-lint", "title", "body"], directory)
    found = [line for line in result.stderr.splitlines() if line.startswith(("title:", "body:"))]
    if result.returncode not in (0, 1) or bool(found) != bool(result.returncode):
        raise RefusalError(f"prose-lint exited with status {result.returncode}, so the marks were not checked")
    return found


def opens_fence(line: str) -> str | None:
    """Return the backticks or tildes that open a fenced code block on this line, if it opens one."""
    match = FENCE.match(line)
    if match is None or (match[1][0] == "`" and "`" in match[2]):
        return None
    return match[1]


def closes_fence(line: str, opening: str) -> bool:
    """Tell whether the line closes the fence: a run of the opening's character, at least as long, and nothing after."""
    match = FENCE.match(line)
    return match is not None and not match[2].strip() and match[1][0] == opening[0] and len(match[1]) >= len(opening)


class Body(t.NamedTuple):
    """What the checks read from a body.

    A line inside a fenced code block is never a heading. A content line is neither blank nor one of the
    seven headings.
    """

    headings: list[tuple[int, str]]
    """The second-level headings, with their line numbers."""
    content: int
    """The number of content lines."""
    last_prose_lines: dict[str, tuple[int, str]]


def read_body(body: str) -> Body:
    """Read the headings, the content lines and the last prose line of each section of ENDING_LINES of the body."""
    headings: list[tuple[int, str]] = []
    content = 0
    last_prose_lines: dict[str, tuple[int, str]] = {}
    section: str | None = None
    fence: str | None = None
    for number, raw in enumerate(body.split("\n"), 1):
        line = raw.rstrip()
        if not line:
            continue
        prose = False
        if fence is not None:
            if closes_fence(line, fence):
                fence = None
        elif (opening := opens_fence(line)) is not None:
            fence = opening
        elif SECOND_LEVEL_HEADING.match(line):
            section = line if line in ENDING_LINES else None
            headings.append((number, line))
            if line in HEADINGS:
                continue
        else:
            prose = True
        if section is not None and prose:
            last_prose_lines[section] = (number, line)
        elif section is not None:
            _ = last_prose_lines.pop(section, None)
        content += 1
    return Body(headings, content, last_prose_lines)


def check_headings(headings: list[tuple[int, str]]) -> list[str]:
    """Check that the headings are exactly the seven, each once, in order."""
    found: list[str] = []
    first: dict[str, int] = {}
    for number, heading in headings:
        if heading not in HEADINGS:
            found.append(
                (
                    f"body:{number}: '{plain(heading)}' is not one of the seven headings: spell it as one of them, "
                    "move its text under one, or make it a third-level heading"
                ),
            )
        elif heading in first:
            found.append(
                (
                    f"body:{number}: '{heading}' is there a second time: "
                    f"merge it into the section at line {first[heading]}"
                ),
            )
        else:
            first[heading] = number
    found.extend(
        f"body: '{heading}' is missing: add the section, and write None in it when it has nothing to say"
        for heading in HEADINGS
        if heading not in first
    )
    if list(first) != [heading for heading in HEADINGS if heading in first]:
        found.append(f"body: the headings are out of order: write them as {ORDER}")
    return found


def check_ending_lines(last_prose_lines: dict[str, tuple[int, str]]) -> list[str]:
    """Return an error for each section of ENDING_LINES whose line is missing or not in its form.

    The line is missing when the section's last line is no prose line that starts with the line's word.
    """
    found: list[str] = []
    for section, ending in ENDING_LINES.items():
        end = last_prose_lines.get(section)
        if end is None or not end[1].startswith(ending.start):
            found.append(f"body: {ending.missing}")
        elif ending.form.fullmatch(end[1]) is None:
            found.append(f"body:{end[0]}: {ending.malformed}")
    return found


def check_title_keyword(title: str) -> list[str]:
    """Return an error when the title holds a closing keyword before an issue."""
    if CLOSING_KEYWORD.search(title) is None:
        return []
    return [
        (
            "title: a closing keyword stands in the title, and GitHub closes the issue after it when the commit lands: "
            f"name the issue in the line that ends '{WHY}', or reword the title {NO_KEYWORD}"
        ),
    ]


def check_body_keywords(body: str, last_prose_lines: dict[str, tuple[int, str]]) -> list[str]:
    """Return an error for each line of the body that holds a closing keyword before an issue.

    The line that ends Why, when its last prose line starts with "Closes", is the one line that may.
    """
    why_end = last_prose_lines.get(WHY)
    why_line = why_end[0] if why_end is not None and why_end[1].startswith(ENDING_LINES[WHY].start) else None
    return [
        (
            f"body:{number}: a closing keyword stands outside the line that ends '{WHY}', and GitHub closes the issue "
            f"after it when the pull request merges: name the issue in that line, or reword {NO_KEYWORD}"
        )
        for number, line in enumerate(body.split("\n"), 1)
        if number != why_line and CLOSING_KEYWORD.search(line) is not None
    ]


def check_length(content: int, target: int, headroom: int) -> tuple[list[str], list[str]]:
    """Return an error above the limit, which is the target plus the headroom, and a warning above the target."""
    limit = target + headroom
    numbers = f"body is {content} content lines, limit is {limit} (target {target} plus headroom {headroom})"
    if content > limit:
        return [f"{numbers}: over the limit; {WAYS_OUT}"], []
    if content > target:
        return [], [f"{numbers}: over the target; {WAYS_OUT}"]
    return [], []


def main(arguments: list[str]) -> int:
    """Check PR_TITLE and PR_BODY, print what fails, and return the exit status.

    The status is 0 when all holds, 1 on an error and 2 when the run cannot check.
    """
    parser = argparse.ArgumentParser(
        prog="check-pull-request",
        description="Check PR_TITLE and PR_BODY as the subject and the message of the commit a pull request lands as.",
    )
    _ = parser.add_argument(
        "--target-lines", type=int, required=True, help="content lines the body gets a warning above"
    )
    _ = parser.add_argument(
        "--headroom-lines", type=int, required=True, help="content lines above the target it may have"
    )
    lengths = parser.parse_args(arguments)
    # A namespace types every value as Any; argparse has run each one through its type.
    target_lines, headroom_lines = t.cast("int", lengths.target_lines), t.cast("int", lengths.headroom_lines)
    title = from_environment("PR_TITLE")
    body = from_environment("PR_BODY")
    warnings: list[str] = []
    try:
        with tempfile.TemporaryDirectory() as name:
            directory = pathlib.Path(name)
            _ = (directory / "title").write_bytes(title.encode())
            _ = (directory / "body").write_bytes(body.encode())
            errors = check_title(title, directory / "title")
            marks = check_marks(directory)
    except RefusalError as refusal:
        print(f"check-pull-request: {refusal}", file=sys.stderr)
        return 2
    errors += check_title_keyword(title)
    errors += [line for line in marks if line.startswith("title:")]
    if body.strip():
        read = read_body(body)
        errors += check_headings(read.headings)
        errors += check_ending_lines(read.last_prose_lines)
        errors += check_body_keywords(body, read.last_prose_lines)
        over_limit, warnings = check_length(read.content, target_lines, headroom_lines)
        errors += over_limit
    else:
        errors.append(f"body: PR_BODY is empty: write the seven sections, in this order: {ORDER}")
    errors += [line for line in marks if line.startswith("body:")]
    for line in errors:
        print(f"error: {line}", file=sys.stderr)
    for line in warnings:
        print(f"warning: {line}", file=sys.stderr)
        if os.environ.get("GITHUB_ACTIONS"):
            print(f"::warning::{line}")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
