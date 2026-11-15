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
  When no ignore rule covers `.claude/worktrees/`, where Claude Code creates a session's worktrees, it adds `/.claude/worktrees/` to `info/exclude` in the clone's common git directory, which every worktree of the clone reads and git does not track.
  A repository set up before `/repo:init` wrote that line into `.gitignore` has no such rule.
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
- In 36 such sessions, with 214 hook events, no `CwdChanged` or `FileChanged` hook fired, and the `SessionStart` hook of every resumed worktree session ran in the launch tree.
- When a worktree's `devenv.nix` broke between two turns, the next command there ran without the devenv environment, and the model quoted the hook's message word for word.
- The hook took 16 to 32 ms before a command when nothing had changed, 172 to 303 ms to evaluate a tree devenv had evaluated before, and 4.5 to 6.3 s for the first evaluation of a new worktree, the slowest while a `devenv test` ran beside it.

### One live session per working tree

Two live sessions in one working tree change its `HEAD`, its index and its files under each other.
`hooks/one-session-per-tree.py` refuses a session's `Edit`, `Write`, `NotebookEdit`, `Bash` and `Monitor` calls in a working tree where a live session that started earlier works, busy or idle.
The refusal lifts once the later session has moved to a worktree of its own, or once the earlier one has ended, crashed or been killed.
Every other tool still runs, `Read`, `EnterWorktree` and `ExitWorktree` among them, and the earlier session, like a session alone in its tree, is never refused.
The decision and the options it rejected are in `docs/decisions/a-session-moves-to-its-own-worktree-when-another-works-in-its-tree.md` of the devkit.

- A working tree is the nearest directory at or above a directory that holds `.git`, so a linked worktree is a tree of its own.
  The call's tree is the one that holds the hook's working directory, and another session's tree is the one that holds the working directory of its process, `/proc/<pid>/cwd`.
- Claude Code keeps one file for each live session in `${CLAUDE_CONFIG_DIR:-~/.claude}/sessions/<pid>.json`, in a format it does not document.
  A file counts while its `pid` runs with the start time that its `procStart` records, field 22 of `/proc/<pid>/stat`.
  So the file that a crashed or killed session leaves behind stops counting, and so does one whose pid a new process took.
- The hook's own session is the nearest process above it with a file that counts.
  Claude Code starts a hook as a child of the session's process.
- Of two sessions, the earlier is the one with the smaller `procStart`, then the smaller pid.
  A resumed session runs in a new process, so it is the later one.
- The refusal names each earlier session in the tree, with its name, whether it runs in the CLI, headless or in VS Code, and whether it is busy or how long it has been idle.
  It names the tree and what is checked out there, and says that the operator's standing instructions ask for the move, since the description of `EnterWorktree` tells the model to use it only when someone asked for a worktree.
  When the task continues the work on that branch, the session asks the operator to close the other session.
  Otherwise it calls `EnterWorktree` without a name, so that Claude Code generates one, since a name in use enters that worktree and a session refused the shell cannot list the names in use.
  When `EnterWorktree` answers that the session is in a worktree session already, as it does after `--worktree` and after a resume into a worktree, the session first calls `ExitWorktree` with action `keep`, which leaves the worktree, and the other session's lock on it, in place.
- At `SessionStart`, when the registry holds no file for this session, the hook says so in one line that names the registry's directory.
  The check then lets every call run, as `docs/decisions/the-session-check-fails-open-when-the-registry-is-unreadable.md` of the devkit decides.

Like every Python hook, the check runs only in a session whose process has `python3` on its PATH, as a session started from the devenv shell has, because Claude Code gives a hook the environment of the session's process and nothing that `CLAUDE_ENV_FILE` adds (issue 156).

Verified on 2026-11-15 on Claude Code 2.1.321 (the Nix package) and 2.1.323 (the binary of the VS Code extension), in headless sessions on haiku in scratch repositories, with `--permission-mode default`, only `EnterWorktree`, `ExitWorktree` and `Bash(sleep:*)` allowed, and prompts that name no worktree:

- With an earlier session idle in the main checkout, the later session's first `Bash` call there was refused, the session called `EnterWorktree`, and its next `Bash` call ran in the new worktree, in 15 of 15 runs over the drafts of the refusal, 4 of them with the final text.
  After a `kill -9` of the earlier session, a third session's `Bash` call in the main checkout ran.
- With two sessions in one `--worktree` worktree, which the second opened by the same name, `EnterWorktree` refused the later session as already in a worktree session.
  It called `ExitWorktree` with `keep`, then `EnterWorktree`, and its `Bash` call ran in the new worktree, in 4 of 4 runs with the final text.
  The shared worktree kept the earlier session's lock.
- Without the paragraph of the standing instructions, the later session in the shared worktree moved in 0 of 2 runs, and said that the refusal's claim did not match its `CLAUDE.md`.
  With a paragraph that named only `EnterWorktree`, it stopped in 1 of 2 runs, because the description of `ExitWorktree` says to call it only when asked.
- With a name of its own, `EnterWorktree` entered a leftover worktree of the same name in 5 of 6 runs, so the refusal asks for no name.
- The check took 59 to 168 ms before a call, median 72 ms over 85 calls, about 19 ms of it the start of `python3` and about 15 ms the import of `dataclasses`.
- A copy of the registry entry of a live VS Code session on 2.1.325 gave the refusal that names it as a VS Code session idle for 17 h 26 min.

## Install

Part of the `all` bundle, which a Lyngon repository installs whole:

```sh
claude plugin marketplace add lyngon/devkit
claude plugin install all@lyngon --scope project
```
