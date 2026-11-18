# ruff: noqa: INP001  # a module beside the script that imports it, which no package holds
"""The root modules that the rule files at the default branch of origin declare unprotected, read with git.

The default branch is the one that origin's HEAD names when the tool asks origin, and the tool reads it only when
refs/remotes/origin/HEAD names the same branch at the same commit, so a local ref that the agent set, or one not
fetched since origin changed, never decides.
"""

import collections.abc as ct
import dataclasses
import os
import pathlib
import re
import shlex
import subprocess
import typing as t

DEFAULT_BRANCH = "refs/remotes/origin/HEAD"
REMOTE_BRANCHES = "refs/remotes/origin/"
BRANCHES = "refs/heads/"
SYMBOLIC = f"ref: {BRANCHES}"
ORIGIN = "origin"
ORIGIN_URL = f"remote.{ORIGIN}.url"
ORIGIN_HEAD = ("ls-remote", "--symref", ORIGIN, "HEAD")
ORIGIN_SECONDS = 60
FETCH = "Run `git fetch origin` and `git remote set-head origin --auto`, and propose again."
GIT_MISSING = "git-missing: the tool runs git, which lyngon.scriptTools puts on the PATH"
RULES = ".claude/rules/"
UNPROTECTED_ROOTS = "unprotected-roots"
REGULAR_FILES = frozenset({"100644", "100755"})
LIST_ITEM = re.compile(r"( *)- (\S+)")
PLAIN_COMPONENT = re.compile(r"[A-Za-z0-9_.-]+")


class GitError(Exception):
    """git is missing, or a git command failed. The message names the refusal and what git said."""


class UnreadableError(Exception):
    """A rule file names unprotected-roots in a form the tool does not read. The message says why, as a clause."""


class UndeclaredError(Exception):
    """The tool cannot tell which commit is the default branch of origin. The message says why and what to do."""


