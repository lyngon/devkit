# Workflow

Single source in `shared/` of the Lyngon devkit; plugins symlink it.
Which skills to invoke, in which order, for each kind of work, and where the human decides.

## The flows

| Scenario | Flow |
| --- | --- |
| Set up or adopt a repository | `/repo:init` |
| Toss ideas around | `/discover:brainstorm`; `/discover:approach` only when an idea firms up |
| A new feature, or anything with more than one reasonable design | `/discover:approach` classifies the work, then the bounded or architectural flow below |
| A bug | `practice:debug`, then `practice:tdd` for the regression test, `practice:verify` before claiming it fixed |
| A small change with an obvious design | Do it; `practice:tdd` and `practice:verify` apply on their own |
| A term or a decision | `discover:domain-model` |
| A finished branch, however it was made | `/build:finish` |
| Review feedback, from a person or a reviewer subagent | `review:receive` before implementing any of it |

### Bounded change

A well-scoped change to a flow that already exists in the repository.

1. `/discover:approach` asks the clarifying questions that matter in one round and presents a short design in chat: approach, files touched, testing.
2. **Gate**: the user says yes to that design.
3. Implement with `practice:tdd`; `practice:verify` before every claim.
4. `/review:request` before merging.
5. `/build:finish` to integrate the branch.

### Architectural change

A new subsystem, a restructuring, or an interface others depend on.

1. `/discover:approach` runs the interview; `CONCEPTS.md` terms and ADRs are written as they settle, and the design goes to `docs/plans/YYYY-MM-DD-<slug>.md`.
2. `/build:plan` appends the tasks to that file and commits it on the feature branch.
3. **Gate 1**: the user reviews the design and the plan, and picks the executor.
4. `/build:delegate` (a fresh implementer per task, a reviewer after each task; the default beyond a handful of tasks) or `/build:execute` (inline, one review at the end) builds it, one commit per task, without asking.
5. `/build:finish` runs the full check, removes the plan file and presents the integration menu.
6. **Gate 2**: the user reads the branch, starting from the executor's "Rulings I made" and "Deferred minors" lists, and merges, asks for changes or keeps it.
7. `review:receive` handles the feedback; the fixes go through `practice:tdd`.

### Spike

A feasibility question whose output is an answer.
`/discover:approach` presents the question and the probe, the user nods, the agent investigates as cheaply as correctness allows and reports a recommendation.
Anything built is throwaway; keeping it is a new request, classified again.

## Who decides what

The user decides at the gates: the classification (they can override it), the design, the plan and the executor, and what happens to the finished branch.
Between the gates the executor decides: conflicts inside the plan, ambiguities, findings it parks, all recorded as rulings in the ledger and surfaced with the branch.
Four things always stop an executor for the user: an irreversible or destructive operation, a security-sensitive action, a side effect outside the worktree (a merge, a push to a shared branch, a publish), and a plan so broken that every path forward is a guess.
A fifth is Lyngon's: a check or hook is never disabled, skipped or weakened to get past it.

Between the gates, the executor is also the reviewer's client: a task reviewer after every task in `/build:delegate`, a whole-branch reviewer at the end in both executors.
A per-commit human review is not part of any flow; the two gates replace it.

## What gets written where

- Nothing, in `/discover:brainstorm`.
- Terms in `CONCEPTS.md` and decisions in `docs/adr/`, as they settle in `/discover:approach` and `discover:domain-model`, and again in `/build:finish` when the design still holds an unrecorded decision.
- The design and the plan in `docs/plans/YYYY-MM-DD-<slug>.md`, committed on the branch and removed by `/build:finish`.
- The execution ledger, briefs and review packages in `tmp/build/<slug>/`, scratch that never enters git.
- Deferred work in `docs/TODO.md`, only when the user says so.

## With the Lyngon structure

A new package (app, library, adapter, contract, tool, infra module or environment) is created with `/repo:add-package`, never by hand, whichever flow needs it.

## With devenv

The full check that `/build:finish` and `practice:verify` require is `devenv test`.
