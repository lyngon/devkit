# ruff: noqa: INP001  # a module beside the script that imports it, which no package holds
"""The root modules that the rule files at the default branch of origin declare unprotected, read with git."""

import collections.abc as ct
import dataclasses
import pathlib
import re
import shlex
import subprocess
import typing as t

DEFAULT_BRANCH = "refs/remotes/origin/HEAD"
RULES = ".claude/rules/"
UNPROTECTED_ROOTS = "unprotected-roots"
REGULAR_FILES = frozenset({"100644", "100755"})
LIST_ITEM = re.compile(r"( *)- (\S+)")
PLAIN_COMPONENT = re.compile(r"[A-Za-z0-9_.-]+")


class GitError(Exception):
    """git is missing, or a git command failed. The message names the refusal and what git said."""


class UnreadableError(Exception):
    """A rule file names unprotected-roots in a form the tool does not read. The message says why, as a clause."""


@dataclasses.dataclass(frozen=True, slots=True)
class Declaration:
    """What the rule files declare at a commit of the default branch.

    `roots` holds each directory listed under unprotected-roots with the rule file that lists it, and `unreadable`
    each rule file that names unprotected-roots in a form the tool does not read, with why.
    """

    commit: str
    roots: tuple[tuple[str, str], ...]
    unreadable: tuple[tuple[str, str], ...]


def plain_directory(text: str) -> str:
    """Return a directory that a rule file lists, without `.` or a trailing slash.

    Raises UnreadableError for one that is empty, absolute, holds `..` or any character beyond letters, digits,
    `_`, `.`, `-` and `/`, such as a glob's.
    """
    path = pathlib.PurePosixPath(text)
    plain = all(PLAIN_COMPONENT.fullmatch(part) for part in path.parts)
    if not path.parts or path.is_absolute() or ".." in path.parts or not plain:
        raise UnreadableError(f"`{text}` is no plain relative directory")
    return str(path)


def frontmatter(text: str) -> list[str]:
    """Return the lines between a file's opening and closing `---`, none when it opens with no `---`.

    Raises UnreadableError for frontmatter that never closes and names unprotected-roots.
    """
    lines = text.splitlines()
    if not lines or lines[0].rstrip() != "---":
        return []
    end = next((number for number, line in enumerate(lines) if number > 0 and line.rstrip() == "---"), None)
    if end is None:
        if UNPROTECTED_ROOTS in text:
            raise UnreadableError("its frontmatter has no closing `---`")
        return []
    return lines[1:end]


def block_list(lines: ct.Sequence[str]) -> tuple[str, ...]:
    """Return the items of the block list that the lines open with, up to the next key.

    Raises UnreadableError for any line before that key that is no item, for no item at all, and for items
    indented differently.
    """
    items: list[tuple[int, str]] = []
    for line in lines:
        if line and not line.startswith((" ", "-")):
            break
        if not line.strip():
            continue
        item = LIST_ITEM.fullmatch(line.rstrip())
        if item is None:
            raise UnreadableError(f"`{line.strip()}` under it is no item of a block list")
        items.append((len(item.group(1)), item.group(2)))
    if not items:
        raise UnreadableError("it lists no directory under it")
    if len({indent for indent, _ in items}) > 1:
        raise UnreadableError("the items under it are indented differently")
    return tuple(value for _, value in items)


def declared_roots(text: str) -> tuple[str, ...]:
    """Return the directories that a rule file's frontmatter lists under unprotected-roots, none without the key.

    Raises UnreadableError when the file names the key and its value is anything but a block list of plain
    relative directories. The reader refuses what it is in doubt about, since a refusal only makes a run wait.
    """
    front = frontmatter(text)
    named = [number for number, line in enumerate(front) if UNPROTECTED_ROOTS in line]
    if not named:
        return ()
    if len(named) > 1 or front[named[0]].rstrip() != f"{UNPROTECTED_ROOTS}:":
        raise UnreadableError(f"it names {UNPROTECTED_ROOTS} other than once, on a line `{UNPROTECTED_ROOTS}:` alone")
    return tuple(plain_directory(value) for value in block_list(front[named[0] + 1 :]))


def git(root: pathlib.Path, *arguments: str) -> subprocess.CompletedProcess[bytes]:
    """Run git from the root of the repository and capture its output. Raises GitError when git is missing."""
    try:
        return subprocess.run(["git", *arguments], cwd=root, capture_output=True, check=False)
    except FileNotFoundError:
        raise GitError("git-missing: the tool runs git, which lyngon.scriptTools puts on the PATH") from None


def printed(result: subprocess.CompletedProcess[bytes]) -> str:
    """Return what a git command printed. Raises GitError, with what git said, when it failed."""
    if result.returncode != 0:
        command = shlex.join(t.cast("list[str]", result.args))
        said = result.stderr.decode(errors="replace").strip()
        raise GitError(f"git-failed: `{command}` exited {result.returncode}: {said}")
    return result.stdout.decode(errors="replace")


def branch_of(root: pathlib.Path) -> str | None:
    """Return the branch that HEAD is on, or None when HEAD is detached."""
    result = git(root, "symbolic-ref", "--quiet", "--short", "HEAD")
    return None if result.returncode == 1 else printed(result).strip()


def declaration_of(root: pathlib.Path) -> Declaration | None:
    """Read the rule files as they are at the default branch of origin. Returns None when that ref is missing."""
    found = git(root, "rev-parse", "--verify", "--quiet", "--end-of-options", f"{DEFAULT_BRANCH}^{{commit}}")
    if found.returncode == 1:
        return None
    commit = printed(found).strip()
    roots: list[tuple[str, str]] = []
    unreadable: list[tuple[str, str]] = []
    for entry in filter(None, printed(git(root, "ls-tree", "-z", commit, "--", RULES)).split("\0")):
        details, _, path = entry.partition("\t")
        mode, kind, blob = details.split(" ")
        if kind != "blob" or mode not in REGULAR_FILES or not path.endswith(".md"):
            continue
        text = printed(git(root, "cat-file", "blob", blob))
        try:
            roots.extend((path, directory) for directory in declared_roots(text))
        except UnreadableError as error:
            unreadable.append((path, str(error)))
    return Declaration(commit=commit, roots=tuple(roots), unreadable=tuple(unreadable))
