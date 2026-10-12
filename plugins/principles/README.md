# principles

The principles Lyngon agents apply with judgment.

## Skills

- `/principles:index`: one line per principle, saying when it applies and what it demands, and one file per principle under `references/`. The agent invokes it before work that takes judgment and then reads the file of each principle that applies.

The index holds 32 principles in six groups.
The 24 in the groups core, architecture, verification, delegation and meta are vendored from [pstack](https://github.com/cursor/plugins/tree/main/pstack) (MIT), with the patches listed in the provenance record, [catalog/vendored/pstack.md](../../catalog/vendored/pstack.md).
The license is `LICENSE-pstack` in this plugin.
The 8 in the group steering are written by Lyngon.

A repository's own principles are not here.
They are the files under its `.claude/rules/`.

## Changing a principle

A principle is one line in `skills/index/SKILL.md` and one file under `skills/index/references/`, named after the principle and at most 100 lines long.
`validate-marketplace` fails when the lines and the files disagree.
A change to a vendored principle is listed under "Local patches" in that record.

## Install

Part of the `all` bundle, which a Lyngon repository installs whole:

```sh
claude plugin marketplace add lyngon/devkit
claude plugin install all@lyngon --scope project
```
