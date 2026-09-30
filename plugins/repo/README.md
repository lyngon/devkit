# repo

Repository setup and package creation for Lyngon.

Prerequisites: documents, workflow, baseline, structure

## Skills

- `/repo:init`: interview the owner about purpose, audiences, stack and constraints, then create or adopt the standard repository files.
  Works on empty repositories and on existing ones.
  User-invoked only.
- `/repo:add-package`: create a package in the directory its kind decides (`apps/`, `libs/`, `contracts/`, `tools/`, `infra/`), with its files, and register it in its workspace and devenv.
  Agents invoke it on their own whenever a package is needed.

## Hooks

- `SessionStart` (`hooks/session-start.sh`): in a repository whose root `CLAUDE.md` says it follows the Lyngon structure, prints `hooks/session-start-structure.txt`, which says to create every package with `/repo:add-package`; elsewhere it prints nothing.
  The lines about which devkit skills to invoke come from the `conventions` plugin's hook.

### With devenv

Claude Code captures its environment once, at start, so without help the packages and variables of `devenv.nix` are missing from the agent's Bash commands, or stale after a change.
`hooks/export-environment.sh` fixes that in every project whose root has a `devenv.nix`:

- `SessionStart`: evaluates the devenv environment and writes it to `$CLAUDE_ENV_FILE`, which Claude Code runs before every Bash command, including a subagent's.
  It exports through `direnv export bash` when direnv has allowed `.envrc`, and otherwise from `devenv direnv-export`, keeping only the variables the devenv shell adds or changes.
  It returns the files to watch: the root devenv files and every file under the project the last evaluation read, so a package's `devenv.nix` is watched too.
- `FileChanged`: when a watched file changes, evaluates again and replaces the environment.
- `CwdChanged`: evaluates again after a `cd`.
  Claude Code fires it only when a settings file also has a `CwdChanged` or `FileChanged` hook, and in that case it discards the `FileChanged` export and the watch list on every `cd`; this hook restores both.

When the evaluation fails, the hook keeps the previous environment and says so on stderr; it never fails the session.

Verified in headless sessions (`claude -p`) with Claude Code 2.1.283, devenv 2.4.0 and direnv 2.37.1, in a scratch repository that imports the baseline:

- `jq`, declared only in `devenv.nix`, resolves in the first Bash command, and a subagent sees the same environment, updates included.
- Adding a package to the root `devenv.nix`, or changing a variable in an imported package's `devenv.nix`, reaches the first Bash command after the new evaluation, about 9 s later in that repository; a cached evaluation takes under a second.
  Commands in between still see the previous environment, and a variable removed from `devenv.nix` stays set until the next session.
- A plugin's `FileChanged` matcher adds nothing to Claude Code's watch list, which only settings hooks and returned `watchPaths` fill.
  A settings matcher watches its names in the current directory only, so `devenv.nix` there misses `apps/<name>/devenv.nix` until the agent changes into that directory.
  That is why the hook returns the files to watch instead of naming them in a matcher.

## Install

```sh
claude plugin marketplace add lyngon/devkit
claude plugin install repo@lyngon --scope project
```
