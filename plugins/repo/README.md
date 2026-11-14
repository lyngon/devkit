# repo

Repository setup and package creation for Lyngon.

## Skills

- `/repo:init`: interview the owner about purpose, audiences, stack and constraints, then create or adopt the steering documents and the other standard repository files.
  Works on empty repositories and on existing ones.
  User-invoked only.
- `/repo:add-package`: create a package in the directory its kind decides (`apps/`, `libs/`, `contracts/`, `tools/`, `infra/`), with its files, and register it in its workspace and devenv.
  Agents invoke it on their own whenever a package is needed.

## Hooks

- `SessionStart` (`hooks/session-start.sh`): in a repository whose root `devenv.nix` sets `lyngon.structure.enable = true`, prints `hooks/session-start-structure.txt`, which says to create every package with `/repo:add-package`, that an app holds main, wiring and config and no logic, and that a file under `generated/` or `vendor/` is never edited by hand.
  It then fetches `origin` with pruning, for at most 10 s, and adds a line for each of these cases:

  - The fetch failed or got no answer in time. The line gives git's reason, and the lines after it count what the last fetch saw.
  - The current branch is behind its upstream. The line gives the count and `git pull --ff-only`.
  - The upstream of the current branch no longer exists, as after GitHub merges its pull request and deletes the branch.
  - The local default branch is behind the default branch of `origin`, and another branch is current. The line says to start every new branch from the default branch of `origin`.

  Otherwise it prints nothing.
  Its timeout in `hooks/hooks.json` is 20 s, so a remote that never answers still leaves the hook time to say so.
  The lines about which devkit skills to invoke come from the `conventions` plugin's hook.

### The devenv environment in a session

Claude Code captures its environment once, at start, so without help the packages and variables of `devenv.nix` are missing from the agent's Bash commands, or stale after a change.
`hooks/export-environment.sh` gives each Bash command, a subagent's included, the devenv environment of the working tree the command starts in.
That tree is the nearest directory at or above the command's directory that holds both `.git` and `devenv.nix`.
So a linked worktree is a tree of its own, and a repository without a `devenv.nix` inside a tree belongs to that tree.

- `SessionStart`: writes lines to `$CLAUDE_ENV_FILE`, which Claude Code runs before every Bash command.
  The lines find the command's tree and source the environment that this session keeps for it, under `$CLAUDE_PLUGIN_DATA/sessions/`.
  The hook then evaluates the tree the session starts in.
  It exports through `direnv export bash` when direnv has allowed `.envrc`, and otherwise from `devenv direnv-export`, keeping only the variables the devenv shell adds or changes.
  When the environment names the baseline's `agent-identity` command, it also appends the lines that make the session's agents act on GitHub as a GitHub App, and passes the command's message to the session as context; the devkit's `devenv/agent-identity.md` explains the rest.
  A startup or a resume drops the environments of the session's earlier process, because each one builds on the environment of the process that evaluated it.
  A compaction or `/clear` keeps them.
  It also deletes the environments of every session whose last start is more than a week old.
- `PreToolUse` on `Bash` and `Monitor`: evaluates the call's tree when this session has no environment for it yet, or when a watched file changed, appeared or went away since the last evaluation.
  The watched files are the root devenv files and every file under the tree that the last evaluation read, so a package's `devenv.nix` is watched too.
  The command waits for the evaluation and runs with its result.

When an evaluation fails, commands in the tree keep its previous environment, or run without one when it had none, until a watched file changes.
The hook says so on stderr and, before a command, in the session's context; it never fails the session or the command.

The hook evaluates before each command, and not on `CwdChanged` or `FileChanged`, because Claude Code fires no `CwdChanged`, `FileChanged` or `SessionStart` hook when a session moves between trees.
`CLAUDE_PROJECT_DIR` stays at the tree the session started in, while a `PreToolUse` hook runs in the directory of the call.

Verified on 2026-11-14 in headless sessions (`claude -p`) in a scratch repository with a minimal `devenv.nix`, with devenv 2.4.0, on Claude Code 2.1.321 (the Nix package) and 2.1.323 (the binary of the VS Code extension):

- `printenv DEVENV_ROOT` printed the tree it ran in after `EnterWorktree`, after `ExitWorktree`, in a `--worktree` session, in a resumed session that moved back into its worktree, in a `Monitor` command and in a subagent's command in a worktree.
- In 22 such sessions, with 132 hook events, no `CwdChanged` or `FileChanged` hook fired, and the `SessionStart` hook of every resumed worktree session ran in the launch tree.
- When a worktree's `devenv.nix` broke between two turns, the next command there ran without the devenv environment, and the model quoted the hook's message word for word.
- The hook took 21 to 28 ms before a command when nothing had changed, 172 to 242 ms to evaluate a tree devenv had evaluated before, and 4.5 to 5.0 s for the first evaluation of a new worktree.

## Install

Part of the `all` bundle, which a Lyngon repository installs whole:

```sh
claude plugin marketplace add lyngon/devkit
claude plugin install all@lyngon --scope project
```
