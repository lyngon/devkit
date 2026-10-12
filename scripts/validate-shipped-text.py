#!/usr/bin/env python3
"""Check the text that the plugins ship.

Shipped text is what an agent can read from an installed plugin: every file
under a local plugin's skills/, commands/, agents/ and hooks/ directories, with
a link into shared/ read as the document it points at, and every document
under shared/. A plugin's README.md, its eval cases and its licenses are not
shipped text: a README is read in this repository, by a person.

Two checks:

- A skill reference names a skill that exists. A plugin assumes every other
  plugin of the bundle, so its text names their skills freely, and nothing else
  fails when a skill is renamed or removed and a pointer to it stays.
- `writing` stands alone. It is the one plugin that is installed outside a
  Lyngon development repository, so its text names no skill of another plugin
  and no term of such a repository.

Runs from anywhere inside the repository. Exits 1 when a check fails.
"""

import collections.abc as ct
import dataclasses
import json
import os
import pathlib
import re
import subprocess
import sys

# The directories of a plugin whose files reach an agent.
COMPONENTS = ("skills", "commands", "agents", "hooks")

# A skill reference is two names in kebab-case, each starting with a letter,
# joined by a colon with nothing around it: `<plugin>:<skill>`. A slash may
# stand before it, as in a slash command.
#
# A key and its value, a URL and a path have the same shape. Two rules tell
# them apart, and both lean toward failing, since a reference that is taken
# for other text passes unchecked.
#
# 1. The pair starts a word of its own. A letter, a digit, `_`, `.`, `/`, `:`
#    or `-` right before it makes it the tail of a path, a URL or a longer
#    token, as in `src/recovery.js:41` and `https://example.com/a:b`. A right
#    side that starts with a digit is a line, a port or a time, never a skill.
# 2. A pair whose left side is in NAMESPACES below belongs to another tool.
#
# Every other pair is a skill reference and must resolve. One whose left side
# is no plugin of the marketplace fails as well: a pointer to a plugin that
# was removed is the stale reference this check exists for, and a list of the
# known plugins could not catch it.
_NAME = r"[a-z][a-z0-9]*(?:-[a-z0-9]+)*"
REFERENCE = re.compile(rf"(?<![\w./:-])/?({_NAME}):({_NAME})(?![\w-])")

# The left sides that other tools own, each with the text it stands in. A
# plugin of that name wins over the entry, so the list can never hide a skill.
NAMESPACES = {
    "blob": "git's partial clone filter, --filter=blob:none",
    "file": "a place in a file, file:line",
    "github": "a flake reference, github:owner/repository",
    "in": "a GitHub search qualifier, in:title",
    "node": "a Node builtin module, node:fs",
}

# The plugin that assumes nothing: no other plugin, and no Lyngon development
# repository around it.
STANDALONE = "writing"

# What only a Lyngon development repository has, by where it comes from: the
# documents, devenv, the baseline and the structure. A term is matched as it
# is written here, anywhere in a line, so `ruff` also fails "gruff". When a
# sentence trips a term it does not mean, reword the sentence.
TERMS: ct.Mapping[str, tuple[str, ...]] = {
    "documents": (
        "CONCEPTS.md",
        "docs/decisions",
        "INTENT.md",
        "CLAUDE.md",
        ".claude/rules",
        "docs/TODO.md",
        "docs/conventions",
    ),
    "devenv": ("devenv", "secretspec", "git-hooks", "enterTest", ".pre-commit-config"),
    "baseline": (
        "lyngon.enable",
        "lyngon.structure",
        "lyngon.mcp",
        "lyngon/devenv",
        "validate-documents",
        "prose-lint",
        "markdownlint",
        "nixfmt",
        "shellcheck",
        "ruff",
        "prettier",
        "commitizen",
        "typos",
        "ripsecrets",
        "actionlint",
        "yamllint",
        "deadnix",
        "statix",
        "golangci-lint",
        "ruff.toml",
        "tsconfig.base.json",
        "eslint.config.js",
        "basedpyright",
    ),
    "structure": (
        "apps/",
        "libs/",
        "contracts/",
        "tools/",
        "infra/",
        "STRUCTURE.md",
        "add-package",
        "validate-structure",
    ),
}


class ValidationError(Exception):
    """A tree that cannot be checked at all. The message is what the author reads."""


@dataclasses.dataclass(frozen=True, slots=True)
class Marketplace:
    """The plugins that the manifest lists: the directory of each local one by
    its name, and the names of the pinned ones, whose files the tree does not hold."""

    local: ct.Mapping[str, pathlib.Path]
    pinned: frozenset[str]


@dataclasses.dataclass(frozen=True, slots=True)
class Finding:
    """One failure, at a line of a file named by its path from the repository root."""

    path: str
    line: int
    message: str


def repository_root() -> pathlib.Path:
    """The root of the git repository that holds the working directory."""
    found = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True, check=False)
    if found.returncode != 0:
        raise ValidationError("not inside a git repository")
    return pathlib.Path(found.stdout.strip()).resolve()


