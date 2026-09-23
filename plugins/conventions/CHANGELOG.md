# Changelog

All notable changes to the `conventions` plugin.
Versions follow semver and are recorded in `.claude-plugin/plugin.json`.

## 0.4.1 - 2026-09-23

- Ships `LICENSE-mattpocock`, the MIT license of the `ADR-FORMAT.md` and `CONCEPTS-FORMAT.md` documents adapted from mattpocock/skills, and both documents point to it.

## 0.4.0 - 2026-09-23

- The `python` skill names the type checker under `With the Lyngon baseline`: basedpyright in `all` mode through the `{name}-basedpyright` hook, and `# pyright: ignore[rule]  # reason` for a single finding.

## 0.3.0 - 2026-09-23

- The `typescript` skill names the compiler flags beyond `strict: true`, and adds rules for Node builtins (`node:` prefix, namespace import), erasable syntax only (no `enum`, `namespace` or parameter properties), indexed access, boolean conditions and exhaustive `switch`. Tool configuration files are the one allowed default export.
- `With the Lyngon baseline` names the `{name}-tsc` and `{name}-eslint` hooks, the root `tsconfig.base.json` and `eslint.config.js`, and how to silence a single finding.

## 0.2.0 - 2026-09-23

- The `python` skill has an `Imports` section: import modules, never names; `from a.b import c` only when `c` is a module; absolute imports only; the fixed aliases `typing as t`, `collections.abc as ct` and `datetime as dt`, plus the conventional third-party aliases (`numpy as np`).
- Docstrings state a contract or a reason, never the name restated as a sentence.
- `With the Lyngon baseline` names the root `ruff.toml` as the only ruff configuration and says how to silence a single finding.
- The `python-domain-value` eval checks module imports (`imports-modules`) and expects `@dataclasses.dataclass(frozen=True, slots=True)`.

## 0.1.1 - 2026-09-23

- The `nix` skill no longer assumes devenv or the Lyngon baseline on every Nix file: universal Nix rules first, then `With devenv`, `With the Lyngon baseline` and `With the Lyngon structure` sections. Every "checked by" line moved under `With the Lyngon baseline`, since the hooks come from it.

## 0.1.0 - 2026-09-20

- Added `engineering`, `python`, `typescript`, `nix`, `markdown`, `documents` and `adr`: background skills that load by file path (`paths` frontmatter, `user-invocable: false`) and state the conventions the hooks cannot check.
- Declares the `documents` prerequisite; everything about devenv or the Lyngon structure sits under conditional headings.
- Added the first eval case, `python-domain-value`. `claude plugin eval` is in early access and could not be run here; evals are not wired into CI (token cost).
