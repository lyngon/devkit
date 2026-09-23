# core

The plugins that work in any repository with the Lyngon documents, installed with one command.

Prerequisites: documents

```sh
claude plugin marketplace add lyngon/devkit
claude plugin install core@lyngon
```

This plugin has no skills of its own.
It exists for repositories that want discovery, the build workflow, the engineering practices, review, writing and the conventions without adopting the baseline or the Lyngon structure.
The validator checks that no member declares a prerequisite above `documents`, so installing `core` never imposes the layout or the toolchain.
A repository that adopts everything installs `all` instead.
