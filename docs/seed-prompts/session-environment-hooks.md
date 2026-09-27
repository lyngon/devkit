# Repo plugin: session environment hooks

Seed prompt for a fresh Claude Code session in the devkit repository.

Add two things to the `repo` plugin's hooks: the repository's devenv environment exported into the agent session and kept current, and a warning when the branch is behind its upstream.

This is a bounded change: no design file and no plan file.
Work on a branch named `feat/session-environment-hooks`.
Do not commit until I have reviewed the files; after the review, commit by concern in Conventional Commits form.
Bump the `repo` plugin version and add a `CHANGELOG.md` entry.
Run `devenv test` before handing over and report its output faithfully.

## Facts

Verified on 2026-09-27 with devenv 2.3.1, direnv 2.37.1 and Claude Code 2.1.278.

- Claude Code captures its environment once, at start.
  In the session that wrote this file, the Bash tool carried the five `DIRENV_*` state variables but no devenv profile on `PATH`, and `jq`, declared in `devenv.nix`, was missing.
  lyngon.com sessions saw the same: stale at start, because the VS Code extension `mkhl.direnv` had not reloaded after a `devenv.nix` change, and never updated during the session when tasks added packages and `env.AWS_PROFILE` to `devenv.nix`.
  A missing tool fails loudly; a missing identity variable fails silently or picks the wrong identity.
- Because the inherited `DIRENV_*` state claims the environment is loaded, `direnv export bash` prints nothing (3 ms).
  Clearing the `DIRENV_*` variables first makes it re-export everything.
- A full re-evaluation, `_DEVENV_CALLER=direnv devenv direnv-export`, which is what direnv runs, took 3.9 s here and 45 s in lyngon.com on devenv 2.3.1, because it also ran the hook suite; devenv 2.4.0 stops that (see `docs/seed-prompts/repo-init-templates.md`).
- `direnv exec . <cmd>` is not a fast path: it re-evaluated on every call, 4.7 s here, measured three times, also with the state cleared.
- The Claude Code hooks guide, section "Reload environment when directory or files change": a `SessionStart`, `CwdChanged` or `FileChanged` hook may write shell to `$CLAUDE_ENV_FILE`; Claude Code runs that file as a preamble before each Bash command, and a rewrite is seen by the next command; the guide's own example writes `direnv export bash` output.
  `FileChanged` matches literal file names.
  Command hooks have a default timeout of 10 minutes.
  Not documented: whether subagents inherit the file, and whether a matcher on `devenv.nix` matches `apps/<name>/devenv.nix`.
- devenv's direnvrc watches the root devenv files and the previous evaluation's input list (`.devenv/input-paths.txt`), which here includes the imported `devenv/devenv.nix`, so imported package files are covered by direnv.

## 1. Environment export hook

Add to `plugins/repo/hooks/hooks.json` a `SessionStart` entry and a `FileChanged` entry (matcher `devenv.nix|devenv.yaml|devenv.lock|devenv.local.nix|devenv.local.yaml|.envrc`), both running a new script `hooks/export-environment.sh`:

- It acts only when `devenv.nix` exists at `$CLAUDE_PROJECT_DIR` and `$CLAUDE_ENV_FILE` is set.
- It unsets every `DIRENV_*` variable, then writes to `$CLAUDE_ENV_FILE` the output of `direnv export bash` when `direnv` is on `PATH` and the `.envrc` is allowed, and otherwise the output of `_DEVENV_CALLER=direnv devenv direnv-export`, which is the same bash-eval format direnv consumes.
- It prints one line on stderr saying what it did or why it skipped (no devenv, not allowed, evaluation failed) and never fails the session: a failed evaluation leaves the file untouched.
- `set -euo pipefail`, shellcheck clean, the style of the existing `session-start.sh`.

Verify by hand, in a scratch repository that imports the baseline: `jq` resolves after the hook; adding a package to `devenv.nix` is visible to the next Bash command; a dispatched subagent sees the environment; the `FileChanged` matcher fires, or does not, for a package's `devenv.nix`.
Write what you find into the plugin README, under a "With devenv" heading, since the hooks act only when devenv is present; the marking rules are in `docs/conventions/prerequisites.md`.

Documentation:

- In the CLAUDE.md template in `plugins/repo/skills/init/references/repo-files.md`: the repo plugin's hooks export the devenv environment into the agent session and refresh it when the devenv files change; no `devenv shell --` wrapper around commands.
- In `plugins/repo/skills/init/references/devenv.md`, "Activation and editors", and in this repository's `README.md`, "Developing": the sentence that `mkhl.direnv` makes the tools available to the Claude Code extension is true at start only; the hooks keep the session current.

## 2. Behind-upstream warning

In `plugins/repo/hooks/session-start.sh`: when the current branch has an upstream and `git rev-list --count HEAD..@{u}` is above zero, append one line to the context: "The current branch is N commits behind its upstream; fast-forward before starting: `git pull --ff-only`."
No fetch: the case that bit lyngon.com was already visible after the previous session's fetch.
Skip silently when there is no upstream or git fails, and keep the script's JSON escaping.

## Out of scope

- A session hold in the build ledger: deferred in `docs/TODO.md`.
- The devenv 2.4.0 version bump: `docs/seed-prompts/repo-init-templates.md`.
