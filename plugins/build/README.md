# build

From an approved design to an open pull request.

Prerequisites: documents

## Skills

- `/build:plan`: write the implementation plan for a settled design as bite-sized, test-first tasks, appended to the design file under `docs/plans/`, and hand it to the user for review.
- `/build:delegate`: execute a plan with a fresh implementer subagent per task, a spec-and-quality review after each task and a whole-branch review at the end. The default for more than a handful of tasks.
- `/build:execute`: execute a plan yourself in the session, task by task, with one whole-branch review at the end. The cheap mode.
- `/build:finish`: run the full check, remove the plan file, push the branch and open the pull request (asking once first, unless the user's standing instructions cover it, as the `conventions` plugin's do), then offer the deferred findings for `docs/TODO.md`; merging locally or keeping the branch only on request.

The user reviews at two gates: the plan before execution, and the pull request afterwards, starting from the executor's "Rulings I made" and "Deferred minors" lists in its description.
Between the gates the executor commits per task on a feature branch and does not stop to ask, except for the stop conditions every executor carries.
The execution ledger and the task briefs live under `tmp/build/<plan>/`, the agent scratch directory, never in git.
See [ADR 0016](../../docs/adr/0016-planned-work-is-reviewed-at-two-gates.md).

All four are vendored from [obra/superpowers](https://github.com/obra/superpowers) (MIT), see each skill's `UPSTREAM.md`.
The executors invoke `practice:tdd`, `practice:debug`, `practice:verify` and `review:request`, so `practice` and `review` are dependencies.

## Install

```sh
claude plugin marketplace add lyngon/devkit
claude plugin install build@lyngon --scope project
```
