#!/usr/bin/env python3
# Check the title and the body of a pull request, which become the subject and
# the message of the one commit the pull request lands as. Each message says
# what is wrong and what to do:
#
#   title     one line that commitizen accepts as a Conventional Commits subject,
#             under the repository's own commitizen configuration when it has one
#   headings  the body's second-level headings are exactly the seven sections,
#             each once, in order; a line inside a fenced code block is no heading
#   scope     the section ## Scope ends with the line "Met on the way:", then
#             "nothing" or each issue and pull request for a problem the work
#             met, as #12 or owner/repository#12; only the form is checked,
#             since the check runs without a network, and the forge shows a
#             reference to nothing as plain text
#   length    the body's content lines (neither blank nor one of the seven
#             headings) stay within the limit, the target plus the headroom;
#             above the target they get a warning
#   marks     no em dash, en dash or curly quote in either, as prose-lint finds them
#
# The title is read from PR_TITLE and the body from PR_BODY. Both are untrusted,
# since anyone can write them in a public repository: neither reaches a shell or
# a command line, and no message repeats their text, except a heading reduced to
# plain characters.
#
# The baseline module builds the command check-pull-request from this file and
# writes the target and the headroom into it as arguments, so a local shell and
# CI check against the same numbers. cz and prose-lint come from its PATH. It
# prints nothing when all holds, exits 1 on an error and 2 when it cannot check.
# A warning leaves the exit status at 0, and with GITHUB_ACTIONS set it is also
# printed as a workflow annotation.
import argparse
import os
import pathlib
import re
import subprocess
import sys
import tempfile
import typing as t

HEADINGS: t.Final = (
    "## Why", "## Decisions", "## What changed", "## Scope", "## Blast radius", "## Verified", "## Not verified",
)
ORDER: t.Final = ", ".join(HEADINGS)
SCOPE: t.Final = "## Scope"
MET_ON_THE_WAY: t.Final = "Met on the way:"
# An issue or a pull request as the forge links it, in this repository or in another.
REFERENCE: t.Final = r"(?:[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)?#[1-9][0-9]*"
MET_ON_THE_WAY_LINE: t.Final = re.compile(
    rf"{MET_ON_THE_WAY} (?:nothing|{REFERENCE}(?:(?:,| and|, and) {REFERENCE})*)\.?",
)
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


class Refusal(Exception):
    """The run cannot check what it was asked to check."""


def from_environment(name: str) -> str:
    """The variable's text, empty when it is unset; bytes that are not UTF-8 are replaced."""
    return os.environb.get(name.encode(), b"").decode("utf-8", errors="replace")


def plain(text: str) -> str:
    """Untrusted text made safe to print: nothing a workflow or a terminal would take for a command."""
    return re.sub(r"[^A-Za-z0-9 #.,()/_-]", "?", text)[:SHOWN_CHARACTERS]


def run(arguments: list[str], directory: pathlib.Path | None = None) -> subprocess.CompletedProcess[str]:
    """The finished tool with what it printed, or a refusal when it cannot be started."""
    try:
        return subprocess.run(arguments, cwd=directory, capture_output=True, text=True, check=False)
    except OSError as error:
        raise Refusal(f"cannot run {arguments[0]}: {error.strerror}") from error


def check_title(title: str, file: pathlib.Path) -> list[str]:
    """The title is one line that commitizen accepts; the file holds the title."""
    if not title.strip():
        return ["title: PR_TITLE is empty: set it to the title of the pull request, <type>(<scope>): <subject>"]
    if len(title.splitlines()) > 1:
        return ["title: it has more than one line: keep the subject on one line and move the rest into the body"]
    # No prefix is exempt: commitizen lets "Merge" and "Revert" through for a commit that git writes.
    result = run(["cz", "check", "--allowed-prefixes", "--commit-msg-file", str(file)])
    if result.returncode == COMMITIZEN_REJECTS:
        return [
            "title: commitizen rejects it as a Conventional Commits subject: write it as "
            '<type>(<scope>): <subject>, such as "fix(orders): reject a negative quantity"',
        ]
    if result.returncode != 0:
        raise Refusal(
            f"cz exited with status {result.returncode}, so the title was not checked; "
            "run cz check in the repository to see why",
        )
    return []


def check_marks(directory: pathlib.Path) -> list[str]:
    """Em and en dashes and curly quotes in the files title and body of the directory, as prose-lint reports them."""
    result = run(["prose-lint", "title", "body"], directory)
    found = [line for line in result.stderr.splitlines() if line.startswith(("title:", "body:"))]
    if result.returncode not in (0, 1) or bool(found) != bool(result.returncode):
        raise Refusal(f"prose-lint exited with status {result.returncode}, so the marks were not checked")
    return found


