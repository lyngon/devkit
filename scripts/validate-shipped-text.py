#!/usr/bin/env python3
"""Check the text that the plugins ship.

Shipped text is what an agent can read from an installed plugin: every file
under a local plugin's skills/, commands/, agents/ and hooks/ directories, with
a link into shared/ read as the document it points at, and every document
under shared/. A plugin's README.md, its eval cases and its licenses are not
shipped text: a README is read in this repository, by a person.

Three checks:

- A skill reference names a skill or an agent that exists. A plugin assumes
  every other plugin of the bundle, so its text names their skills and agents
  freely, and nothing else fails when one is renamed or removed and a pointer
  to it stays. The skills of a pinned plugin are not in this tree, so a
  reference to one passes when the marketplace lists the plugin.
- `writing` stands alone. It is the one plugin that is installed outside a
  Lyngon development repository, so its text names no skill of another plugin
  and no term of such a repository.
- The structure is a choice per repository. Every other plugin assumes a Lyngon
  development repository, which has the documents, devenv and the baseline but
  not always the structure, so a term of the structure stands in a section
  headed `With the Lyngon structure`. An agent reads such a section as "only
  where the repository adopted the structure".

Usage: validate-shipped-text.py [<root>]

Checks the tree at <root>, which the commit hook sets to a checkout of the
index, or else the working tree of the repository around the working
directory, untracked files included. Exits 1 when a check fails.
"""

import collections.abc as ct
import dataclasses
import json
import os
import pathlib
import re
import subprocess
import sys
import typing as t

# The directories of a plugin whose files reach an agent.
COMPONENTS: tuple[str, ...] = ("skills", "commands", "agents", "hooks")

# A skill reference is two names in kebab-case, each starting with a letter,
# joined by a colon with nothing around it: `<plugin>:<skill>`. A slash may
# stand before it, as in a slash command. Claude Code names an agent of a
# plugin the same way, `<plugin>:<agent>`, so the right side may be an agent.
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
_NAME: str = r"[a-z][a-z0-9]*(?:-[a-z0-9]+)*"
REFERENCE: re.Pattern[str] = re.compile(rf"(?<![\w./:-])/?({_NAME}):({_NAME})(?![\w-])")

# The left sides that other tools own, each with the text it stands in. A
# plugin of that name wins over the entry, so the list can never hide a skill.
NAMESPACES: ct.Mapping[str, str] = {
    "blob": "git's partial clone filter, --filter=blob:none",
    "file": "a place in a file, file:line",
    "github": "a flake reference, github:owner/repository",
    "in": "a GitHub search qualifier, in:title",
    "node": "a Node builtin module, node:fs",
}

# The plugin that assumes nothing: no other plugin, and no Lyngon development
# repository around it.
STANDALONE: str = "writing"

# The one conditional heading, at any level. Its section runs to the next
# heading of the same or a higher level.
STRUCTURE_HEADING: str = "With the Lyngon structure"

# The plugins that write about the structure outside such a section: `repo`
# sets the structure up and creates the packages in it, and `devkit` maintains
# the document that defines it.
STRUCTURE_ASSUMED: tuple[str, ...] = ("repo", "devkit")

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
    """The plugins that the manifest lists.

    These are the directory of each local one by its name, and the names of the
    pinned ones, whose files the tree does not hold.
    """

    local: ct.Mapping[str, pathlib.Path]
    pinned: frozenset[str]


@dataclasses.dataclass(frozen=True, slots=True)
class Finding:
    """One failure, at a line of a file named by its path from the repository root."""

    path: str
    line: int
    message: str


def repository_root() -> pathlib.Path:
    """Return the root of the git repository that holds the working directory."""
    found = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True, check=False)
    if found.returncode != 0:
        raise ValidationError("not inside a git repository")
    return pathlib.Path(found.stdout.strip()).resolve()


