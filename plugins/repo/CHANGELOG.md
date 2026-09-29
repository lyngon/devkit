# Changelog

All notable changes to the `repo` plugin.
Versions follow semver and are recorded in `.claude-plugin/plugin.json`.

## 0.9.0 - 2026-09-29

- The plugin declares the `workflow` prerequisite, and `init` adopts the Lyngon workflow in every scope: the settings it writes enable `conventions` next to `core` or a subset, the interview says so, and the README template installs `core` with `conventions` when the settings do (ADR 0017).

## 0.8.2 - 2026-09-29

- `init` step 7 says before both modes that `add-package` leaves its commit to `init`; the sentence sat after the adopt-mode list, though fresh mode relies on it too.

## 0.8.1 - 2026-09-29

- The `SessionStart` hook prints its text instead of building JSON by hand, so no character in the text can break the output.

## 0.8.0 - 2026-09-29

- `init` commits its work: one root commit on `main` in fresh mode, asking before the push, and in adopt mode commits by concern on `chore/adopt-lyngon-conventions`, then a pull request. `add-package` commits its package on the feature branch and never pushes; under `init` it leaves the commit to `init`. The README template installs the plugins with `--scope project`.

## 0.7.0 - 2026-09-29

- The `SessionStart` hook prints only the structure line, and only in a repository that follows the Lyngon structure. The generic lines moved to the `conventions` plugin's hook, which reaches every repository that installs `core`; the line saying that conventions load on their own was wrong and is gone.

## 0.6.3 - 2026-09-29

- The `devenv.yaml` template requires devenv 2.4.0. From 2.4.0 on, `devenv shell` and every direnv re-evaluation no longer run the hook suite first, which on 2.3.1 cost agents up to 45 s per wrapped command. The saving needs the `devenv` input in `devenv.lock` at 2.4 as well, which `require_version` does not check; `devenv.md` says to run `devenv update devenv` in adopt mode.

## 0.6.2 - 2026-09-29

- `STRUCTURE.md`, symlinked into `init` and `add-package`, reserves "domain" for the domain layer and the domain model of a Context; for DNS it says "domain name", "zone" or "hostname". Infrastructure repositories use "domain" for DNS names, which collided with the structure's own sense of the word.

## 0.6.1 - 2026-09-29

- The `CLAUDE.md` template says what `devenv test` actually prints: task names and times, and hook output only when a hook fails. It previously promised `DEVENV_NO_AI_AGENT=1` would show per-hook output, which a passing run never does; per-hook results come from `prek run --all-files` in the devenv shell.

## 0.6.0 - 2026-09-29

- The Terraform stack is now OpenTofu: `languages.opentofu`, `terraform-format` (which runs `tofu fmt`), tflint from nixpkgs with the AWS ruleset and a root `.tflint.hcl`, and a `{name}-tflint` hook for every root and HCL module. The stock `tflint` hook in git-hooks.nix passes file names, which tflint has rejected since 0.47 ("Command line arguments support was dropped in v0.47"); reproduced against the pinned nixpkgs. `add-package` shows an infrastructure environment's `devenv.nix`.

## 0.5.5 - 2026-09-29

- Stock hooks (`ruff-format`, `ruff`, `terraform-format`) are enabled once in the root `devenv.nix`, and a package's `devenv.nix` adds only its own `{name}-` hooks. The package template scoped `ruff-format` and `ruff` per package, which fails evaluation as soon as a second Python package exists.

## 0.5.4 - 2026-09-29

- The `.gitignore` baseline anchors `/tmp/` and `/sandbox/` to the repository root; unanchored, `sandbox/` also ignored `infra/environments/sandbox/`.

## 0.5.3 - 2026-09-29

- `init` enables every plugin by name in `.claude/settings.json`: `all@lyngon` and each of its members, or the chosen bundle or subset with its dependencies. With the bundle alone, Claude Code 2.1.278 did not load `build`, because it does not count a member installed with the bundle as enabled when it checks another member's dependencies. The README still installs with the one bundle command.

## 0.5.2 - 2026-09-23

- `init` no longer writes a private marketplace credentials note into the README; the marketplace installs without credentials.

## 0.5.1 - 2026-09-23

- The `SessionStart` hook names `brainstorm`, the `build` skills, the `practice` skills and `review:receive`, and says that process skills come before implementation. It points at `WORKFLOW.md` for the flow between them.

## 0.5.0 - 2026-09-23

- `init` configures basedpyright in `all` mode in the root `pyproject.toml` and adds it from nixpkgs to the root `devenv.nix`; the PyPI wheel's bundled Node runs on NixOS only with nix-ld. Each Python package gets a `{name}-basedpyright` hook. In adopt mode, remaining errors go into a committed baseline instead of disabled rules.

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
