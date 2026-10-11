# principles

The principles Lyngon agents apply with judgment.

Prerequisites: documents

## Skills

- `/principles:index`: one line per principle, saying when it applies and what it demands, and one file per principle under `references/`. The agent invokes it before work that takes judgment and then reads the file of each principle that applies.

The index holds 32 principles in six groups.
The 24 in the groups core, architecture, verification, delegation and meta are vendored from [pstack](https://github.com/cursor/plugins/tree/main/pstack) (MIT), with the patches listed in the skill's `UPSTREAM.md`.
The 8 in the group steering are written by Lyngon.

A repository's own principles are not here.
They are the files under its `.claude/rules/`.

## Changing a principle

A principle is one line in `skills/index/SKILL.md` and one file under `skills/index/references/`, named after the principle and at most 100 lines long.
`validate-marketplace` fails when the lines and the files disagree.
A change to a vendored principle is listed under "Local patches" in `UPSTREAM.md`.

## Install

Part of the `core` and `all` bundles.
On its own:

```sh
claude plugin marketplace add lyngon/devkit
claude plugin install principles@lyngon --scope project
```
