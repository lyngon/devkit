---
name: init
description: Set up a fresh repository, or adopt an existing one, to Lyngon conventions. Interviews the owner relentlessly about purpose, failure modes, audiences, stack and constraints, then writes INTENT.md, .claude/CLAUDE.md, README.md, CONCEPTS.md, decision records, devenv, git hooks, CI and every package in the kind-first Lyngon layout. User-invoked only.
disable-model-invocation: true
argument-hint: "[fresh|adopt]"
---

# Initialize a repository

## Overview

One session that takes a repository from "empty" or "grown organically" to the Lyngon baseline.
The interview is the core.
The files are its output, written only after the owner confirms a shared understanding.

The scope question in the interview decides which prerequisites the repository adopts: the documents alone, the documents and the baseline, or the documents, the baseline and the layout defined in [STRUCTURE.md](STRUCTURE.md).
The file set below is written scope by scope; nothing from a scope the owner did not adopt is written.
Every scope adopts the Lyngon workflow: the settings enable `conventions`, whose standing instructions commit, push and open pull requests without asking.

## When to use

- The user asks to initialize, bootstrap, scaffold or set up a repository.
- The user asks to adopt or bring an existing repository "up to standard".

## When not to use

- Adding a single file (a decision record, a hook) to a repository that already follows the baseline. Edit it directly.
- Anything unrelated to repository structure. The skill does not write application code.

## Workflow

Work through the steps in order.
Do not write files before step 3 is confirmed.

### 1. Inventory

Facts are your job, never the user's.
Before asking anything, look up:

- `git remote -v`, `git log --oneline | head`, tracked files. No tracked files means **fresh** mode, otherwise **adopt** mode.
- Existing `README.md`, `INTENT.md`, `CONCEPTS.md`, `CONTEXT.md`, `docs/decisions/`, `docs/TODO.md`, and what an older setup left: `CLAUDE.md`, `AGENTS.md`, `docs/adr/`.
- Existing `devenv.nix`, `devenv.yaml`, `.envrc`, `flake.nix`, `.gitignore`, `.pre-commit-config.yaml`, `.claude/settings.json`, `.mcp.json`, CI workflows.
- Stack markers: `pyproject.toml`, `uv.lock`, `package.json`, `pnpm-lock.yaml`, `Cargo.toml`, `go.mod`, `*.tf`, `*.cabal`, `stack.yaml`, `*.nix`, shell scripts.
- Existing package layout (`apps/`, `libs/`, a flat `packages/`, `services/`, per-language roots) and root workspace files (`pyproject.toml`, `pnpm-workspace.yaml`, `Cargo.toml`, `go.work`).
- Existing tests and how they run.

Summarize the inventory in at most ten lines, then start the interview.
Whatever the inventory settled is not asked again.

### 2. Interview

Invoke two skills from the `discover` plugin, which this plugin depends on: `discover:interview` for the rounds-and-frontier method, and `discover:domain-model` for settling terms into `CONCEPTS.md` and recording decisions.
Then follow [references/interview.md](references/interview.md) for the question catalog, the first question ("what would make this repository a failure in a year?"), the rules specific to repository setup, and where each answer lands.

Every question carries a recommended answer.
Skipped questions take the recommendation, and you say so at the start of the next round.

Do not turn a "don't know" or "later" into a `docs/TODO.md` item on your own.
Only what the user explicitly defers goes there.

The interview ends when the frontier is empty.

### 3. Shared understanding

Present one table: every decision, its answer, and which file it lands in.
List the decision records and the rule files you intend to write, by name.
Wait for the user to confirm.
If they change something, update the table and wait again.

### 4. Plan the file set

List every file you will create.
In adopt mode, show a diff for every file that already exists and never overwrite silently.
For `README.md` in adopt mode, merge into the existing structure rather than replacing it.
If an existing `README.md` states the problem, audience or non-goals, move that content into `INTENT.md` and leave a link behind.

An existing `CLAUDE.md`, `AGENTS.md` or `docs/adr/` is sorted and then deleted, never kept.
Sort each line and each record by the admission test in `discover:domain-model`: drop what a check carries, what the tree shows and what holds for every Lyngon repository; a principle that passes becomes a rule file under `.claude/rules/`, and a decision that passes becomes a record under `docs/decisions/`, named after the decision.
Show the owner the sorting before deleting anything.

