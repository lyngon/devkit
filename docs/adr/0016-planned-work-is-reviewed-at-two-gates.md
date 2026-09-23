# Planned work is reviewed at two gates, the plan and the branch, and the plan lives on the branch until it lands

Reviewing every commit made the owner the bottleneck of agent-driven work, and the vendored build workflow (superpowers' `writing-plans`, `executing-plans` and `subagent-driven-development`) commits once per task and keys its recovery ledger on those commits.
We review planned work at two gates: the design and the task list before execution (`/discover:approach`, `/build:plan`), and the finished branch afterwards, read from the executor's "Rulings I made" and "Deferred minors" lists; between the gates the executor commits per task on a feature branch without asking, and per-task scrutiny is a reviewer subagent's job (`/build:delegate` by default).
The plan is one file, `docs/plans/YYYY-MM-DD-<slug>.md`, with the design and the tasks, committed on the branch so a reviewer or a fresh session reads both together, and removed by `/build:finish` before integration because git history holds the work and ADRs hold the decisions; the execution ledger lives in `tmp/build/<slug>/`, the agent scratch directory, never in git.

## Considered options

- Keep per-commit review: the owner's attention bounds throughput, and a ledger keyed on task commits cannot wait for it.
- Keep plans under `docs/` after the work lands: a stale plan contradicts the code and becomes a second place to maintain what the code already says.
- Keep plans in `tmp/`: not on the branch, so the reviewer sees tasks without the design and a fresh session cannot pick the plan up.

## Consequences

- Interactive sessions without a plan keep the earlier habit: stage, run the full check, stop for file review, commit when told.
- `build` declares `documents` and is in `core`; the ledger location does not raise it, since `tmp/` is the scratch directory of every repository the `repo` plugin sets up and the workspace script ignores its own directory where `tmp/` is not ignored.
- A decision made while planning still becomes an ADR before the plan file is removed; `/build:finish` checks the design section for one.
