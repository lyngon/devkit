#!/usr/bin/env python3
"""Check a repository against the layout rules in shared/STRUCTURE.md section 4.4.

Nothing depends on an app, apps, libs and contracts never depend on tools or
infra, every language workspace lists its members explicitly and completely,
every app and library carries a README.md, and no path segment under apps/,
libs/ or tools/ names a language. Runs at pre-commit with no arguments from
anywhere inside the repository. A repository without any of the package
directories (the devkit itself) passes.

A manifest is read where it enters, through Table, and a table, an array or a
string that the rules read and that has another type there fails the run,
naming the file and the key.
"""

import collections.abc as ct
import dataclasses
import json
import os
import pathlib
import re
import subprocess
import sys
import tomllib
import typing as t

MANIFESTS: t.Final = {
    "pyproject.toml": "python",
    "package.json": "typescript",
    "Cargo.toml": "rust",
    "go.mod": "go",
}
PACKAGE_ROOTS: t.Final = ["apps", "libs", "tools", "infra/modules", "infra/environments"]
LANGUAGE_NAMES: t.Final = {
    "python",
    "typescript",
    "javascript",
    "rust",
    "go",
    "golang",
    "haskell",
    "java",
    "csharp",
    "dotnet",
    "c",
    "cpp",
    "nix",
    "shell",
    "terraform",
}
PACKAGE_DOCS: t.Final = ["README.md"]

errors: list[str] = []


def fail(path: str, message: str) -> None:
    """Record an error about the path, which the run prints when it ends."""
    errors.append(f"error: {path}: {message}")


def as_table(value: object) -> dict[str, object] | None:
    """Return a TOML table or a JSON object, whose keys are strings, or None for any other value."""
    return t.cast("dict[str, object]", value) if isinstance(value, dict) else None


def as_array(value: object) -> list[object] | None:
    """Return a TOML or JSON array, or None for any other value."""
    return t.cast("list[object]", value) if isinstance(value, list) else None


@dataclasses.dataclass(frozen=True, slots=True)
class Table:
    """A table of a TOML file or an object of a JSON file, with the file and the keys it lies at.

    A value that the rules read is narrowed here, once. A table, an array or a string of another type fails the run,
    naming the file and the key, and reads as missing.
    """

    values: ct.Mapping[str, object]
    file: str
    keys: tuple[str, ...] = ()

    def where(self, key: str) -> str:
        """Return the keys that lead to a value under the key, joined as TOML joins them."""
        return ".".join((*self.keys, key))

    def get(self, key: str) -> object:
        """Return the value under the key, of whatever type, or None when it is missing."""
        return self.values.get(key)

    def table(self, key: str) -> "Table":
        """Return the table under the key, empty when it is missing or of another type."""
        found = as_table(self.values.get(key, {}))
        if found is None:
            fail(self.file, f"cannot read: {self.where(key)} is no table")
            found = {}
        return Table(found, self.file, (*self.keys, key))

    def member(self, key: str) -> "Table | None":
        """Return the value under the key as a table, or None when it is missing or of another type.

        For a value that may be a table or something else, such as a dependency that is a version or a table.
        """
        found = as_table(self.values.get(key))
        return None if found is None else Table(found, self.file, (*self.keys, key))

    def array(self, key: str) -> list[object]:
        """Return the array under the key, empty when it is missing or of another type."""
        found = as_array(self.values.get(key, []))
        if found is None:
            fail(self.file, f"cannot read: {self.where(key)} is no array")
            return []
        return found

    def string(self, key: str) -> str | None:
        """Return the string under the key, or None when it is missing or of another type."""
        value = self.values.get(key)
        if value is None or isinstance(value, str):
            return value
        fail(self.file, f"cannot read: {self.where(key)} is no string")
        return None