def read_marketplace(root: pathlib.Path) -> Marketplace:
    """Read the manifest. Raises ValidationError when it is missing, is not JSON or has no list of plugins."""
    manifest = root / ".claude-plugin" / "marketplace.json"
    try:
        data = t.cast("object", json.loads(manifest.read_text()))
    except (OSError, json.JSONDecodeError) as error:
        raise ValidationError(f"cannot read .claude-plugin/marketplace.json: {error}") from error
    # The keys of a JSON object are strings.
    entries = t.cast("dict[str, object]", data).get("plugins") if isinstance(data, dict) else None
    if not isinstance(entries, list):
        raise ValidationError(".claude-plugin/marketplace.json has no list 'plugins'")
    local: dict[str, pathlib.Path] = {}
    pinned: set[str] = set()
    for entry in t.cast("list[object]", entries):
        fields = t.cast("dict[str, object]", entry) if isinstance(entry, dict) else {}
        name, source = fields.get("name"), fields.get("source")
        if not isinstance(name, str):
            continue
        if isinstance(source, str):
            local[name] = root / source
        else:
            pinned.add(name)
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
    """Return the files of one plugin that hold shipped text, by their paths inside the plugin."""
    return [path for component in COMPONENTS for path in files_below(directory / component)]


def shipped_files(root: pathlib.Path, marketplace: Marketplace) -> list[pathlib.Path]:
    """Return the files that hold shipped text, each once.

    A document that plugins link is the one file under shared/, however many
    links lead to it.
    """
    found = [path.resolve() for directory in marketplace.local.values() for path in plugin_files(directory)]
    found += [path.resolve() for path in files_below(root / "shared") if not path.name.startswith("LICENSE")]
    return sorted(set(found))


def displayed(path: pathlib.Path, root: pathlib.Path) -> str:
    """Return the path as a message names it: from the repository root, also for a file that a link leads out of it."""
    return pathlib.Path(os.path.relpath(path, root)).as_posix()


def read_lines(path: pathlib.Path) -> list[str]:
    """Return the lines of a text file, and none for a file that is not text."""
    try:
        return path.read_text(encoding="utf-8").splitlines()
    except UnicodeDecodeError:
        return []


def references(line: str, marketplace: Marketplace) -> ct.Iterator[tuple[str, str]]:
    """Yield the skill references of a line, each as its plugin and its skill."""
    for match in REFERENCE.finditer(line):
        plugin, skill = match.group(1), match.group(2)
        if plugin in NAMESPACES and plugin not in marketplace.local and plugin not in marketplace.pinned:
            continue
        yield plugin, skill


def unresolved(plugin: str, name: str, root: pathlib.Path, marketplace: Marketplace) -> str | None:
    """Why the reference names neither a skill nor an agent, or None when it names one.

    An agent resolves by its file, agents/<name>.md directly in the plugin,
    because validate-marketplace holds the name in its frontmatter to the name
    of its file, and Claude Code names it after the frontmatter.
    """
    directory = marketplace.local.get(plugin)
    if directory is not None:
        skill_file = directory / "skills" / name / "SKILL.md"
        agent_file = directory / "agents" / f"{name}.md"
        if skill_file.is_file() or agent_file.is_file():
            return None
        return (
            f"names '{plugin}:{name}', and neither the skill {displayed(skill_file, root)} "
            f"nor the agent {displayed(agent_file, root)} exists"
        )
    # The skills of a pinned plugin are in its upstream, not in this tree, so
    # a reference to one is taken on trust once the plugin is listed.
    if plugin in marketplace.pinned:
        return None
    return (
        f"names '{plugin}:{name}', and the marketplace has no plugin '{plugin}'; if this is no skill or agent, "
        "write it another way or add its left side to NAMESPACES in scripts/validate-shipped-text.py"
    )


