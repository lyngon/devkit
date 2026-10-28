# practice

Engineering discipline while changing code.

## Skills

- `tdd`: write the failing test first, watch it fail, write the minimal code, watch it pass, refactor. The agent invokes it before writing production code for any feature, bug fix or behaviour change.
- `debug`: find the root cause before proposing a fix. The agent invokes it on any bug, failing test, unexpected behaviour or build failure.
- `verify`: run the command that proves a claim and read its output before saying done, fixed or passing. The agent invokes it before any completion claim, commit or hand-over.
- `/practice:benchmark-checklist`: vet a perf measurement with seven questions (limiter, tuning, limits, errors, repeatability, relevance, whether the work happened) before reporting or acting on it. Use when running a benchmark or reporting a speedup or regression.

`tdd`, `debug` and `verify` are vendored from [obra/superpowers](https://github.com/obra/superpowers) (MIT), and `benchmark-checklist` from [cursor/plugins](https://github.com/cursor/plugins) (MIT).
The licenses are `LICENSE-superpowers` and `LICENSE-pstack` in this plugin, and the provenance records are [catalog/vendored/superpowers.md](../../catalog/vendored/superpowers.md) and [catalog/vendored/pstack.md](../../catalog/vendored/pstack.md).
The `conventions` plugin states the same rules in a few lines; these skills are the procedures that make an agent follow them under pressure.

## Install

Part of the `all` bundle.
On its own:

```sh
claude plugin marketplace add lyngon/devkit
claude plugin install practice@lyngon --scope project
```