@dataclasses.dataclass
class Package:
    """A directory under a package root that holds the manifest of its language."""

    path: str  # relative to the repository root, forward slashes
    language: str
    name: str | None = None
    # Internal dependencies, as repository-relative paths once resolved.
    deps: list[str] = dataclasses.field(default_factory=list)


def repo_root() -> pathlib.Path:
    """Return the top of the git repository, or the working directory where git names none."""
    try:
        out = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            capture_output=True,
            text=True,
            check=True,
        ).stdout.strip()
        return pathlib.Path(out)
    except (OSError, subprocess.CalledProcessError):
        return pathlib.Path.cwd()


def rel(root: pathlib.Path, path: pathlib.Path) -> str:
    """Return the path from the root, normalised, with forward slashes."""
    return os.path.relpath(os.path.normpath(path), root).replace(os.sep, "/")


def normalise_pep503(name: str) -> str:
    """Return the name of a Python distribution as PEP 503 compares it."""
    return re.sub(r"[-_.]+", "-", name).lower()


def requirement_name(spec: str) -> str | None:
    """Return the normalised name of the distribution that a requirement names, or None when it names none."""
    match = re.match(r"\s*([A-Za-z0-9][A-Za-z0-9._-]*)", spec)
    return normalise_pep503(match.group(1)) if match else None


def read_toml(path: pathlib.Path) -> Table:
    """Read a TOML file; one that cannot be read or parsed fails the run and reads as empty."""
    try:
        return Table(tomllib.loads(path.read_text()), str(path))
    except (OSError, tomllib.TOMLDecodeError) as exc:
        fail(str(path), f"cannot parse: {exc}")
        return Table({}, str(path))


def read_json(path: pathlib.Path) -> Table:
    """Read a JSON file; one that cannot be read or parsed fails the run, and one that is no object reads as empty."""
    try:
        found = as_table(t.cast("object", json.loads(path.read_text())))
        return Table(found or {}, str(path))
    except (OSError, json.JSONDecodeError) as exc:
        fail(str(path), f"cannot parse: {exc}")
        return Table({}, str(path))


# --- Discovery ---------------------------------------------------------------


def package_dirs(root: pathlib.Path) -> list[pathlib.Path]:
    """Return every directory that may hold a package.

    These are the direct children of the package roots, and the children of each contract directory.
    """
    dirs: list[pathlib.Path] = []
    for parent in PACKAGE_ROOTS:
        dirs += [d for d in sorted((root / parent).glob("*")) if d.is_dir()]
    for contract in sorted((root / "contracts").glob("*")):
        dirs += [d for d in sorted(contract.glob("*")) if d.is_dir()]
    return dirs


def discover(root: pathlib.Path) -> list[Package]:
    """Return a package for each manifest in a directory that may hold a package."""
    packages: list[Package] = []
    for directory in package_dirs(root):
        for manifest, language in MANIFESTS.items():
            if (directory / manifest).is_file():
                packages.append(Package(rel(root, directory), language))
    return packages


# --- Dependency resolution per language --------------------------------------


def python_deps(root: pathlib.Path, packages: list[Package]) -> None:
    """Set the name and the internal dependencies of each Python package.

    A dependency is a requirement of the project, of an extra or of a dependency group, or a uv source from the
    workspace, that names another package.
    """
    by_name: dict[str, str] = {}
    required: dict[str, set[str]] = {}
    for pkg in packages:
        manifest = read_toml(root / pkg.path / "pyproject.toml")
        project = manifest.table("project")
        name = project.string("name")
        if name:
            pkg.name = normalise_pep503(name)
            by_name[pkg.name] = pkg.path
        specs = list(project.array("dependencies"))
        extras = project.table("optional-dependencies")
        for extra in extras.values:
            specs += extras.array(extra)
        groups = manifest.table("dependency-groups")
        for group in groups.values:
            specs += groups.array(group)
        names = {found for s in specs if isinstance(s, str) and (found := requirement_name(s)) is not None}
        sources = manifest.table("tool").table("uv").table("sources")
        for source_name in sources.values:
            source = sources.member(source_name)
            if source is not None and source.get("workspace"):
                names.add(normalise_pep503(source_name))
        required[pkg.path] = names
    for pkg in packages:
        pkg.deps = sorted(by_name[n] for n in required[pkg.path] if n in by_name)


