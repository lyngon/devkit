#!/usr/bin/env python3
"""Check a repository's steering documents against the Lyngon document rules.

Each message names its rule and the fix:

  agent-file-imports-intent        .claude/CLAUDE.md and INTENT.md are tracked
                                   at the root, and in a package both or
                                   neither, and the agent file holds the line
                                   @../INTENT.md
  agent-file-holds-only-imports    each line of an agent file is blank or
                                   @../<name>.md, naming a tracked file
                                   directly in the directory that holds .claude/
  no-agents-md                     no file is named AGENTS.md
  no-claude-md-outside-dot-claude  a CLAUDE.md lies directly in a .claude/
                                   directory
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
it checks every tracked file. The root's agent file is checked on every run,
and every path given, deleted or not, brings in the agent file of its own
directory, or is one, so a package's pair is checked whenever a file of the
package's directory is among the arguments. A path inside a vendor/ or
generated/ directory is skipped, and the other rules skip a path that is gone
from the working tree. Without git, every file of the working tree counts as
tracked. It exits 1 on a violation and 2 when it cannot check what it was
asked to.
"""

import collections.abc as ct
import dataclasses
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
DOT_CLAUDE: t.Final = ".claude"
AGENT_FILE_NAME: t.Final = "CLAUDE.md"
INTENT_NAME: t.Final = "INTENT.md"
# The grammar of a line of an agent file, each pattern matched in full against
# the line without its trailing whitespace. Leading whitespace is not forgiven,
# so that no line passes that Markdown may read as a code block.
IMPORT: t.Final = re.compile(r"@\.\./(?P<name>[^/\s]+\.md)")
ANY_IMPORT: t.Final = re.compile(r"\s*@\S+")
INTENT_IMPORT: t.Final = f"@../{INTENT_NAME}"
IMPORT_FORM: t.Final = "@../<name>.md"
RULE_HOME: t.Final = f"{RULES_DIRECTORY}/<principle>.md, with paths: when it concerns part of the tree"
MOVE_LINES: t.Final = f"move what must stay to {RULE_HOME}, and delete the file"


class RefusalError(Exception):
    """The run cannot check what it was asked to check."""


def error(path: pathlib.PurePosixPath | str, rule: str, fix: str, line: int | None = None) -> str:
    """One line of output: where, the rule's name, and how to fix it."""
    where = f"{path}" if line is None else f"{path}:{line}"
    return f"error: {where}: {rule}: {fix}"


@dataclasses.dataclass(frozen=True, slots=True, order=True)
class AgentFile:
    """The place <home>/.claude/CLAUDE.md, whether a file is there or not.

    The root's is required, and a package's goes with the INTENT.md beside it.
    Its members are the only code that joins .claude, CLAUDE.md or INTENT.md
    onto a directory.
    """

    home: pathlib.PurePosixPath

    @property
    def path(self) -> pathlib.PurePosixPath:
        """The agent file itself, relative to the root."""
        return self.home / DOT_CLAUDE / AGENT_FILE_NAME

    @property
    def intent(self) -> pathlib.PurePosixPath:
        """The INTENT.md that the required line imports."""
        return self.sibling(INTENT_NAME)

    @property
    def is_root(self) -> bool:
        """Whether the home is the root of the repository."""
        return not self.home.parts

    @property
    def place(self) -> str:
        """The home as a message names it."""
        return "the root" if self.is_root else f"{self.home}/"

    def sibling(self, name: str) -> pathlib.PurePosixPath:
        """Return the file that the line @../<name> imports."""
        return self.home / name


ROOT: t.Final = AgentFile(pathlib.PurePosixPath("."))


def agent_file_of(path: pathlib.PurePosixPath) -> AgentFile | None:
    """Return the agent file that the path is, or None for any other path."""
    if path.name == AGENT_FILE_NAME and path.parent.name == DOT_CLAUDE:
        return AgentFile(path.parent.parent)
    return None


@dataclasses.dataclass(frozen=True, slots=True)
class Import:
    """A line @../<name>.md, which imports the file <name>.md directly in the home of its agent file."""

    number: int
    name: str


