# Changelog

All notable changes to the `build` plugin.
Versions follow semver and are recorded in `.claude-plugin/plugin.json`.
Vendored skills record their upstream commit in their own `UPSTREAM.md`.

## 0.15.25 - 2026-09-30

- `delegate`'s `task-brief` reads an Owner Gates index Task cell of "Task 6" as task 6, so a task indexed that way without its marker is refused, where only a bare "6" was matched and the task extracted as ungated.

## 0.15.24 - 2026-09-30

- `delegate`'s owner gate protocol keeps the commits of an unforeseen gate whose run-time approval lapsed: a resumed run re-runs only the steps that produced its artifact, and only when the artifact is missing or its pin no longer matches, then asks again, where it said to re-run the whole pre-gate part, commits included.
  A recovered gated task whose BASE was lost with the workspace takes the parent of its first commit in the log as BASE for its evidence review, where nothing said which BASE to use.

## 0.15.23 - 2026-09-30

- `delegate`'s owner gate protocol shows one `Artifact:` line per pinned file and quotes the `Show` file for a pinned file that is not text, removes a task's temporary files only once its evidence review is clean, since the reviewer checks against them, and replaces only the character a hook rejects in a verbatim answer, or a `|` that would break a table, with its plain form.
  A session the owner ends with no task at its gate pauses with `docs(plan): pause before Task N`, which Resuming reads from too; the ledger never holds a secret; Pausing spells out the post-gate argument of `execution-status write`; the pre-approval check passes a gate only for an action the approval pins, where it could pass a gate that "Who performs the action" says must ask.
  `delegate` says a gated task has two reports, one per part, and its implementer template joins the pre-gate exception to "Every task ends with at least one commit"; `plan` agrees on temporary files and on replacing a character in a pre-approval.

## 0.15.22 - 2026-09-30

- `WORKFLOW.md`, symlinked into `plan`, names the executor's "Owner gates" list beside "Rulings I made" and "Deferred minors" at the second review gate.
  `plan` names the user's two review gates where it said "two gates", leaves the owner gates clause out of the first handoff template when the plan declares none, and words self-review item 7 without the undefined "stop-list action".

## 0.15.21 - 2026-09-30

- `finish` runs `execution-status restore` whenever the plan holds an Execution status, which keeps a longer ledger, where it ran only when `progress.md` was missing, and takes the pull request's "Owner gates" list from the record commits since the merge base, one entry per gate with its answer or pre-approval and the record commit's hash, where it took every `Gate` line of a ledger that may be gone.
  `delegate`'s and `execute`'s Finish paragraphs say one entry per gate, that `build:finish` puts three lists in the description, not two, and that it reads the owner gates too.

## 0.15.20 - 2026-09-30

- `delegate`'s `execution-status write` gives a ledger without a final newline one, where the closing fence joined the ledger's last line and `restore` then found no fenced ledger; refuses a ledger line of four backticks after any indentation, where only an unindented one was caught although the fence tracker ends the fence at either; and refuses a RESUME_AT holding a newline.

## 0.15.19 - 2026-09-30

- `delegate`'s `pin` refuses a directory, a file it cannot read and a hash that did not come out, with exit 2 and a message naming the file, before it prints any line, where a file without read permission printed `sha256: <file>` with an empty hash and exited 0, and `--check` reported an empty hash as a mismatch.

## 0.15.18 - 2026-09-30

- `delegate`'s owner gate protocol pins the artifact of an unforeseen gate: its `Show` is the written statement plus any artifact the stopped part produced, which becomes its `Acts on`, and the owner performs an action with nothing to pin, where the statement alone was pinned and the artifact that then got applied never was.
  Its post-gate part gets the whole brief and the step to start at, since `task-brief --part` refuses an ungated task, and builds on the commits made before the stop; the implementer template and `execute` say so.

## 0.15.17 - 2026-09-30

- `delegate`'s owner gate protocol voids a pre-approval for the run when a pin check or dry-run re-check of its gate fails, and ledgers `Gate <id>: approval void (<the check that failed>)`, where the gate went back to step 1 and the pre-approval check passed it again without asking.
  Resuming reads that line as a post-gate part that stopped without acting.

## 0.15.16 - 2026-09-30