def typescript_deps(root: pathlib.Path, packages: list[Package]) -> None:
    """Set the name and the internal dependencies of each TypeScript package.

    A dependency is one that names another package or asks for a workspace version.
    """
    manifests = {p.path: read_json(root / p.path / "package.json") for p in packages}
    for pkg in packages:
        pkg.name = manifests[pkg.path].string("name")
    by_name = {p.name: p.path for p in packages if p.name}
    for pkg in packages:
        deps: set[str] = set()
        for section in ("dependencies", "devDependencies", "peerDependencies"):
            for name, version in manifests[pkg.path].table(section).values.items():
                if str(version).startswith("workspace:") or name in by_name:
                    deps.add(by_name.get(name, name))
        pkg.deps = sorted(deps)


def workspace_dependencies(root: pathlib.Path) -> Table:
    """Return the table [workspace.dependencies] of the root Cargo.toml, empty without one."""
    if (root / "Cargo.toml").is_file():
        return read_toml(root / "Cargo.toml").table("workspace").table("dependencies")
    return Table({}, "Cargo.toml")


def rust_deps(root: pathlib.Path, packages: list[Package]) -> None:
    """Set the name and the internal dependencies of each Rust crate.

    A dependency is one with a path, its own or the workspace's, or one that names another crate.
    """
    workspace = workspace_dependencies(root)
    manifests = {p.path: read_toml(root / p.path / "Cargo.toml") for p in packages}
    for pkg in packages:
        pkg.name = manifests[pkg.path].table("package").string("name")
    by_name = {p.name: p.path for p in packages if p.name}
    for pkg in packages:
        deps: set[str] = set()
        for section in ("dependencies", "dev-dependencies", "build-dependencies"):
            declared = manifests[pkg.path].table(section)
            for name in declared.values:
                # A table, or None for a version alone. One that defers to the workspace is read from there, and
                # its path is then from the root.
                spec, base = declared.member(name), root / pkg.path
                if spec is not None and spec.get("workspace"):
                    spec, base = workspace.member(name), root
                if spec is not None and "path" in spec.values:
                    if (path := spec.string("path")) is not None:
                        deps.add(rel(root, base / path))
                    continue
                package = name if spec is None or "package" not in spec.values else spec.string("package")
                if package is not None and package in by_name:
                    deps.add(by_name[package])
                elif name in by_name:
                    deps.add(by_name[name])
        pkg.deps = sorted(deps)


def go_directives(text: str, keyword: str) -> list[str]:
    """Return the arguments of every `keyword x` line and `keyword ( ... )` block."""
    text = re.sub(r"//[^\n]*", "", text)
    found = [match.group(1) for match in re.finditer(rf"^{keyword}\s+([^(\n][^\n]*)$", text, re.MULTILINE)]
    for block in re.finditer(rf"^{keyword}\s*\(\s*\n(.*?)^\)", text, re.MULTILINE | re.DOTALL):
        found += [line.strip() for line in block.group(1).splitlines() if line.strip()]
    return found


def go_deps(root: pathlib.Path, packages: list[Package]) -> None:
    """Set the module and the internal dependencies of each Go module.

    A dependency is a required module that is another package, or a replacement by a relative path.
    """
    texts: dict[str, str] = {}
    for pkg in packages:
        texts[pkg.path] = text = (root / pkg.path / "go.mod").read_text()
        match = re.search(r"^module\s+(\S+)", text, re.MULTILINE)
        pkg.name = match.group(1) if match else None
    by_name = {p.name: p.path for p in packages if p.name}
    for pkg in packages:
        deps: set[str] = set()
        for line in go_directives(texts[pkg.path], "require"):
            module = line.split()[0]
            if module in by_name:
                deps.add(by_name[module])
        for line in go_directives(texts[pkg.path], "replace"):
            target = line.split("=>")[-1].split()[0] if "=>" in line else ""
            if target.startswith(("./", "../")):
                deps.add(rel(root, root / pkg.path / target))
        pkg.deps = sorted(deps)