@dataclasses.dataclass(frozen=True, slots=True)
class Declaration:
    """What the rule files declare at the commit of the default branch of origin.

    `roots` holds each directory listed under unprotected-roots with the rule file that lists it, and `unreadable`
    each rule file that names unprotected-roots in a form the tool does not read, with why.
    """

    branch: str
    commit: str
    roots: tuple[tuple[str, str], ...]
    unreadable: tuple[tuple[str, str], ...]

    def covering(self, root_module: str) -> tuple[str, str] | None:
        """Return the rule file and the directory that cover a root module, at it or above it, or None."""
        module = pathlib.PurePosixPath(root_module)
        return next(((path, directory) for path, directory in self.roots if module.is_relative_to(directory)), None)


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

    Raises UnreadableError for any line before that key that is no item, for no item at all, for items indented
    differently, and for a comment at any indent, since items may follow it that YAML still counts.
    """
    items: list[tuple[int, str]] = []
    for line in lines:
        if line.lstrip().startswith("#"):
            raise UnreadableError(f"`{line.strip()}` under it is a comment")
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
    """Run git from the root of the repository and capture its output. Raises GitError when git is missing.

    git ignores the replacement objects under refs/replace/, so that it reads each commit as origin holds it.
    """
    try:
        return subprocess.run(["git", "--no-replace-objects", *arguments], cwd=root, capture_output=True, check=False)
    except FileNotFoundError:
        raise GitError(GIT_MISSING) from None


def printed(result: subprocess.CompletedProcess[bytes]) -> str:
    """Return what a git command printed. Raises GitError, with what git said, when it failed."""
    if result.returncode != 0:
        command = shlex.join(t.cast("list[str]", result.args))
        said = result.stderr.decode(errors="replace").strip()
        raise GitError(f"git-failed: `{command}` exited {result.returncode}: {said}")
    return result.stdout.decode(errors="replace")


def branch_of(root: pathlib.Path) -> str | None:
    """Return the branch that HEAD is on, its full name without refs/heads/, or None when HEAD is detached.

    The full name, since git shortens refs/heads/main to heads/main when a tag or another ref is named main too.
    """
    result = git(root, "symbolic-ref", "--quiet", "HEAD")
    return None if result.returncode == 1 else printed(result).strip().removeprefix(BRANCHES)


def origin_default(root: pathlib.Path) -> tuple[str, str]:
    """Return the branch that origin's HEAD names, and its commit, as origin says now.

    Raises UndeclaredError when no remote is named origin, when origin cannot be reached or its HEAD names no branch.
    """
    url = git(root, "config", "--get", ORIGIN_URL)
    if url.returncode == 1 or not printed(url).strip():
        message = (
            f"No remote is named `{ORIGIN}`, since `git config --get {ORIGIN_URL}` prints nothing,"
            " so the tool cannot read its default branch."
        )
        raise UndeclaredError(message)
    command = ["git", *ORIGIN_HEAD]
    unreachable = f"origin cannot be reached, so the tool cannot read its default branch: `{shlex.join(command)}`"
    fetch_later = "Fetch origin once it can be reached, and propose again."
    try:
        result = subprocess.run(
            command,
            cwd=root,
            env={**os.environ, "GIT_TERMINAL_PROMPT": "0"},
            stdin=subprocess.DEVNULL,
            capture_output=True,
            timeout=ORIGIN_SECONDS,
            check=False,
        )
    except FileNotFoundError:
        raise GitError(GIT_MISSING) from None
    except subprocess.TimeoutExpired:
        raise UndeclaredError(f"{unreachable} ran longer than {ORIGIN_SECONDS} seconds. {fetch_later}") from None
    if result.returncode != 0:
        said = " ".join(result.stderr.decode(errors="replace").split())
        raise UndeclaredError(f"{unreachable} exited {result.returncode}: {said} {fetch_later}")
    printed_lines = result.stdout.decode(errors="replace").splitlines()
    heads = [line.removesuffix("\tHEAD") for line in printed_lines if line.endswith("\tHEAD")]
    named = [head.removeprefix(SYMBOLIC) for head in heads if head.startswith(SYMBOLIC)]
    commits = [head for head in heads if not head.startswith("ref: ")]
    if len(named) != 1 or len(commits) != 1:
        raise UndeclaredError("origin's HEAD names no branch, so the tool cannot read its default branch.")
    return named[0], commits[0]


def fetched_default(root: pathlib.Path) -> tuple[str | None, str | None]:
    """Return the branch that refs/remotes/origin/HEAD names and its commit, each None when it names none."""
    named = git(root, "symbolic-ref", "--quiet", DEFAULT_BRANCH)
    found = git(root, "rev-parse", "--verify", "--quiet", "--end-of-options", f"{DEFAULT_BRANCH}^{{commit}}")
    branch = printed(named).strip().removeprefix(REMOTE_BRANCHES) if named.returncode == 0 else None
    return branch, printed(found).strip() if found.returncode == 0 else None


def declaration_of(root: pathlib.Path) -> Declaration:
    """Read the rule files at the default branch of origin.

    Raises UndeclaredError when origin cannot be reached, when its HEAD names no branch, and when
    refs/remotes/origin/HEAD names another branch or another commit than origin's HEAD does. Raises GitError when git
    is missing or fails.
    """
    branch, commit = origin_default(root)
    fetched_branch, fetched_commit = fetched_default(root)
    if (fetched_branch, fetched_commit) != (branch, commit):
        if fetched_commit is None:
            fetched = f"`{DEFAULT_BRANCH}` is missing"
        elif fetched_branch is None:
            fetched = f"`{DEFAULT_BRANCH}` names `{fetched_commit}` and no branch"
        else:
            fetched = f"`{DEFAULT_BRANCH}` names `{fetched_branch}` at `{fetched_commit}`"
        raise UndeclaredError(f"{fetched}, while origin's default branch is `{branch}` at `{commit}`. {FETCH}")
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
    return Declaration(branch=branch, commit=commit, roots=tuple(roots), unreadable=tuple(unreadable))
