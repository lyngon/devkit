# Planned work is reviewed at two gates

Reviewing every commit made the owner the bottleneck of agent-driven work, and the vendored build workflow (superpowers' `writing-plans`, `executing-plans` and `subagent-driven-development`) commits once per task and keys its recovery ledger on those commits.
We review planned work at two review gates: the design and the task list before execution (`/discover:approach`, `/build:plan`), and the pull request afterwards, read from the executor's "Rulings I made" and "Deferred minors" lists in its description; between the review gates the executor commits per task on a feature branch without asking, and per-task scrutiny is a reviewer subagent's job (`/build:delegate` by default).
The agent pushes the branch and opens the pull request without asking once the full check passes, and merging stays the owner's decision.

## Considered options

- Keep per-commit review: the owner's attention bounds throughput, and a ledger keyed on task commits cannot wait for it.
- Keep file review before commit for work without a plan: it keeps the owner in series with every commit, and holding commits mixes concerns in one working tree (pull request 2 held twelve, rebuilt into commits afterwards).
- Keep plans under `docs/` after the work lands: a stale plan contradicts the code and becomes a second place to maintain what the code already says.
- Keep plans in `tmp/`: not on the branch, so the reviewer sees tasks without the design and a fresh session cannot pick the plan up.

## Consequences

- Work without a plan follows the same rule, with the pull request as its last review gate: the agent commits each concern on a feature branch as it goes, without waiting for a file review.
- The plan is one file, `docs/plans/YYYY-MM-DD-<slug>.md`, with the design and the tasks, committed on the branch so a reviewer or a fresh session reads both together, and removed by `/build:finish` before the push, because git history holds the work and decision records hold the decisions. The execution ledger lives in `tmp/build/<slug>/`, the agent scratch directory, never in git.
- The standing instructions to commit, push and open the pull request live in `conventions:engineering`, because only a plugin reaches every repository that uses the devkit; the `conventions` session hook and the skill descriptions make agents invoke it.
  Those instructions also list what still waits for the owner: a merge, a push to the default branch, a force-push, closing a pull request, deleting a remote branch, a tag, a release, a publish.
- A decision made while planning still becomes a decision record before the plan file is removed; `/build:finish` checks the design section for one.
- Owner gates inside a plan's execution, and the copy of the ledger in the plan when a run pauses, are in [Owner gates are declared in the plan and pre-approved by name](owner-gates-are-declared-in-the-plan-and-pre-approved-by-name.md).

Enforced by: judgment