RESOLVERS: t.Final[dict[str, ct.Callable[[pathlib.Path, list[Package]], None]]] = {
    "python": python_deps,
    "typescript": typescript_deps,
    "rust": rust_deps,
    "go": go_deps,
}


# --- Workspaces --------------------------------------------------------------


def pnpm_members(path: pathlib.Path) -> list[str] | None:
    """Return the top-level `packages:` list of pnpm-workspace.yaml.

    Read without a YAML library: a block list of quoted or unquoted strings is all pnpm needs.
    """
    members: list[str] | None = None
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


def uv_members(path: pathlib.Path) -> object:
    """Return the members of the uv workspace in a pyproject.toml, of whatever type, or None."""
    return read_toml(path).table("tool").table("uv").table("workspace").get("members")


def cargo_members(path: pathlib.Path) -> object:
    """Return the members of the workspace in a Cargo.toml, of whatever type, or None."""
    return read_toml(path).table("workspace").get("members")


def go_work_members(path: pathlib.Path) -> object:
    """Return the modules that a go.work uses."""
    return go_directives(path.read_text(), "use")


WORKSPACES: t.Final[dict[str, tuple[str, str, ct.Callable[[pathlib.Path], object]]]] = {
    "python": ("pyproject.toml", "[tool.uv.workspace] members", uv_members),
    "typescript": ("pnpm-workspace.yaml", "packages", pnpm_members),
    "rust": ("Cargo.toml", "[workspace] members", cargo_members),
    "go": ("go.work", "use", go_work_members),
}


def check_workspace(root: pathlib.Path, language: str, packages: list[Package]) -> None:
    """Check that the workspace of the language lists every one of its packages, and only those, by path."""
    filename, section, read_members = WORKSPACES[language]
    path = root / filename
    members = as_array(read_members(path)) if path.is_file() else None
    if members is None:
        fail(filename, f"{section} is missing, but {language} packages exist: " + ", ".join(p.path for p in packages))
        return
    manifest = next(m for m, lang in MANIFESTS.items() if lang == language)
    listed: set[str] = set()
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
    """Check that nothing depends on an app, and that apps, libs and contracts never depend on tools or infra."""
    for pkg in packages:
        for dep in pkg.deps:
            if dep.startswith("apps/"):
                fail(pkg.path, f"depends on app {dep}; nothing depends on an app")
            if pkg.path.startswith(("apps/", "libs/", "contracts/")) and dep.startswith(("tools/", "infra/")):
                fail(pkg.path, f"depends on {dep}; apps, libs and contracts never depend on tools/ or infra/")


def check_package_docs(root: pathlib.Path, packages: list[Package]) -> None:
    """Check that every app and library carries its documents."""
    for path in sorted({p.path for p in packages if p.path.startswith(("apps/", "libs/"))}):
        directory = root / path
        for doc in PACKAGE_DOCS:
            if not (directory / doc).is_file():
                fail(path, f"missing {doc}")


def check_language_segments(root: pathlib.Path) -> None:
    """Check that no directory directly under apps/, libs/ or tools/ is named after a language."""
    for parent in ("apps", "libs", "tools"):
        for directory in sorted((root / parent).glob("*")):
            if directory.is_dir() and directory.name.lower() in LANGUAGE_NAMES:
                fail(
                    rel(root, directory),
                    "named after a language; language is an attribute of a package, never a path segment",
                )


def main() -> int:
    """Check the repository and return the exit status: 0 when every rule holds, 1 otherwise."""
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