def opens_fence(line: str) -> str | None:
    """The backticks or tildes that open a fenced code block on this line, if it opens one."""
    match = FENCE.match(line)
    if match is None or (match[1][0] == "`" and "`" in match[2]):
        return None
    return match[1]


def closes_fence(line: str, opening: str) -> bool:
    """A closing fence is a run of the opening's character, at least as long, with nothing after it."""
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
    scope_end: tuple[int, str] | None
    """The last line of the section ## Scope that is not blank, with its number; None when the section is
    missing, holds no such line or ends in a fenced code block."""


def read_body(body: str) -> Body:
    """The headings, the content lines and the end of the section ## Scope of the body."""
    headings: list[tuple[int, str]] = []
    content = 0
    scope_end: tuple[int, str] | None = None
    in_scope = False
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
            in_scope = line == SCOPE
            headings.append((number, line))
            if line in HEADINGS:
                continue
        else:
            prose = True
        if in_scope:
            scope_end = (number, line) if prose else None
        content += 1
    return Body(headings, content, scope_end)


def check_headings(headings: list[tuple[int, str]]) -> list[str]:
    """The headings are exactly the seven, each once, in order."""
    found = []
    first: dict[str, int] = {}
    for number, heading in headings:
        if heading not in HEADINGS:
            found.append(
                f"body:{number}: '{plain(heading)}' is not one of the seven headings: spell it as one of them, "
                "move its text under one, or make it a third-level heading",
            )
        elif heading in first:
            found.append(
                f"body:{number}: '{heading}' is there a second time: merge it into the section at line {first[heading]}",
            )
        else:
            first[heading] = number
    for heading in HEADINGS:
        if heading not in first:
            found.append(
                f"body: '{heading}' is missing: add the section, and write None in it when it has nothing to say",
            )
    if list(first) != [heading for heading in HEADINGS if heading in first]:
        found.append(f"body: the headings are out of order: write them as {ORDER}")
    return found


def check_met_on_the_way(scope_end: tuple[int, str] | None) -> list[str]:
    """The section ## Scope ends with a line that says nothing, or names each issue and pull request."""
    if scope_end is None or not scope_end[1].startswith(MET_ON_THE_WAY):
        return [
            f"body: '{SCOPE}' does not end with a line that says what the work met on the way: end the section with "
            f'"{MET_ON_THE_WAY} nothing." or with each issue and pull request for a problem the work met, '
            f'as "{MET_ON_THE_WAY} #12 and #15."',
        ]
    number, line = scope_end
    if MET_ON_THE_WAY_LINE.fullmatch(line) is None:
        return [
            f'body:{number}: the line "{MET_ON_THE_WAY}" says neither "nothing" nor a list of issues and pull '
            f'requests: write "{MET_ON_THE_WAY} nothing." or name each one as #12 or owner/repository#12, '
            f'joined by commas and "and"',
        ]
    return []


def check_length(content: int, target: int, headroom: int) -> tuple[list[str], list[str]]:
    """An error above the limit, which is the target plus the headroom, and a warning above the target."""
    limit = target + headroom
    numbers = f"body is {content} content lines, limit is {limit} (target {target} plus headroom {headroom})"
    if content > limit:
        return [f"{numbers}: over the limit; {WAYS_OUT}"], []
    if content > target:
        return [], [f"{numbers}: over the target; {WAYS_OUT}"]
    return [], []


def main(arguments: list[str]) -> int:
    parser = argparse.ArgumentParser(
        prog="check-pull-request",
        description="Check PR_TITLE and PR_BODY as the subject and the message of the commit a pull request lands as.",
    )
    parser.add_argument("--target-lines", type=int, required=True, help="content lines the body gets a warning above")
    parser.add_argument("--headroom-lines", type=int, required=True, help="content lines above the target it may have")
    lengths = parser.parse_args(arguments)
    title = from_environment("PR_TITLE")
    body = from_environment("PR_BODY")
    warnings: list[str] = []
    try:
        with tempfile.TemporaryDirectory() as name:
            directory = pathlib.Path(name)
            (directory / "title").write_bytes(title.encode())
            (directory / "body").write_bytes(body.encode())
            errors = check_title(title, directory / "title")
            marks = check_marks(directory)
    except Refusal as refusal:
        print(f"check-pull-request: {refusal}", file=sys.stderr)
        return 2
    errors += [line for line in marks if line.startswith("title:")]
    if body.strip():
        read = read_body(body)
        errors += check_headings(read.headings)
        errors += check_met_on_the_way(read.scope_end)
        over_limit, warnings = check_length(read.content, lengths.target_lines, lengths.headroom_lines)
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
