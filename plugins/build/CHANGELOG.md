# Changelog

All notable changes to the `build` plugin.
Versions follow semver and are recorded in `.claude-plugin/plugin.json`.
Vendored skills record their upstream commit in their own `UPSTREAM.md`.

## 0.15.2 - 2026-09-30

- `execute` ledgers `Task N post-gate: started` in the same call as `task-start --part post-gate`, before any post-gate step runs, so a run lost after the gated action still shows a started post-gate part when it resumes.

## 0.15.1 - 2026-09-30

- `delegate`'s owner gate protocol says the gate message's lines are sent exactly as its template shows them, with no backticks or other formatting added, so its first line always reads `Owner gate <id> (Task N)`.

## 0.15.0 - 2026-09-30

- `WORKFLOW.md`, symlinked into `plan`, names the review gates and the owner gates: the user pre-approves owner gates by ID at the first review gate, the executors stop only at owner gates, every stop runs the same protocol, and the Execution status and the record commits are listed with what gets written where. The README says so.

## 0.14.0 - 2026-09-30

- `finish` recreates a paused run's ledger from the plan's Execution status before it removes the plan, and the pull request description lists the owner gates: each gate's ID, the answer or the pre-approval, and the record commit of its task.

## 0.13.0 - 2026-09-30

- `plan` writes owner gates: a gate step with its ID and fields in the task that performs a hard-to-reverse action, the rules for the steps before and after it and for who may perform the action, and a `### Owner Gates` index as the first subsection of the plan. Every task ends with at least one commit. The handoff lists the gates that can be pre-approved and asks which, by ID; the answer goes into the index, committed as `docs(plan): record pre-approved owner gates`. Self-review checks the gates.

## 0.12.0 - 2026-09-30

- `execute` runs a task with an owner gate as `delegate`'s `references/owner-gates.md` says, doing both parts itself and dispatching the evidence reviewer, since its final review cannot see live state. `task-start` takes `--part pre-gate|post-gate` and passes it to `task-brief`. Setup restores a paused run's ledger from the plan's Execution status, and the final message lists the owner gates. Its stop list names the owner gates the plan declares next to the five stops.

## 0.11.1 - 2026-09-30

- `delegate` names the owner gates the plan declares next to the five stops in three sentences that still said only the five stops stop the executor.

## 0.11.0 - 2026-09-30

- `delegate` runs a task with an owner gate as `references/owner-gates.md` says: two dispatches around the gate, which the controller takes; a pre-approved gate passes without asking; the post-gate dispatch is fresh and carries the approval; an evidence review takes the place of the diff review. Each of the five stops that the plan did not declare runs the same protocol as an unforeseen gate. Setup restores a paused run's ledger from the plan's Execution status, and the final message lists the owner gates next to the rulings and deferred minors.

## 0.10.0 - 2026-09-30

- `delegate` gains `references/owner-gates.md`, the protocol both executors follow at an owner gate: the two parts of a gated task, who may perform the action, the pins, the pre-approval check, the gate message, the record commit, unforeseen stops, pausing and resuming, and the ledger lines. `references/evidence-reviewer-prompt.md` reviews a gated task against the approved artifact, the record commit and the live system through read-only calls. The implementer template ends every task with at least one commit, a record commit for work outside the repository, instead of letting a brief declare that a task commits nothing, and carries an optional `## Owner Gate` section for the two parts.

## 0.9.0 - 2026-09-30

- `delegate` gains `scripts/execution-status`. `write PLAN RESUME_AT` copies the ledger verbatim into an `## Execution status` section of the plan, replacing an earlier one in place and leaving every other line as it was; `restore PLAN` recreates a missing ledger from that copy, replaces a ledger the copy extends, keeps one that extends the copy, and exits 1 when they disagree.

## 0.8.0 - 2026-09-30

- `task-brief` ends a task at the next heading of the same or a higher level, so the last task no longer carries a later section, such as an Execution status, into its brief; it tracks fences by character and length, so a fence inside a longer one stays text. A task with an owner gate is extracted in two parts: `--part pre-gate` writes `task-N-pre-gate-brief.md` (the steps before the gate, the gate and a line that stops the implementer there) and `--part post-gate` writes `task-N-post-gate-brief.md` (the gate and the steps after it). Before it writes anything, it refuses a task with two gates, a gate missing a field or giving one twice, a performer other than `agent` or `owner`, an ID that is not kebab-case, is duplicated or is missing from the Owner Gates index, a gated task without `--part` and an ungated task with it.