@dataclasses.dataclass(frozen=True, slots=True)
class ImportElsewhere:
    """A line of one @ token that is no Import: indented, or naming a file outside the home or not Markdown."""

    number: int
    text: str


@dataclasses.dataclass(frozen=True, slots=True)
class Text:
    """Any other line that is not blank."""

    number: int


type Line = Import | ImportElsewhere | Text


def parse_lines(lines: ct.Iterable[str]) -> list[Line]:
    """Return what each line of an agent file is, in file order, leaving out the blank ones."""
    parsed: list[Line] = []
    for number, line in enumerate(lines, 1):
        text = line.rstrip()
        if not text:
            continue
        if (match := IMPORT.fullmatch(text)) is not None:
            parsed.append(Import(number, match["name"]))
        elif ANY_IMPORT.fullmatch(text):
            parsed.append(ImportElsewhere(number, text))
        else:
            parsed.append(Text(number))
    return parsed


@dataclasses.dataclass(frozen=True, slots=True)
class Tree:
    """The working tree at the root, and the files git tracks in it, or None when git cannot say."""

    root: pathlib.Path
    tracked: frozenset[pathlib.PurePosixPath] | None

    def holds(self, path: pathlib.PurePosixPath) -> bool:
        """Whether the path is a file of the working tree that git tracks: the one meaning of missing or untracked.

        Without git, every file of the working tree counts as tracked.
        """
        return (self.tracked is None or path in self.tracked) and (self.root / path).is_file()


def git(*arguments: str) -> str | None:
    """Return the output of a git command, or None when git refuses or is missing."""
    try:
        return subprocess.run(["git", *arguments], capture_output=True, text=True, check=True).stdout
    except (OSError, subprocess.CalledProcessError):
        return None


def tracked_files(root: pathlib.Path) -> frozenset[pathlib.PurePosixPath] | None:
    """Every file git tracks, relative to the root, or None when git cannot list them."""
    out = git("-C", str(root), "ls-files", "-z")
    if out is None:
        return None
    return frozenset(pathlib.PurePosixPath(name) for name in out.split("\0") if name)


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


def skipped(path: pathlib.PurePosixPath) -> bool:
    """Whether the path lies inside a vendor/ or generated/ directory."""
    return bool(SKIPPED_DIRECTORIES.intersection(path.parts[:-1]))


def agent_files(paths: ct.Iterable[pathlib.PurePosixPath]) -> list[AgentFile]:
    """Return the agent files that a run over the paths checks, each once: the root's first, then in path order.

    Each path that is not skipped brings in the agent file it is, or else the one of its own directory, so a
    fixture tree that the arguments leave out brings in nothing.
    """
    brought_in = {agent_file_of(path) or AgentFile(path.parent) for path in paths if not skipped(path)}
    return [ROOT, *sorted(brought_in - {ROOT})]


def check_agent_file(tree: Tree, agent_file: AgentFile) -> list[str]:
    """Check one agent file, there or not, against agent-file-imports-intent and agent-file-holds-only-imports.

    The root holds its agent file and its INTENT.md; a package holds both or neither. An unreadable agent file
    counts as not there. The target of the line @../INTENT.md belongs to the pair, so a missing intent is
    reported once.
    """
    rule = "agent-file-imports-intent"
    lines = read_lines(tree.root, agent_file.path) if tree.holds(agent_file.path) else None
    intent = tree.holds(agent_file.intent)
    required = agent_file.is_root or intent
    if agent_file.is_root:
        purpose = "every session starts from the intent"
    else:
        purpose = f"a session loads the package's intent when it works on a file in {agent_file.place}"
    found: list[str] = []
    if lines is None and required:
        found.append(error(agent_file.path, rule, f"create it with the line {INTENT_IMPORT}, so that {purpose}"))
    if agent_file.is_root and not intent:
        found.append(
            error(
                agent_file.intent,
                rule,
                f"create it with the repository's intent, which {agent_file.path} imports into every session",
            )
        )
    if lines is None:
        return found
    if not required:
        found.append(
            error(
                agent_file.intent,
                rule,
                (
                    "create it with the sections in which the package's intent differs from the root's, "
                    f"or delete {agent_file.path}, which a package holds only beside its {INTENT_NAME}"
                ),
            )
        )
    parsed = parse_lines(lines)
    found += [message for line in parsed if (message := line_error(tree, agent_file, line)) is not None]
    if required and not any(isinstance(line, Import) and line.name == INTENT_NAME for line in parsed):
        found.append(error(agent_file.path, rule, f"add the line {INTENT_IMPORT}, so that {purpose}"))
    return found


