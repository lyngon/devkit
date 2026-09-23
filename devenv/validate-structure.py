#!/usr/bin/env python3
# Check a repository against the layout rules in shared/STRUCTURE.md section
# 4.4: nothing depends on an app, apps, libs and contracts never depend on
# tools or infra, every language workspace lists its members explicitly and
# completely, every app and library carries its four documents, and no path
# segment under apps/, libs/ or tools/ names a language. Runs at pre-commit
# with no arguments from anywhere inside the repository. A repository without
# any of the package directories (the devkit itself) passes.
import json
import os
import re
import subprocess
import sys
import tomllib
from dataclasses import dataclass, field
from pathlib import Path

MANIFESTS = {
    "pyproject.toml": "python",
    "package.json": "typescript",
    "Cargo.toml": "rust",
    "go.mod": "go",
}
PACKAGE_ROOTS = ["apps", "libs", "tools", "infra/modules", "infra/environments"]
LANGUAGE_NAMES = {
    "python", "typescript", "javascript", "rust", "go", "golang", "haskell",
    "java", "csharp", "dotnet", "c", "cpp", "nix", "shell", "terraform",
}
PACKAGE_DOCS = ["README.md", "INTENT.md", "CLAUDE.md"]

errors: list[str] = []


def fail(path: str, message: str) -> None:
    errors.append(f"error: {path}: {message}")


@dataclass
class Package:
    path: str  # relative to the repository root, forward slashes
    language: str
    name: str | None = None
    # Internal dependencies, as repository-relative paths once resolved.
    deps: list[str] = field(default_factory=list)


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


def normalise_pep503(name: str) -> str:
    return re.sub(r"[-_.]+", "-", name).lower()


def requirement_name(spec: str) -> str | None:
    match = re.match(r"\s*([A-Za-z0-9][A-Za-z0-9._-]*)", spec)
    return normalise_pep503(match.group(1)) if match else None


def read_toml(path: Path) -> dict:
    try:
        return tomllib.loads(path.read_text())
    except (OSError, tomllib.TOMLDecodeError) as exc:
        fail(str(path), f"cannot parse: {exc}")
        return {}


def read_json(path: Path) -> dict:
    try:
        data = json.loads(path.read_text())
        return data if isinstance(data, dict) else {}
    except (OSError, json.JSONDecodeError) as exc:
        fail(str(path), f"cannot parse: {exc}")
        return {}


# --- Discovery ---------------------------------------------------------------

def package_dirs(root: Path) -> list[Path]:
    """Every directory that may hold a package: direct children of the
    package roots, and children of each contract directory."""
    dirs = []
    for parent in PACKAGE_ROOTS:
        dirs += [d for d in sorted((root / parent).glob("*")) if d.is_dir()]
    for contract in sorted((root / "contracts").glob("*")):
        dirs += [d for d in sorted(contract.glob("*")) if d.is_dir()]
    return dirs


def discover(root: Path) -> list[Package]:
    packages = []
    for directory in package_dirs(root):
        for manifest, language in MANIFESTS.items():
            if (directory / manifest).is_file():
                packages.append(Package(rel(root, directory), language))
    return packages


# --- Dependency resolution per language --------------------------------------

def python_deps(root: Path, packages: list[Package]) -> None:
    by_name = {}
    manifests = {}
    for pkg in packages:
        manifests[pkg.path] = data = read_toml(root / pkg.path / "pyproject.toml")
        name = data.get("project", {}).get("name")
        if name:
            pkg.name = normalise_pep503(name)
            by_name[pkg.name] = pkg.path
    for pkg in packages:
        data = manifests[pkg.path]
        project = data.get("project", {})
        specs = list(project.get("dependencies", []))
        for group in project.get("optional-dependencies", {}).values():
            specs += group
        for group in data.get("dependency-groups", {}).values():
            specs += group
        names = {requirement_name(s) for s in specs if isinstance(s, str)}
        sources = data.get("tool", {}).get("uv", {}).get("sources", {})
        for name, source in sources.items():
            if isinstance(source, dict) and source.get("workspace"):
                names.add(normalise_pep503(name))
        pkg.deps = sorted(by_name[n] for n in names if n in by_name)