## 0.7.0 - 2026-09-30

- `delegate` gains `scripts/pin`, which prints a file's sha256 in the form an owner gate records (`sha256:<hex> <file>`) and checks a file against a recorded pin with `--check`, using `sha256sum` or `shasum`. The build scripts have fixture tests in `tests/scripts.sh`, which also prove that `review-package` accepts a range holding only an empty record commit.

## 0.6.0 - 2026-09-29

- `finish` asks once before the push unless the user's standing instructions cover pushing and opening a pull request; under the Lyngon workflow, `conventions:engineering`'s do, and it pushes without asking as before. `WORKFLOW.md` names `conventions:engineering` only under a "With the Lyngon workflow" heading. The README lists the deferred-findings question after the pull request, where `finish` asks it. `plan`, `execute` and `delegate` say the push is left to `finish` instead of saying it is never a stop.

## 0.5.0 - 2026-09-29

- `plan`, `execute` and `delegate` name the pull request as the user's second gate, and the executors no longer stop for pushing the feature branch or opening its pull request. `WORKFLOW.md` puts commit, push and pull request into every flow and ends the bounded flow with a gate on the pull request. The plugin's description ends at an open pull request instead of an integrated branch.

## 0.4.0 - 2026-09-29

- `finish` pushes the branch and opens the pull request without asking instead of presenting a menu, and merges locally or keeps the branch only on request. The description carries what changed, decisions for the user, the executor's rulings and deferred minors with a link to the plan, unfixed findings and the verification. An existing pull request gets its description updated; without a remote the branch is kept, and without a forge CLI the creation link is handed over. Deferred findings go into the description, and the question which of them go to `docs/TODO.md` comes after the pull request is open.

## 0.3.0 - 2026-09-29

- `plan` requires every check the plan mandates (a script, a command with an expected output, a condition a task verifies before it proceeds) to be shown failing when its property does not hold and passing when it does. A check without that control is a placeholder, and self-review looks for it.
- `plan` self-review checks every block of prose the plan dictates (ADR text, README steps, `CLAUDE.md` lines, `CONCEPTS.md` entries) against the existing ADRs, the gates and rules in `CLAUDE.md`, and the findings recorded earlier in the design and plan.
- `plan` writes a command a person runs by hand in POSIX sh or through `bash -c`, and points at `conventions:shell` for the rules of scripts.

## 0.2.0 - 2026-09-29

- Task briefs carry the plan's Global Constraints section after the task text. The task reviewer reads them in the brief; the controller adds at most one sentence of emphasis instead of pasting them.
- `task-brief` and `review-package` print only the file path on stdout and their summary on stderr, so `B=$(task-brief ...)` captures the path.
- One brief and one report per task. A report file left by an earlier attempt is handed to the new implementer, who reads it first and appends under a dated heading.
- Review packages list every commit with its full message, so reviewers can check the commit rules.
- Every reviewer gets the state changes since the plan was written, ledgered as `State:` lines, in an optional section.
- The implementer template tests and commits as the brief says, with the previous behaviour as the default, and a brief may declare that a task commits nothing. Hook evidence is the output of an explicit hook run, never commit-time output; with devenv, `prek run --all-files`.
- `delegate` and `execute` hand the plan workspace to `finish` instead of deleting it. `finish` offers the deferred minors and parked findings for `docs/TODO.md` before it removes the plan, and removes the workspace when the work lands.
- `finish` ends a pull request with the landing steps for after the forge merges it: switch to the base branch, `git pull --ff-only`, remove the worktree and delete the local branch.

## 0.1.0 - 2026-09-23

- Added `plan`, `execute`, `delegate` and `finish`, vendored from obra/superpowers 6.4.1 at commit `5bf4e78` (`writing-plans`, `executing-plans`, `subagent-driven-development`, `finishing-a-development-branch`) and rewritten to Lyngon vocabulary: plans in `docs/plans/` on the branch, the ledger in `tmp/build/`, one commit per task on a feature branch, review at the plan and the branch, no package installs, and the worktree skill folded into the executors' setup.
- `plan` links the shared `WORKFLOW.md`, which lays out the flow between the discover, build, practice and review skills and the user's gates.
