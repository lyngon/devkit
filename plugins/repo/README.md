# repo

Repository setup and package creation for Lyngon.

Prerequisites: documents, baseline, structure

## Skills

- `/repo:init`: interview the owner about purpose, audiences, stack and constraints, then create or adopt the standard repository files.
  Works on empty repositories and on existing ones.
  User-invoked only.
- `/repo:add-package`: create a package in the directory its kind decides (`apps/`, `libs/`, `contracts/`, `tools/`, `infra/`), with its files, and register it in its workspace and devenv.
  Agents invoke it on their own whenever a package is needed.

## Hooks

- `SessionStart`: prints a few lines telling the agent which devkit skills to invoke and when.
  The text is `hooks/session-start.txt`, plus `hooks/session-start-structure.txt` when the root `CLAUDE.md` says the repository follows the Lyngon structure.

## Install

```sh
claude plugin marketplace add lyngon/devkit
claude plugin install repo@lyngon
```
