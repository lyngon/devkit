# practice

Engineering discipline while changing code.

Prerequisites: git

## Skills

- `tdd`: write the failing test first, watch it fail, write the minimal code, watch it pass, refactor. The agent invokes it before writing production code for any feature, bug fix or behaviour change.
- `debug`: find the root cause before proposing a fix. The agent invokes it on any bug, failing test, unexpected behaviour or build failure.
- `verify`: run the command that proves a claim and read its output before saying done, fixed or passing. The agent invokes it before any completion claim, commit or hand-over.

All three are vendored from [obra/superpowers](https://github.com/obra/superpowers) (MIT).
The license is `LICENSE-superpowers` in this plugin, and the provenance record is [catalog/vendored/superpowers.md](../../catalog/vendored/superpowers.md).
The `conventions` plugin states the same rules in a few lines; these skills are the procedures that make an agent follow them under pressure.

## Install

Part of the `core` and `all` bundles.
On its own:

```sh
claude plugin marketplace add lyngon/devkit
claude plugin install practice@lyngon --scope project
```