- `delegate`'s implementer template tells a post-gate implementer that the approval covers one run of the approved commands, and that in a fix round it never runs them again and takes no other effect outside the repository but reports BLOCKED, where a fix round resumed the implementer that held the approval and a finding about the live system invited a second apply.
  Both executors screen the evidence review's findings before any fix, so one whose fix needs another live action becomes an unforeseen gate, and `delegate`'s scoped re-review after an evidence-review fix gets read-only access to the live system.

## 0.15.15 - 2026-09-30

- `delegate`'s owner gate protocol reconciles the ledger with `git log` at every setup of a plan that declares owner gates or holds an Execution status, reading from the pause commit or else from the merge base, where it did so only after a pause; so a record commit whose completion was never ledgered, or a workspace lost without a pause, no longer lets a gated action run twice.
  A run-time approval lapses when the session that received it ends before the post-gate part starts, at a pause or not, where the text said only "at a pause".
  `delegate` and `execute` follow this at setup, say that `PLAN_FILE` is the plan's path relative to the repository root in the ledger's identity line and every script call, and join the resume rule with its gated-task exception.

## 0.15.14 - 2026-09-30

- `delegate`'s `task-brief` refuses (exit 3) a step title that says "owner gate" without being a well-formed marker, such as the Title Case `Owner Gate`, and a task that the Owner Gates index names but whose steps hold no marker with that ID, where it extracted either task as ungated, the gated action included; a step titled "Owner gateway" is no longer taken for a malformed marker.
  `plan` tells plan authors so.

## 0.15.13 - 2026-09-30

- `execute`'s `## Owner gates` asks for `Task N post-gate: started` to be ledgered before any post-gate step runs, in any call, where it also required the same call as `task-start --part post-gate`.

## 0.15.12 - 2026-09-30

- `execute`'s `task-done` skips lines of only whitespace, a carriage return included, when it picks the last output line for the ledger, so a check whose output ends with a spinner clearing its line records its last real line.

## 0.15.11 - 2026-09-30

- `delegate`'s owner gate protocol no longer says the gate message's lines are exact: the message keeps the plan's text verbatim in a `text` fence with more backticks than any fence it quotes, a gate pinned by a command's text shows `Command:` in place of the `Artifact:` line, and a gate the owner performs shows a `Commands:` line and asks for "done", where the exact template ended in "Answer yes, no with what to change, or later." and read as letting a "yes" pass an owner-performed gate.

## 0.15.10 - 2026-09-30

- `delegate`'s Resuming section recovers a gated task whose record commit is in the log by ledgering its gate answer and resuming at its evidence review, which completes it, where it could be ledgered complete without that review; a post-gate line with a record commit after it no longer triggers the unforeseen-gate safeguard, and the ledger example shows a recovered completion.

## 0.15.9 - 2026-09-30

- The evidence reviewer prompt reads the task's ledger lines and record commit where an inline executor wrote no report files, and `execute`'s `## Owner gates` says to pass them in place of `[PRE_GATE_REPORT]` and `[POST_GATE_REPORT]`, where the template marked the two report files as required.

## 0.15.8 - 2026-09-30

- `delegate`'s owner gate protocol reconciles a restored ledger with the commits after the pause commit: it ledgers the tasks those commits complete as recovered from `git log`, resumes at the first task they do not complete, and never re-runs the post-gate part of a gate whose record commit is in the log, where the copy in the plan, as old as the pause commit, would have had a resumed run redo the tasks and a pre-approved gate act a second time.

## 0.15.7 - 2026-09-30

- `execute`'s `task-done` records a passing test command that prints nothing, with `(no output)` as the last line, where it exited 1 under `pipefail` and recorded nothing although the check passed.

## 0.15.6 - 2026-09-30

- `execute` names `workspace`, `execution-status restore` and `review-package` by their path from its own directory and runs them from the repository root, and `delegate` runs `review-package` from the repository root, where both said to run them from the skill's directory, which an executor read as changing into it, so the scripts resolved the repository that holds the skill.

## 0.15.5 - 2026-09-30

- `delegate`'s owner gate protocol sends the gate message as a single `text` fence, since the instruction to add no formatting alone still let an executor put the gate ID in backticks.

## 0.15.4 - 2026-09-30

- `delegate`'s owner gate protocol places the artifact's quote below the gate message's `Artifact:` line, so a message sent exactly as its template shows it still quotes the artifact.

## 0.15.3 - 2026-09-30

- `delegate`'s owner gate protocol ledgers every answer at a gate verbatim with its time, a "later" too, so the ledger shows that the owner paused the run.

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
