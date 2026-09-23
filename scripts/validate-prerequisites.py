#!/usr/bin/env python3
# Check every local plugin against docs/conventions/prerequisites.md: the
# README declares its prerequisites on one `Prerequisites:` line, no file an
# agent can read names a prerequisite the plugin has not declared outside a
# conditional section, a skill whose paths are all devenv files is conditional
# on devenv as a whole, and a bundle declares the union of its members.
# Runs from anywhere inside the repository. Pinned plugins are skipped.
import json
import os
import re
import subprocess
import sys
from pathlib import Path

ORDER = ["documents", "devenv", "structure"]
TERMS = {
    "documents": [
        "CONCEPTS.md", "docs/adr", "INTENT.md", "CLAUDE.md", "AGENTS.md",
        "docs/TODO.md", "docs/conventions",
    ],
    "devenv": [
        "devenv", "secretspec", "git-hooks", "enterTest", ".pre-commit-config",
        "prose-lint", "markdownlint", "nixfmt", "shellcheck", "ruff", "prettier",
        "commitizen", "typos", "ripsecrets", "actionlint", "yamllint", "deadnix",
        "statix", "golangci-lint",
    ],
    "structure": [
        "apps/", "libs/", "contracts/", "tools/", "infra/", "STRUCTURE.md",
        "add-package", "validate-structure",
    ],
}
HEADINGS = {
    "With the Lyngon documents": "documents",
    "With devenv": "devenv",
    "With the Lyngon structure": "structure",
}
EXTENSIONS = {".md", ".txt", ".sh"}
SKIPPED_NAMES = {"CHANGELOG.md", "UPSTREAM.md"}
COMPONENTS = ["skills", "commands", "agents", "hooks"]

errors: list[str] = []


def fail(path: str, message: str) -> None:
    errors.append(f"error: {path}: {message}")


def repo_root() -> Path:
    try:
        out = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            capture_output=True, text=True, check=True,
        ).stdout.strip()
        return Path(out)
    except (OSError, subprocess.CalledProcessError):
        return Path.cwd()


def rel(root: Path, path: Path) -> str:
    return os.path.relpath(os.path.normpath(path), root).replace(os.sep, "/")


def read_json(path: Path) -> dict:
    try:
        data = json.loads(path.read_text())
        return data if isinstance(data, dict) else {}
    except (OSError, json.JSONDecodeError) as exc:
        fail(str(path), f"cannot parse: {exc}")
        return {}


def declared_line(names: list[str]) -> str:
    return "Prerequisites: " + (", ".join(names) if names else "git")


# --- Declarations ------------------------------------------------------------

def read_declaration(root: Path, plugin: Path) -> list[str] | None:
    """The prerequisites the plugin README declares, in canonical order, or
    None when the declaration is missing or malformed."""
    readme = plugin / "README.md"
    display = rel(root, readme)
    if not readme.is_file():
        fail(display, "is missing")
        return None
    found = [m.group(1) for line in readme.read_text().splitlines()
             if (m := re.match(r"^Prerequisites: (.+)$", line))]
    if len(found) != 1:
        fail(display, f"needs exactly one 'Prerequisites:' line, found {len(found)}")
        return None
    value = found[0].strip()
    if value == "git":
        return []
    names = [n.strip() for n in value.split(",")]
    for name in names:
        if name not in ORDER:
            fail(display, f"unknown prerequisite '{name}'; use {', '.join(ORDER)} or git")
            return None
    if names != [n for n in ORDER if n in names]:
        fail(display, f"prerequisites must be listed once each in the order {', '.join(ORDER)}")
        return None
    return names


# --- Text --------------------------------------------------------------------

def text_files(plugin: Path) -> list[Path]:
    """Every file an agent can read, through symlinks, except the plugin
    README, the changelog, provenance, licenses and evals."""
    files = []
    for dirpath, dirnames, filenames in os.walk(plugin, followlinks=True):
        dirnames[:] = sorted(d for d in dirnames if d != "evals")
        for name in sorted(filenames):
            path = Path(dirpath) / name
            if path.suffix not in EXTENSIONS or name in SKIPPED_NAMES or name.startswith("LICENSE"):
                continue
            if name == "README.md" and path.parent == plugin:
                continue
            if path.is_file():
                files.append(path)
    return files