def typescript_deps(root: Path, packages: list[Package]) -> None:
    manifests = {p.path: read_json(root / p.path / "package.json") for p in packages}
    for pkg in packages:
        pkg.name = manifests[pkg.path].get("name")
    by_name = {p.name: p.path for p in packages if p.name}
    for pkg in packages:
        deps = set()
        for section in ("dependencies", "devDependencies", "peerDependencies"):
            for name, version in manifests[pkg.path].get(section, {}).items():
                if str(version).startswith("workspace:") or name in by_name:
                    deps.add(by_name.get(name, name))
        pkg.deps = sorted(deps)


def rust_deps(root: Path, packages: list[Package]) -> None:
    workspace = {}
    if (root / "Cargo.toml").is_file():
        workspace = read_toml(root / "Cargo.toml").get("workspace", {}).get("dependencies", {})
    manifests = {p.path: read_toml(root / p.path / "Cargo.toml") for p in packages}
    for pkg in packages:
        pkg.name = manifests[pkg.path].get("package", {}).get("name")
    by_name = {p.name: p.path for p in packages if p.name}
    for pkg in packages:
        deps = set()
        for section in ("dependencies", "dev-dependencies", "build-dependencies"):
            for name, spec in manifests[pkg.path].get(section, {}).items():
                if isinstance(spec, dict) and spec.get("workspace"):
                    spec = workspace.get(name, {})
                    base = root
                else:
                    base = root / pkg.path
                if isinstance(spec, dict) and "path" in spec:
                    deps.add(rel(root, base / spec["path"]))
                elif isinstance(spec, dict) and spec.get("package", name) in by_name:
                    deps.add(by_name[spec.get("package", name)])
                elif name in by_name:
                    deps.add(by_name[name])
        pkg.deps = sorted(deps)


def go_directives(text: str, keyword: str) -> list[str]:
    """The arguments of every `keyword x` line and `keyword ( ... )` block."""
    text = re.sub(r"//[^\n]*", "", text)
    found = re.findall(rf"^{keyword}\s+([^(\n][^\n]*)$", text, re.M)
    for block in re.findall(rf"^{keyword}\s*\(\s*\n(.*?)^\)", text, re.M | re.S):
        found += [line.strip() for line in block.splitlines() if line.strip()]
    return found


def go_deps(root: Path, packages: list[Package]) -> None:
    texts = {}
    for pkg in packages:
        texts[pkg.path] = text = (root / pkg.path / "go.mod").read_text()
        match = re.search(r"^module\s+(\S+)", text, re.M)
        pkg.name = match.group(1) if match else None
    by_name = {p.name: p.path for p in packages if p.name}
    for pkg in packages:
        deps = set()
        for line in go_directives(texts[pkg.path], "require"):
            module = line.split()[0]
            if module in by_name:
                deps.add(by_name[module])
        for line in go_directives(texts[pkg.path], "replace"):
            target = line.split("=>")[-1].split()[0] if "=>" in line else ""
            if target.startswith(("./", "../")):
                deps.add(rel(root, root / pkg.path / target))
        pkg.deps = sorted(deps)


RESOLVERS = {
    "python": python_deps,
    "typescript": typescript_deps,
    "rust": rust_deps,
    "go": go_deps,
}


# --- Workspaces --------------------------------------------------------------

