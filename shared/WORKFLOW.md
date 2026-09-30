# Workflow

Single source in `shared/` of the Lyngon devkit; plugins symlink it.
Which skills to invoke, in which order, for each kind of work, and where the human decides.

## The flows

| Scenario | Flow |
| --- | --- |
| Set up or adopt a repository | `/repo:init` |
| Toss ideas around | `/discover:brainstorm`; `/discover:approach` only when an idea firms up |
| A new feature, or anything with more than one reasonable design | `/discover:approach` classifies the work, then the bounded or architectural flow below |
| A bug | `practice:debug`, then `practice:tdd` for the regression test, `practice:verify` before claiming it fixed, then `/build:finish` |
| A small change with an obvious design | Do it; `practice:tdd` and `practice:verify` apply on their own; then `/build:finish` |
| A term or a decision | `discover:domain-model` |
| A finished branch, however it was made | `/build:finish` pushes it and opens the pull request |
| Review feedback, from a person or a reviewer subagent | `review:receive` before implementing any of it |

### Bounded change

A well-scoped change to a flow that already exists in the repository.

1. `/discover:approach` asks the clarifying questions that matter in one round and presents a short design in chat: approach, files touched, testing.
2. **Review gate**: the user says yes to that design.
3. Implement with `practice:tdd`, committing each concern as it is done; `practice:verify` before every claim.
4. `/review:request` before the pull request.
5. `/build:finish` runs the full check, pushes the branch and opens the pull request.
6. **Review gate**: the user reviews the pull request and merges it or asks for changes.
7. `review:receive` handles the feedback; the fixes are new commits, pushed after the full check.

### Architectural change

A new subsystem, a restructuring, or an interface others depend on.

1. `/discover:approach` runs the interview; `CONCEPTS.md` terms and ADRs are written as they settle, and the design goes to `docs/plans/YYYY-MM-DD-<slug>.md`.
2. `/build:plan` appends the tasks to that file and commits it on the feature branch.
3. **Review gate 1**: the user reviews the design and the plan, picks the executor, and pre-approves by ID the owner gates they want passed without a stop.
4. `/build:delegate` (a fresh implementer per task, a reviewer after each task; the default beyond a handful of tasks) or `/build:execute` (inline, one review at the end) builds it, one commit per task, without asking, and stops only at owner gates.
5. `/build:finish` runs the full check, removes the plan file, pushes the branch and opens the pull request.
6. **Review gate 2**: the user reviews the pull request, starting from the executor's "Rulings I made", "Deferred minors" and "Owner gates" lists in its description, and merges it or asks for changes.
7. `review:receive` handles the feedback; the fixes go through `practice:tdd` and are pushed as new commits after the full check.

### Spike

A feasibility question whose output is an answer.
`/discover:approach` presents the question and the probe, the user nods, the agent investigates as cheaply as correctness allows and reports a recommendation.
Anything built is throwaway; keeping it is a new request, classified again.

## Who decides what

The user decides at the review gates: the classification (they can override it), the design, the plan and the executor, and whether the pull request merges.
Between the review gates the executor decides: conflicts inside the plan, ambiguities, findings it parks, all recorded as rulings in the ledger and surfaced in the pull request.
The user also decides at owner gates, where the executor stops until they approve or perform a hard-to-reverse action, or answer a question the executor must not settle alone.
A plan declares the owner gates it foresees, and the user may pre-approve each one by its ID when approving the plan; approving the plan pre-approves none of them.
Four things stop an executor for the user, unless the plan declares them as a gate the user pre-approved: an irreversible or destructive operation, a security-sensitive action, a side effect outside the worktree (a merge, a push to the default branch, a force-push, closing a pull request, deleting a remote branch, a tag, a release, a publish), and a plan so broken that every path forward is a guess.
Pushing the feature branch and opening its pull request are not among them: they are left to `/build:finish`.
A fifth is Lyngon's: a check or hook is never disabled, skipped or weakened to get past it.
Every stop, planned or not, runs the same protocol: the executor shows what the user must see, asks one question and records the answer; when the session ends before the answer, it pauses with a copy of its ledger in the plan, so a later session resumes it.

Between the review gates, the executor is also the reviewer's client: a task reviewer after every task in `/build:delegate`, an evidence reviewer after every task with an owner gate in both executors, and a whole-branch reviewer at the end in both.
No flow has a per-commit or per-file human review: the agent commits on a feature branch without asking, and the user reviews the pull request.

## What gets written where

- Nothing, in `/discover:brainstorm`.
- Terms in `CONCEPTS.md` and decisions in `docs/adr/`, as they settle in `/discover:approach` and `discover:domain-model`, and again in `/build:finish` when the design still holds an unrecorded decision.
- The design and the plan in `docs/plans/YYYY-MM-DD-<slug>.md`, with the index of owner gates and the user's pre-approvals, committed on the branch and removed by `/build:finish`.
- The execution ledger, briefs and review packages in `tmp/build/<slug>/`, scratch that enters git only as the verbatim copy of the ledger in the plan's `## Execution status` section when a run pauses, removed with the plan.
- The evidence of every owner gate in the record commit that ends its task, empty when the repository did not change.
- Deferred work in `docs/TODO.md`, only when the user says so.

## With the Lyngon workflow

The standing instructions for commits, pushes and pull requests are in `conventions:engineering`: `/build:finish` pushes the branch and opens the pull request without asking.

## With the Lyngon structure

A new package (app, library, adapter, contract, tool, infra module or environment) is created with `/repo:add-package`, never by hand, whichever flow needs it.

## With devenv

The full check that `/build:finish` and `practice:verify` require is `devenv test`.