def read_marketplace(root: pathlib.Path) -> Marketplace:
    """Read the manifest. Raises ValidationError when it is missing, is not JSON or has no list of plugins."""
    manifest = root / ".claude-plugin" / "marketplace.json"
    try:
        data = json.loads(manifest.read_text())
    except (OSError, json.JSONDecodeError) as error:
        raise ValidationError(f"cannot read .claude-plugin/marketplace.json: {error}") from error
    entries = data.get("plugins") if isinstance(data, dict) else None
    if not isinstance(entries, list):
        raise ValidationError(".claude-plugin/marketplace.json has no list 'plugins'")
    local: dict[str, pathlib.Path] = {}
    pinned: set[str] = set()
    for entry in entries:
        if not isinstance(entry, dict) or not isinstance(entry.get("name"), str):
            continue
        source = entry.get("source")
        if isinstance(source, str):
            local[entry["name"]] = root / source
        else:
            pinned.add(entry["name"])
    return Marketplace(local=local, pinned=frozenset(pinned))


def files_below(directory: pathlib.Path) -> list[pathlib.Path]:
    """Every file below a directory, in a fixed order, with links followed."""
    return sorted(
        pathlib.Path(parent) / name
        for parent, _, names in os.walk(directory, followlinks=True)
        for name in names
        if (pathlib.Path(parent) / name).is_file()
    )


def plugin_files(directory: pathlib.Path) -> list[pathlib.Path]:
    """The files of one plugin that hold shipped text, by their paths inside the plugin."""
    return [path for component in COMPONENTS for path in files_below(directory / component)]


def shipped_files(root: pathlib.Path, marketplace: Marketplace) -> list[pathlib.Path]:
    """The files that hold shipped text, each once: a document that plugins link is
    the one file under shared/, however many links lead to it."""
    found = [path.resolve() for directory in marketplace.local.values() for path in plugin_files(directory)]
    found += [path.resolve() for path in files_below(root / "shared") if not path.name.startswith("LICENSE")]
    return sorted(set(found))


def displayed(path: pathlib.Path, root: pathlib.Path) -> str:
    """The path as a message names it: from the repository root, also for a file that a link leads out of it."""
    return pathlib.Path(os.path.relpath(path, root)).as_posix()


def read_lines(path: pathlib.Path) -> list[str]:
    """The lines of a text file, and none for a file that is not text."""
    try:
        return path.read_text(encoding="utf-8").splitlines()
    except UnicodeDecodeError:
        return []


def references(line: str, marketplace: Marketplace) -> ct.Iterator[tuple[str, str]]:
    """The skill references of a line, each as its plugin and its skill."""
    for match in REFERENCE.finditer(line):
        plugin, skill = match.group(1), match.group(2)
        if plugin in NAMESPACES and plugin not in marketplace.local and plugin not in marketplace.pinned:
            continue
        yield plugin, skill


def unresolved(plugin: str, skill: str, root: pathlib.Path, marketplace: Marketplace) -> str | None:
    """Why the reference names no skill, or None when it names one."""
    directory = marketplace.local.get(plugin)
    if directory is not None:
        skill_file = directory / "skills" / skill / "SKILL.md"
        if skill_file.is_file():
            return None
        return f"names the skill '{plugin}:{skill}', and {displayed(skill_file, root)} does not exist"
    # The skills of a pinned plugin are in its upstream, not in this tree, so
    # a reference to one is taken on trust once the plugin is listed.
    if plugin in marketplace.pinned:
        return None
    return (
        f"names the skill '{plugin}:{skill}', and the marketplace has no plugin '{plugin}'; if this is not a skill, "
        "write it another way or add its left side to NAMESPACES in scripts/validate-shipped-text.py"
    )


def check_references(root: pathlib.Path, marketplace: Marketplace) -> list[Finding]:
    """A finding for every skill reference in shipped text that names no skill."""
    return [
        Finding(path=displayed(path, root), line=number, message=reason)
        for path in shipped_files(root, marketplace)
        for number, line in enumerate(read_lines(path), 1)
        for plugin, skill in references(line, marketplace)
        if (reason := unresolved(plugin, skill, root, marketplace)) is not None
    ]


def check_standalone(root: pathlib.Path, marketplace: Marketplace) -> list[Finding]:
    """A finding for every skill of another plugin, and for the first development
    term of every line, in the text of the plugin that stands alone. A document it
    links from shared/ counts as its text, and no heading makes a line conditional."""
    directory = marketplace.local.get(STANDALONE)
    if directory is None:
        return []
    terms = [term for group in TERMS.values() for term in group]
    findings: list[Finding] = []
    for path in plugin_files(directory):
        for number, line in enumerate(read_lines(path), 1):
            reasons = [
                f"names the skill '{plugin}:{skill}', and {STANDALONE} assumes no other plugin, "
                "so its text names only its own skills"
                for plugin, skill in references(line, marketplace)
                if plugin != STANDALONE
            ]
            if (term := next((term for term in terms if term in line), None)) is not None:
                reasons.append(
                    f"names '{term}', a term of a Lyngon development repository, "
                    f"and {STANDALONE} assumes nothing about the repository it is installed in"
                )
            findings += [Finding(path=displayed(path, root), line=number, message=reason) for reason in reasons]
    return findings


def main() -> int:
    """Print what fails and return the exit status: 0 when nothing does, 1 otherwise."""
    try:
        root = repository_root()
        marketplace = read_marketplace(root)
        findings = check_references(root, marketplace) + check_standalone(root, marketplace)
    except ValidationError as error:
        print(f"validate-shipped-text: {error}", file=sys.stderr)
        return 1
    for finding in findings:
        print(f"error: {finding.path}:{finding.line}: {finding.message}", file=sys.stderr)
    if findings:
        print(f"validate-shipped-text: {len(findings)} error(s)", file=sys.stderr)
        return 1
    print("validate-shipped-text: ok")
    return 0


if __name__ == "__main__":
    sys.exit(main())
