# core

The plugins that work in any repository with the Lyngon documents, installed with one command.

Prerequisites: documents

```sh
claude plugin marketplace add lyngon/devkit
claude plugin install core@lyngon --scope project
```

This plugin has no skills of its own.
It exists for repositories that want discovery, planning and execution, the engineering practices, review and writing without adopting the baseline or the Lyngon structure.
The validator checks that no member declares a prerequisite above `documents`, so installing `core` never imposes the layout, the toolchain or the Lyngon workflow.
A repository that adopts the workflow installs `conventions` next to it:

```sh
claude plugin install conventions@lyngon --scope project
```

Without `conventions`, `core` may also be enabled at user scope, for every repository: `/build:finish` then asks before it pushes, and nothing announces a Lyngon repository.
Its executors still commit each task on a feature branch, and its skills still write the Lyngon documents where they run, such as a plan in `docs/plans/`, `CONCEPTS.md` and ADRs.
Install the members by name too: Claude Code does not count a member installed with the bundle as enabled when it checks another member's dependencies, and `build` needs `practice` and `review`.

```sh
claude plugin install core@lyngon --scope user
claude plugin install discover@lyngon --scope user
claude plugin install build@lyngon --scope user
claude plugin install practice@lyngon --scope user
claude plugin install review@lyngon --scope user
claude plugin install writing@lyngon --scope user
```

A repository that adopts everything installs `all` instead.