### 5. Write

In adopt mode, when the repository is on its default branch, create the branch first: `git switch -c chore/adopt-lyngon-conventions`.

Use the templates and rules in [references/repo-files.md](references/repo-files.md) and [references/devenv.md](references/devenv.md).
The full set:

Documents scope:

- `INTENT.md` from the round 1 answers: product, for whom, done, failure, non-goals, horizon.
- `.claude/CLAUDE.md` holding the one line that imports `INTENT.md`.
- `.claude/rules/<name>.md` for each repository principle from step 3, one per file. Most repositories start with none.
- `README.md`, `CONCEPTS.md`, `docs/decisions/<name>.md` for each decision record from step 3, `docs/TODO.md` only if the user deferred something, `docs/conventions/<topic>.md` only for a repository-specific convention too long for a rule file.
- `.gitignore` with the baseline patterns, `/tmp/`, `/sandbox/`, and the stack patterns.
- `.claude/settings.json` hiding the agent's commit attribution, registering the `lyngon` marketplace and enabling each plugin by name: `all@lyngon` and its members, or `core@lyngon` and its members, or the subset the user chose with its dependencies, the last two together with `conventions@lyngon`. The README installs the bundle, or the chosen plugins, with `conventions`.
- `.github/workflows/ci.yml` (or the equivalent for the chosen host).

Baseline scope:

- `devenv.yaml`, `devenv.nix`, `.envrc`, `.vscode/extensions.json`.
- `ruff.toml` and `[tool.basedpyright]` in the root `pyproject.toml` when Python is in the stack.
- `tsconfig.base.json`, `eslint.config.js`, and their dev dependencies in the root `package.json`, when TypeScript is in the stack.

Structure scope:

- `lyngon.structure.enable = true;` on a line of its own in the root `devenv.nix`; the session hook and `add-package` look for that line.
- The root workspace file for every language in use, with explicit members (see `add-package`'s `workspaces.md` reference), and `languages.*` in the root `devenv.nix`.
- Every package named in the interview, created through the `add-package` skill of this plugin, which puts it in the directory its kind decides, writes its files and registers it in its workspace and the root `devenv.yaml`.
- `secretspec.toml` and the `secretspec` section in `devenv.yaml` when the repository needs secrets.
- Services (`services.*` in devenv) only when the user confirmed each one by name.

### 6. Verify

Run, and fix what fails without disabling hooks:

```sh
devenv test
```

Also confirm that `.mcp.json` was generated and that `git status` shows exactly the planned files.
Report the result faithfully, including hooks that could not run.

### 7. Commit and hand off

`add-package` does not commit when this skill invokes it; the commits below include its packages.

In fresh mode the repository has no commits, so there is no base for a pull request: everything lands in one root commit on `main`.

```sh
git symbolic-ref HEAD refs/heads/main
git add -A
git commit -m "chore: initialize repository"
```

The first command names the unborn branch `main` when git's default named it otherwise.
Ask before pushing: the commit is on the default branch.

In adopt mode the work is on the branch step 5 created, or on the feature branch init started on.
Commit by concern, in an order in which each commit passes the hooks, and put two concerns in one commit when neither passes alone:

1. `docs: adopt the Lyngon documents`: `INTENT.md`, `.claude/CLAUDE.md`, the rule files, `README.md`, `CONCEPTS.md`, the decision records, `docs/`, `.gitignore` and `.claude/settings.json`, together with the removal of an old `CLAUDE.md`, `AGENTS.md` and `docs/adr/`.
2. `build: import the Lyngon baseline`: the devenv files and the linter configurations.
3. `ci: run the full check in CI`.
4. `build: adopt the Lyngon structure`: the root workspace files and `secretspec.toml`; then one `feat(<name>): add <kind> <name>` per package.

Then finish the branch with `/build:finish` when the build plugin is installed; otherwise push it and open a pull request.

Print the next steps for the owner:

1. `devenv allow` in the repository.
2. Either `direnv allow`, or `eval "$(devenv hook zsh)"` (or the equivalent for their shell) in their shell configuration.
3. Install the VS Code extension `mkhl.direnv` so the Claude Code extension sees the devenv tools.
4. In fresh mode without a remote: add one and push `main`.
