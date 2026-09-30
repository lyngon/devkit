# Owner gates are declared in the plan, pre-approved only by name, and every stop runs the same protocol

Some planned tasks exist to perform an action only the owner may approve or perform, such as an apply, a deletion, a deploy or a publish; ADR 0016 listed when an executor stops but not how the run continues, and three lyngon.com sessions improvised it.
A plan now declares each such action as an owner gate inside the task that performs it.
The steps before the gate do only reversible work and write what the owner must see; the executor asks one question and records the answer; the steps after the gate do exactly what was approved and nothing else.
The owner may pre-approve a gate by name when approving the plan, and every stop the plan did not foresee runs the same protocol, so one mechanism answers how every stop resumes.

## Considered options

- An owner task type, with the preparation and the verification as separate tasks around it: three tasks per action, and "do exactly what was approved" becomes prose that spans tasks.
- Approving the plan approves every action in it: the owner approves an intent, never the artifact, and one reply authorizes actions nobody named. Pre-approval is explicit and per gate.
- No pre-approval at all: the owner is interrupted for actions whose outcome the plan already pins down.
- A completion line without commits for tasks whose work lies outside the repository, with the evidence in the pull request description: the evidence would live only on the forge, and the review package would need a path without commits.
- For the resume record, committing the ledger after every task (ledger churn in every task's diff and review) or keeping it only in `tmp/` (the rulings and the owner's answers vanish with the workspace, and another checkout has nothing to resume from).

## Consequences

- A run-time approval pins the action: the hash of the artifact it acts on, or the command with its inputs pinned by hash or immutable identifier. It lapses when the run pauses before the action. The executor performs only actions whose effect the approval pins; the owner performs the rest, and the executor verifies them.
- A pre-approval is recorded in the plan's index of owner gates on the branch. It holds only for a gate the executor performs, only while every expected output before the gate matched, and never where the repository's instructions require approval at run time.
- Every task that passes an owner gate ends with a record commit, empty when the repository did not change, whose message holds the evidence: the answer or the pre-approval, the pins, the commands in order and the results of the checks. Every task ends with at least one commit.
- When a run pauses, the ledger is copied verbatim into an `## Execution status` section of the plan and committed on the branch, so a later session in any checkout resumes from it. This narrows ADR 0016: the ledger enters git only as that copy, which `/build:finish` removes with the plan.
- The final whole-branch review stays after the last task, gated or not; an owner action is never placed after the executor hands over.
- `conventions:engineering` counts a pre-approved owner gate as asking before an effect outside the branch.
