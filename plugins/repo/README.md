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

- `SessionStart`: in a repository whose root `CLAUDE.md` says it follows the Lyngon structure, prints `hooks/session-start-structure.txt`, which says to create every package with `/repo:add-package`; elsewhere it prints nothing.
  The lines about which devkit skills to invoke come from the `conventions` plugin's hook.

## Install

```sh
claude plugin marketplace add lyngon/devkit
claude plugin install repo@lyngon --scope project
```
