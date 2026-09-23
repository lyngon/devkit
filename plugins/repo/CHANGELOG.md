# Changelog

All notable changes to the `repo` plugin.
Versions follow semver and are recorded in `.claude-plugin/plugin.json`.

## 0.4.0 - 2026-09-23

- `init` writes a root `tsconfig.base.json` and `eslint.config.js` when TypeScript is in the stack: strict compiler flags beyond `strict: true`, typescript-eslint `strictTypeChecked` and `stylisticTypeChecked`, and rules for exhaustive `switch`, boolean conditions, named exports and Node builtin imports. `typescript` is pinned to `~6.0.3` until typescript-eslint supports TypeScript 7.
- A TypeScript package gets `{name}-tsc` and `{name}-eslint` hooks running the workspace's own tools, and a `tsconfig.json` that extends the base; the commented-out `eslint` line is gone.

## 0.3.0 - 2026-09-23

- `init` writes a root `ruff.toml` when Python is in the stack: every stable rule, a short ignore list with a reason on each entry, the `t`, `ct` and `dt` import aliases, `typing`, `collections.abc` and `datetime` banned from `from` imports, and no relative imports. In adopt mode an existing ruff configuration moves into it.
- `add-package` never gives a Python package its own `[tool.ruff]` table, which would replace the root configuration for that package.

## 0.2.1 - 2026-09-23

- The second prerequisite is called `baseline` (devenv with `lyngon/devenv` imported); the scope question and the file sets use that name.

## 0.2.0 - 2026-09-20

- Added the `add-package` skill: creates an app, library, adapter, contract, tool, infra module or environment in the directory its kind decides, with `INTENT.md`, `README.md`, `CLAUDE.md`, `devenv.nix` and the layer lint for a core library, and registers it in its workspace and the root `devenv.yaml`. Agents may invoke it on their own.
- Added a `SessionStart` hook that tells the agent which devkit skills to invoke and when; it mentions `add-package` only when the root `CLAUDE.md` says the repository follows the Lyngon structure.
- `init` asks which prerequisites the repository adopts (documents, devenv, structure) and writes only those file sets; a structured repository gets the `CLAUDE.md` sentence and `lyngon.structure.enable = true`. `add-package` refuses in a repository without the sentence.
- `init` creates packages through `add-package` and writes the kind-first layout from `shared/STRUCTURE.md` (`apps/`, `libs/`, `contracts/`, `tools/`, `infra/`) instead of a flat `packages/`.
- Languages and workspaces are enabled once at the repository root; a package's `devenv.nix` holds only its tasks, hooks and processes.

## 0.1.2 - 2026-09-16

- The interview recommends the `all` bundle, the settings template enables `all@lyngon`, and the README template tells colleagues to install it once; Claude Code 2.1.195 and later no longer installs plugins from a committed settings file.

## 0.1.1 - 2026-09-16

- The `CLAUDE.md` template names the `prose-lint` hook next to the other enforced conventions.

## 0.1.0 - 2026-09-15

- Added the `init` skill: interview, INTENT.md, CLAUDE.md, README.md, CONCEPTS.md, ADRs, devenv, git hooks and CI for a fresh or existing repository.