def frontmatter_paths(lines: list[str]) -> list[str] | None:
    """The `paths:` entries of a SKILL.md frontmatter, given as a block list
    or as one comma-separated string. None when there is no frontmatter or
    no paths key."""
    if not lines or lines[0].strip() != "---":
        return None
    paths: list[str] | None = None
    for line in lines[1:]:
        if line.strip() == "---":
            break
        if key := re.match(r"^paths:\s*(.*)$", line):
            if value := key.group(1).strip().strip("'\"[]"):
                return [p.strip().strip("'\"") for p in value.split(",") if p.strip()]
            paths = []
        elif paths is not None:
            if item := re.match(r"^\s+-\s*(.+)$", line):
                paths.append(item.group(1).strip().strip("'\""))
            else:
                break
    return paths


def check_file(path: Path, display: str, declared: list[str]) -> None:
    lines = path.read_text(errors="replace").splitlines()
    always = set(declared)
    if path.name == "SKILL.md":
        paths = frontmatter_paths(lines)
        if paths and all(p.endswith(".nix") or p == "devenv.yaml" for p in paths):
            always.add("devenv")
    open_sections: list[tuple[int, str]] = []
    fenced = False
    for number, line in enumerate(lines, 1):
        if line.startswith("```"):
            fenced = not fenced
        elif not fenced and (heading := re.match(r"^(#+) (.*)$", line)):
            level = len(heading.group(1))
            open_sections = [(lv, p) for lv, p in open_sections if lv < level]
            if name := HEADINGS.get(heading.group(2).strip()):
                open_sections.append((level, name))
        allowed = always | {p for _, p in open_sections}
        for prerequisite, terms in TERMS.items():
            if prerequisite in allowed:
                continue
            if term := next((t for t in terms if t in line), None):
                fail(f"{display}:{number}", f"names '{term}' but the plugin declares prerequisites: "
                     + (", ".join(declared) or "none"))
                break


# --- Bundles -----------------------------------------------------------------

def dependency_names(manifest: dict) -> list[str]:
    deps = manifest.get("dependencies", [])
    return [d if isinstance(d, str) else d.get("name", "") for d in deps if isinstance(d, (str, dict))]


def union(name: str, manifests: dict[str, dict], declared: dict[str, list[str] | None], seen: set[str]) -> set[str]:
    if name in seen or name not in manifests:
        return set()
    seen.add(name)
    result = set(declared.get(name) or [])
    for dep in dependency_names(manifests[name]):
        result |= union(dep, manifests, declared, seen)
    return result


def check_bundle(root: Path, name: str, plugin: Path, manifests: dict[str, dict], declared: dict[str, list[str] | None]) -> None:
    deps = dependency_names(manifests[name])
    if not deps or any((plugin / c).exists() for c in COMPONENTS) or declared[name] is None:
        return
    expected = set()
    for dep in deps:
        expected |= union(dep, manifests, declared, set())
    expected_names = [n for n in ORDER if n in expected]
    if declared[name] != expected_names:
        fail(rel(root, plugin / "README.md"), "bundle must declare the union of its dependencies: "
             + declared_line(expected_names))


def main() -> int:
    root = repo_root()
    marketplace = read_json(root / ".claude-plugin" / "marketplace.json")
    plugins = {}
    for entry in marketplace.get("plugins", []):
        source = entry.get("source") if isinstance(entry, dict) else None
        if isinstance(source, str) and source.startswith("./plugins/"):
            plugins[entry.get("name", "")] = root / source[2:]
    manifests = {n: read_json(p / ".claude-plugin" / "plugin.json") for n, p in plugins.items()}
    declared = {n: read_declaration(root, p) for n, p in plugins.items()}
    for name, plugin in plugins.items():
        names = declared[name]
        if names is None:
            continue
        for path in text_files(plugin):
            check_file(path, rel(root, path), names)
        check_bundle(root, name, plugin, manifests, declared)
    for line in errors:
        print(line, file=sys.stderr)
    if errors:
        print(f"validate-prerequisites: {len(errors)} error(s)", file=sys.stderr)
        return 1
    print("validate-prerequisites: ok")
    return 0


if __name__ == "__main__":
    sys.exit(main())
