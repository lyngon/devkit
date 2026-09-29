# Changelog

All notable changes to the `conventions` plugin.
Versions follow semver and are recorded in `.claude-plugin/plugin.json`.

## 0.7.0 - 2026-09-29

- `engineering` carries the user's standing instructions, replacing its "Handing over" section: commit on a feature branch without asking, one concern per commit; push and open a pull request once the full check passes; ask before a merge, a push to the default branch, a force-push, closing a pull request, deleting a remote branch, a tag, a release or a publish. The text says it counts as being asked, which overrides an agent's default of committing only on request. Work that does not belong to the current branch's open or merged pull request starts on a new branch.

## 0.6.0 - 2026-09-29

- Every skill's description ends with when to invoke it ("Invoke before ..."), instead of saying the skill loads automatically. A skill's body reaches the agent only when the agent invokes it, and `paths` does not load it, so no convention reached an agent before. `validate-marketplace` requires the wording.
- A `SessionStart` hook says which devkit skills to invoke and when, and that no skill loads on its own, the conventions included. It takes over the generic lines of the `repo` plugin's hook, so every repository that installs `core` gets them.

## 0.5.1 - 2026-09-29

- `nix` says that stock hooks such as `ruff` and `terraform-format` are enabled once in the root `devenv.nix`, and that a package's `devenv.nix` adds only its own `{name}-` hooks, since a hook's `files` holds one pattern and a stock hook scoped in two packages fails evaluation.

## 0.5.0 - 2026-09-29

- Added `shell`, loaded for `*.sh`, `*.bash` and files under a `scripts/` directory: bash with `set -euo pipefail`, output captured and then matched instead of piped into `grep -q` under `pipefail`, and commands a person runs by hand in POSIX sh or through `bash -c`. `With devenv` makes every script a hook or task runs a `writeShellApplication`; `With the Lyngon baseline` names the `shellcheck` hook and how to silence a single finding.

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
