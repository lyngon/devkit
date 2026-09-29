# Owner gates and operational tasks

Seed prompt for a fresh Claude Code session in the devkit repository.

Start by invoking the `discover:approach` skill with this brief as the request.
The work is architectural: it changes how `build:plan`, `build:delegate`, `build:execute` and `build:finish` fit together, and it amends the stop list in ADR 0016 and `shared/WORKFLOW.md`.

## The problem

Some tasks exist to perform a hard-to-reverse action that only the owner may perform or approve: an apply against a cloud account, deleting resources, a deploy, a production migration, publishing a package, rotating a key.
Three Claude Code sessions in lyngon.com (branch `feat/bootstrap`, pull request 3, 2026-09-27) met them in two shapes:

- **The owner performs, the agent verifies.** Scripts that irreversibly delete cloud resources, run by the owner after reading their dry-run output; the agent verifies the result afterwards and commits a record.
- **The owner approves, the agent performs.** `tofu apply`, allowed by that repository's CLAUDE.md only after the owner's explicit yes on that specific saved plan.

The build skills have no concept of either, so every controller improvised, and the improvisations worked well enough to be codified:

- Two dispatches around the gate: part A ran the steps up to the saved plan and wrote the artifact to approve (the rendered `tofu show` output) to the workspace; the controller showed it to the owner, waited for an explicit yes and recorded it in the ledger; part B applied that saved plan and nothing else.
- A task that changes a live system and commits nothing has no diff, so its review read the brief, the report, the scratch scripts and the live state through read-only calls, with the approved artifact as the baseline.
- The final whole-branch review ran before the owner task, because the flow has no slot after it, so the post-owner verification and record commits reached `build:finish` without any review.
- The ledger and workspace were kept through the owner step, although the skill says to delete them before `build:finish`, because they were the recovery map.
- A session ended while waiting at a gate.
  The controller wrote a handover by hand: an "## Execution status" section at the end of the plan (finished tasks with commit ranges and review results, where to resume, rulings, deferred minors, how to recreate the ledger), and removed the pre-gate artifacts so a stale saved plan could never be applied.
  The next session re-ran the pre-gate steps, got an identical plan, and resumed with no re-dispatch.
- The evidence of what was applied, in what order, and what the checks printed lived only in the gitignored workspace, which is deleted; nothing durable records it.

## Constraints

- ADR 0016: the owner reviews at two gates, the plan and the branch; the plan is transient and lives on the branch; the ledger lives in `tmp/build/<plan>/`, which may vanish.
- `shared/WORKFLOW.md`, "Who decides what": four things stop an executor, plus Lyngon's fifth; "an irreversible or destructive operation" and "a side effect outside this worktree" are among them, but nothing says how the run resumes.
- Implementer subagents cannot ask the owner anything; only the controller can.
- `scripts/task-brief` extracts a whole task; nothing marks where an implementer must stop.
- The completion line assumes commits: `Task N: complete (commits <base>..<head>, ...)`, and `scripts/review-package` refuses an empty commit range.
- Not infrastructure-specific: the same shapes appear for migrations, publishing and secrets.
- The `build` plugin declares `documents` only.

## Decisions to settle in the interview

1. The form in the plan: a gate as a step with a fixed marker inside a task (for example `- [ ] **Step N: Owner gate**`), an owner task type (`### Task N (owner)`), or a gate step plus "who acts after the gate" as a property of the task.
   What a gate names: the artifact to show, the exact question to ask, what happens on a no.
2. The invariants: no irreversible action before a gate; the artifact is written to the workspace before the gate; the part after the gate does exactly what was approved and nothing else.
3. Execution: whether `task-brief` splits at the marker or writes two briefs; the controller's handover message; the ledger lines (`Task N: waiting for owner`, the owner's answer verbatim with its time); the resume rules (re-run the pre-gate steps, never reuse a stale artifact, remove pre-gate artifacts on pause).
4. Review without a diff: an evidence-review variant of the task reviewer (inputs: the brief, the report, the evidence files and read-only access to the live system; baseline: the approved artifact), and a completion line without commits, such as `Task N: complete (no commits by design, review clean)`.
5. Where the final whole-branch review sits relative to owner tasks, and a scoped review for the commits produced after the owner step.
6. Pausing and resuming a run across sessions in general, not only at gates: where the resume record lives (the plan's own "Execution status" section on the branch, since `tmp/` may vanish, or a ledger made durable), what it holds, and what `build:finish` does with it.
7. Evidence that outlives the workspace: what `build:finish` carries into the pull request description or the final commit, such as a summary per operational task of what was applied, in what order, and what the checks printed.
8. Which of this becomes an ADR (the gate semantics and the resume record are candidates), what changes in `shared/WORKFLOW.md`, and how ADR 0016 is amended.

## Already handled elsewhere

Do not redesign these; they landed in `build` 0.2.0 (see `plugins/build/CHANGELOG.md`) or are in `docs/seed-prompts/plan-and-approach-rules.md`:

- the implementer template deferring to the brief on tests and commits;
- the "State changes since the inputs were written" block for reviewers;
- deferred minors reaching `docs/TODO.md` before the plan is removed, and the workspace surviving until `build:finish`;
- briefs carrying the Global Constraints;
- plan-mandated checks proven both ways.

## Inputs to ask me for

- lyngon.com's plan file with the hand-made "## Execution status" section (in the history of branch `feat/bootstrap`) and pull request 3.
- The two-dispatch briefs and the evidence-review prompt the controller improvised, if that repository's `tmp/` still has them.
