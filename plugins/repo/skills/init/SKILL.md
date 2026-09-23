---
name: init
description: Set up a fresh repository, or adopt an existing one, to Lyngon conventions. Interviews the owner relentlessly about purpose, failure modes, audiences, stack and constraints, then writes INTENT.md, CLAUDE.md (with AGENTS.md symlink), README.md, CONCEPTS.md, ADRs, devenv, git hooks, CI and every package in the kind-first Lyngon layout. User-invoked only.
disable-model-invocation: true
argument-hint: "[fresh|adopt]"
---

# Initialize a repository

## Overview

One session that takes a repository from "empty" or "grown organically" to the Lyngon baseline.
The interview is the core.
The files are its output, written only after the owner confirms a shared understanding.

The scope question in the interview decides which prerequisites the repository adopts: the documents alone, the documents and the baseline, or all three including the layout defined in [STRUCTURE.md](STRUCTURE.md).
The file set below is written scope by scope; nothing from a scope the owner did not adopt is written.

## When to use

- The user asks to initialize, bootstrap, scaffold or set up a repository.
- The user asks to adopt or bring an existing repository "up to standard".

## When not to use

- Adding a single file (an ADR, a hook) to a repository that already follows the baseline. Edit it directly.
- Anything unrelated to repository structure. The skill does not write application code.

## Workflow

Work through the steps in order.
Do not write files before step 3 is confirmed.

### 1. Inventory

Facts are your job, never the user's.
Before asking anything, look up:

- `git remote -v`, `git log --oneline | head`, tracked files. No tracked files means **fresh** mode, otherwise **adopt** mode.
- Existing `README.md`, `CLAUDE.md`, `AGENTS.md` (file or symlink, which direction), `CONCEPTS.md`, `CONTEXT.md`, `docs/adr/`, `docs/TODO.md`.
- Existing `devenv.nix`, `devenv.yaml`, `.envrc`, `flake.nix`, `.gitignore`, `.pre-commit-config.yaml`, `.claude/settings.json`, `.mcp.json`, CI workflows.
- Stack markers: `pyproject.toml`, `uv.lock`, `package.json`, `pnpm-lock.yaml`, `Cargo.toml`, `go.mod`, `*.tf`, `*.cabal`, `stack.yaml`, `*.nix`, shell scripts.
- Existing package layout (`apps/`, `libs/`, a flat `packages/`, `services/`, per-language roots) and root workspace files (`pyproject.toml`, `pnpm-workspace.yaml`, `Cargo.toml`, `go.work`).
- Existing tests and how they run.

Summarize the inventory in at most ten lines, then start the interview.
Whatever the inventory settled is not asked again.

### 2. Interview

Invoke two skills from the `discover` plugin, which this plugin depends on: `discover:interview` for the rounds-and-frontier method, and `discover:domain-model` for settling terms into `CONCEPTS.md` and recording ADRs.
Then follow [references/interview.md](references/interview.md) for the question catalog, the first question ("what would make this repository a failure in a year?"), the rules specific to repository setup, and where each answer lands.

Every question carries a recommended answer.
Skipped questions take the recommendation, and you say so at the start of the next round.

Do not turn a "don't know" or "later" into a `docs/TODO.md` item on your own.
Only what the user explicitly defers goes there.

The interview ends when the frontier is empty.

### 3. Shared understanding

Present one table: every decision, its answer, and which file it lands in.
List the ADRs you intend to write with their titles.
Wait for the user to confirm.
If they change something, update the table and wait again.

### 4. Plan the file set

List every file you will create.
In adopt mode, show a diff for every file that already exists and never overwrite silently.
For `README.md` and `CLAUDE.md` in adopt mode, merge into the existing structure rather than replacing it.
If an existing `README.md` states the problem, audience or non-goals, move that content into `INTENT.md` and leave a link behind.
If `AGENTS.md` exists as the source and `CLAUDE.md` as the symlink, ask before reversing the direction.

### 5. Write

Use the templates and rules in [references/repo-files.md](references/repo-files.md) and [references/devenv.md](references/devenv.md).
The full set:

Documents scope:

- `INTENT.md` from the round 1 answers: product, for whom, done, failure, non-goals, horizon.
- `CLAUDE.md` as the source file, `AGENTS.md` as a symlink to it.
- `README.md`, `CONCEPTS.md`, `docs/adr/NNNN-slug.md` for each ADR from step 3, `docs/TODO.md` only if the user deferred something, `docs/conventions/<topic>.md` only for a repository-specific convention that needs more than a line.
- `.gitignore` with the baseline patterns, `tmp/`, `sandbox/`, and the stack patterns.
- `.claude/settings.json` registering the `lyngon` marketplace and enabling `all@lyngon`, `core@lyngon`, or the subset the user chose.
- `.github/workflows/ci.yml` (or the equivalent for the chosen host).

Baseline scope:

- `devenv.yaml`, `devenv.nix`, `.envrc`, `.vscode/extensions.json`.
- `ruff.toml` when Python is in the stack.

Structure scope:

- The sentence "This repository follows the Lyngon structure" in the root `CLAUDE.md`, and `lyngon.structure.enable = true` in `devenv.nix`; the session hook and `add-package` look for the sentence.
- The root workspace file for every language in use, with explicit members (see `add-package`'s `workspaces.md` reference), and `languages.*` in the root `devenv.nix`.
- Every package named in the interview, created through the `add-package` skill of this plugin, which puts it in the directory its kind decides, writes its files and registers it in its workspace, the root `devenv.yaml` and the root `CLAUDE.md`.
- `secretspec.toml` and the `secretspec` section in `devenv.yaml` when the repository needs secrets.
- Services (`services.*` in devenv) only when the user confirmed each one by name.

### 6. Verify

Run, and fix what fails without disabling hooks:

```sh
devenv test
```

Also confirm that `.mcp.json` was generated, that `AGENTS.md` resolves, and that `git status` shows exactly the planned files.
Report the result faithfully, including hooks that could not run.

### 7. Hand-off

Do not commit and do not stage.
Print the next steps for the owner:

1. `devenv allow` in the repository.
2. Either `direnv allow`, or `eval "$(devenv hook zsh)"` (or the equivalent for their shell) in their shell configuration.
3. Install the VS Code extension `mkhl.direnv` so the Claude Code extension sees the devenv tools.
4. Add the git remote and push, if the inventory found none.

End by offering to commit with the message `chore: initialize repository` (or `chore: adopt lyngon repository conventions` in adopt mode), and wait.