def check_references(root: pathlib.Path, marketplace: Marketplace) -> list[Finding]:
    """Return a finding for every skill reference in shipped text that names neither a skill nor an agent."""
    return [
        Finding(path=displayed(path, root), line=number, message=reason)
        for path in shipped_files(root, marketplace)
        for number, line in enumerate(read_lines(path), 1)
        for plugin, name in references(line, marketplace)
        if (reason := unresolved(plugin, name, root, marketplace)) is not None
    ]


def check_standalone(root: pathlib.Path, marketplace: Marketplace) -> list[Finding]:
    """Return the findings in the text of the plugin that stands alone.

    A finding is every skill of another plugin, and the first development term
    of every line. A document it links from shared/ counts as its text, and no
    heading makes a line conditional.
    """
    directory = marketplace.local.get(STANDALONE)
    if directory is None:
        return []
    terms = [term for group in TERMS.values() for term in group]
    findings: list[Finding] = []
    for path in plugin_files(directory):
        for number, line in enumerate(read_lines(path), 1):
            reasons = [
                (
                    f"names the skill '{plugin}:{skill}', and {STANDALONE} assumes no other plugin, "
                    "so its text names only its own skills"
                )
                for plugin, skill in references(line, marketplace)
                if plugin != STANDALONE
            ]
            if (term := next((term for term in terms if term in line), None)) is not None:
                reasons.append(
                    (
                        f"names '{term}', a term of a Lyngon development repository, "
                        f"and {STANDALONE} assumes nothing about the repository it is installed in"
                    ),
                )
            findings += [Finding(path=displayed(path, root), line=number, message=reason) for reason in reasons]
    return findings


def unconditional_lines(path: pathlib.Path) -> ct.Iterator[tuple[int, str]]:
    """Yield the lines of a file that no structure section holds, each with its number.

    The frontmatter of a SKILL.md is left out: its name, description and paths
    say when a skill loads, not what an agent does. A heading inside a fenced
    block opens and closes nothing.
    """
    lines = read_lines(path)
    body_starts = 1
    if path.name == "SKILL.md" and lines and lines[0] == "---":
        body_starts = next((number for number, line in enumerate(lines[1:], 2) if line == "---"), 0) + 1
    section_level: int | None = None
    fenced = False
    for number, line in enumerate(lines[body_starts - 1 :], body_starts):
        if line.startswith("```"):
            fenced = not fenced
        elif not fenced and (heading := re.match(r"^(#+) (.*)$", line)) is not None:
            level = len(heading.group(1))
            if section_level is not None and level <= section_level:
                section_level = None
            if section_level is None and heading.group(2).strip() == STRUCTURE_HEADING:
                section_level = level
        if section_level is None:
            yield number, line


def check_structure(root: pathlib.Path, marketplace: Marketplace) -> list[Finding]:
    """Return a finding for the first structure term of every line outside a structure section.

    The lines are those of every plugin that does not assume the structure. The
    plugin that stands alone is left to its own check, which no section satisfies.
    """
    return [
        Finding(
            path=displayed(path, root),
            line=number,
            message=(
                f"names '{term}' outside a section '{STRUCTURE_HEADING}'; the structure is a choice per "
                f"repository, so only {' and '.join(STRUCTURE_ASSUMED)} write about it anywhere else"
            ),
        )
        for name, directory in marketplace.local.items()
        if name not in STRUCTURE_ASSUMED and name != STANDALONE
        for path in plugin_files(directory)
        for number, line in unconditional_lines(path)
        if (term := next((term for term in TERMS["structure"] if term in line), None)) is not None
    ]


def main(arguments: ct.Sequence[str]) -> int:
    """Check the tree at the one argument, or the repository's; print what fails and return 1 then, else 0."""
    try:
        root = pathlib.Path(arguments[0]).resolve() if arguments else repository_root()
        marketplace = read_marketplace(root)
        findings = [
            *check_references(root, marketplace),
            *check_standalone(root, marketplace),
            *check_structure(root, marketplace),
        ]
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
    sys.exit(main(sys.argv[1:]))