def line_error(tree: Tree, agent_file: AgentFile, line: Line) -> str | None:
    """Return the agent-file-holds-only-imports message for one line of the agent file, or None when it holds.

    An import of INTENT.md always holds here: its target belongs to the pair, which check_agent_file checks.
    """
    rule = "agent-file-holds-only-imports"
    match line:
        case Import(number=number, name=name):
            target = agent_file.sibling(name)
            if name == INTENT_NAME or tree.holds(target):
                return None
            fix = f"the line imports {target}, which is missing or untracked; add the file, or delete the line"
        case ImportElsewhere(number=number, text=text):
            fix = (
                f"'{text}' imports no Markdown file directly in {agent_file.place}; "
                f"write it as {IMPORT_FORM}, or delete the line"
            )
        case Text(number=number):
            fix = (
                f"delete the line, or move what it says to {RULE_HOME}; "
                f"an agent file holds only lines of the form {IMPORT_FORM}"
            )
        case _:
            t.assert_never(line)
    return error(agent_file.path, rule, fix, number)


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
    if path.name == INTENT_NAME:
        found += check_intent(root, path)
    if RULES_DIRECTORY in path.parents:
        found += check_rule_file(root, path)
    if LEDGER_DIRECTORY in path.parents:
        found += check_ledger_file(root, path)
    return found


def check(tree: Tree, paths: list[pathlib.PurePosixPath]) -> list[str]:
    """Every violation among the paths, one line each: the agent files they bring in, then the paths in order."""
    found: list[str] = []
    for agent_file in agent_files(paths):
        found += check_agent_file(tree, agent_file)
    root = tree.root
    adr_directories: set[pathlib.PurePosixPath] = set()
    for path in sorted(set(paths)):
        if skipped(path):
            continue
        if not (root / path).exists(follow_symlinks=False):
            continue
        if path.name == "AGENTS.md":
            fix = "delete the link" if (root / path).is_symlink() else MOVE_LINES
            found.append(
                error(
                    path,
                    "no-agents-md",
                    f"{fix}; Claude Code reads {ROOT.path}, and no other agent harness is supported",
                )
            )
        if path.name == AGENT_FILE_NAME and agent_file_of(path) is None:
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


def read_tree(top: str | None, arguments: list[str]) -> tuple[Tree, list[pathlib.PurePosixPath]]:
    """Return the tree and the files to check: the arguments, or every tracked file when there are none.

    The root is the top of the repository that git names, or the working directory for arguments outside one.
    Raises RefusalError without arguments outside a repository, or when git cannot list the tracked files.
    """
    if not arguments and not top:
        raise RefusalError("not inside a git repository, so no tracked files to check; pass the files as arguments")
    root = pathlib.Path(top.strip()) if top else pathlib.Path.cwd()
    tree = Tree(root, tracked_files(root))
    if arguments:
        return tree, given_files(root, arguments)
    if tree.tracked is None:
        raise RefusalError(f"git cannot list the tracked files of {root}")
    return tree, sorted(tree.tracked)


def main(arguments: list[str]) -> int:
    """Check the files and return the exit status: 0 when all holds, 1 on a violation, 2 when the run cannot check."""
    top = git("rev-parse", "--show-toplevel")
    try:
        tree, paths = read_tree(top, arguments)
    except RefusalError as refusal:
        print(f"validate-documents: {refusal}", file=sys.stderr)
        return 2
    found = check(tree, paths)
    for line in found:
        print(line, file=sys.stderr)
    if found:
        print(f"validate-documents: {len(found)} error(s)", file=sys.stderr)
        return 1
    print("validate-documents: ok")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
