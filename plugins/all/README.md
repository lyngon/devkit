# all

Every plugin a Lyngon repository uses, installed with one command.

Prerequisites: documents, baseline, structure

```sh
claude plugin marketplace add lyngon/devkit
claude plugin install all@lyngon
```

This plugin has no skills of its own.
It exists because Claude Code installs one plugin per command and has no way to install a whole marketplace, but does install a plugin's `dependencies` with it.
The validator checks that `all` lists every local plugin in the marketplace except the ones in category `devkit`, which maintain the devkit itself and are useless elsewhere.

Enabling `all` means its members cannot be disabled one by one; Claude Code refuses to disable a dependency of an enabled plugin.
A repository that wants a subset installs the members directly instead.