def pnpm_members(path: Path) -> list[str] | None:
    """The top-level `packages:` list of pnpm-workspace.yaml, without a YAML
    library: a block list of quoted or unquoted strings is all pnpm needs."""
    members = None
    for raw in path.read_text().splitlines():
        line = re.sub(r"(^|\s)#.*$", "", raw).rstrip()
        if not line.strip():
            continue
        if flow := re.match(r"^packages:\s*\[(.*)\]\s*$", line):
            return [m.strip().strip("'\"") for m in flow.group(1).split(",") if m.strip()]
        if re.match(r"^packages:\s*$", line):
            members = []
            continue
        if members is not None and (item := re.match(r"^\s+-\s*(.+)$", line)):
            members.append(item.group(1).strip().strip("'\""))
            continue
        if members is not None:
            break
    return members


WORKSPACES = {
    "python": ("pyproject.toml", "[tool.uv.workspace] members",
               lambda p: read_toml(p).get("tool", {}).get("uv", {}).get("workspace", {}).get("members")),
    "typescript": ("pnpm-workspace.yaml", "packages", pnpm_members),
    "rust": ("Cargo.toml", "[workspace] members",
             lambda p: read_toml(p).get("workspace", {}).get("members")),
    "go": ("go.work", "use", lambda p: go_directives(p.read_text(), "use")),
}


def check_workspace(root: Path, language: str, packages: list[Package]) -> None:
    filename, section, read_members = WORKSPACES[language]
    path = root / filename
    members = read_members(path) if path.is_file() else None
    if not isinstance(members, list):
        fail(filename, f"{section} is missing, but {language} packages exist: "
             + ", ".join(p.path for p in packages))
        return
    manifest = next(m for m, lang in MANIFESTS.items() if lang == language)
    listed = set()
    for member in members:
        if not isinstance(member, str):
            continue
        if any(c in member for c in "*?["):
            fail(filename, f"{section} entry '{member}' is a glob; list every member explicitly")
            continue
        normalised = rel(root, root / member)
        listed.add(normalised)
        if not (root / normalised / manifest).is_file():
            fail(filename, f"{section} entry '{member}' does not exist or has no {manifest}")
    for pkg in packages:
        if pkg.path not in listed:
            fail(pkg.path, f"not listed in {filename} {section}")


# --- Rules -------------------------------------------------------------------

def check_dependencies(packages: list[Package]) -> None:
    for pkg in packages:
        for dep in pkg.deps:
            if dep.startswith("apps/"):
                fail(pkg.path, f"depends on app {dep}; nothing depends on an app")
            if pkg.path.startswith(("apps/", "libs/", "contracts/")) and dep.startswith(("tools/", "infra/")):
                fail(pkg.path, f"depends on {dep}; apps, libs and contracts never depend on tools/ or infra/")


def check_package_docs(root: Path, packages: list[Package]) -> None:
    for path in sorted({p.path for p in packages if p.path.startswith(("apps/", "libs/"))}):
        directory = root / path
        for doc in PACKAGE_DOCS:
            if not (directory / doc).is_file():
                fail(path, f"missing {doc}")
        agents = directory / "AGENTS.md"
        if not (agents.is_symlink() and agents.resolve() == (directory / "CLAUDE.md").resolve()):
            fail(path, "AGENTS.md must be a symlink to CLAUDE.md")


def check_language_segments(root: Path) -> None:
    for parent in ("apps", "libs", "tools"):
        for directory in sorted((root / parent).glob("*")):
            if directory.is_dir() and directory.name.lower() in LANGUAGE_NAMES:
                fail(rel(root, directory), "named after a language; language is an attribute of a package, never a path segment")


def main() -> int:
    root = repo_root()
    packages = discover(root)
    for language, resolve in RESOLVERS.items():
        members = [p for p in packages if p.language == language]
        if members:
            resolve(root, members)
            check_workspace(root, language, members)
    check_dependencies(packages)
    check_package_docs(root, packages)
    check_language_segments(root)
    for line in errors:
        print(line, file=sys.stderr)
    if errors:
        print(f"validate-structure: {len(errors)} error(s)", file=sys.stderr)
        return 1
    print("validate-structure: ok")
    return 0


if __name__ == "__main__":
    sys.exit(main())
